#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

INVENTORY="inventories/prod/hosts.yml"
VAULT_PASS_FILE=""
ASSUME_YES=0
RUN_PREFLIGHT=1
RUN_BOOTSTRAP=1
RUN_SITE=1
RUN_BACKUP=1

usage() {
  cat <<'USAGE'
Usage: scripts/deploy.sh [options]

Options:
  -i <inventory>           Inventory path (default: inventories/prod/hosts.yml)
  -p <vault pass file>     Optional Ansible Vault password file
  -y, --yes                Non-interactive mode; accept defaults
  --skip-preflight         Skip preflight
  --skip-bootstrap         Skip bootstrap
  --skip-site              Skip site deployment
  --skip-backup            Skip backup configuration
  -h, --help               Show this help
USAGE
}

ensure_local_config() {
  local missing=0
  local required_files=(
    "inventories/prod/hosts.yml"
    "inventories/prod/group_vars/all.yml"
    "inventories/prod/group_vars/core_hosts.yml"
    "inventories/prod/group_vars/vault.yml"
  )

  for file in "${required_files[@]}"; do
    if [[ ! -f "${file}" ]]; then
      missing=1
      break
    fi
  done

  if [[ "${missing}" -eq 0 ]]; then
    return 0
  fi

  echo "Local deployment config is missing."
  echo "Bootstrapping local working files from tracked .example files."
  ./scripts/init-local-config.sh
  echo "Edit the generated local files, encrypt inventories/prod/group_vars/vault.yml, then rerun deploy."
  exit 1
}

prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    [[ "$default" == "y" ]] && return 0 || return 1
  fi
  read -r -p "${prompt} [${default}/$( [[ "$default" == "y" ]] && echo n || echo y )]: " answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy]$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      INVENTORY="$2"
      shift 2
      ;;
    -p)
      VAULT_PASS_FILE="$2"
      shift 2
      ;;
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    --skip-preflight)
      RUN_PREFLIGHT=0
      shift
      ;;
    --skip-bootstrap)
      RUN_BOOTSTRAP=0
      shift
      ;;
    --skip-site)
      RUN_SITE=0
      shift
      ;;
    --skip-backup)
      RUN_BACKUP=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$ASSUME_YES" -eq 0 ]]; then
  read -r -p "Inventory path [${INVENTORY}]: " inventory_answer
  INVENTORY="${inventory_answer:-$INVENTORY}"

  read -r -p "Vault password file (leave blank to omit): " vault_answer
  VAULT_PASS_FILE="${vault_answer:-$VAULT_PASS_FILE}"

  prompt_yes_no "Run preflight?" y && RUN_PREFLIGHT=1 || RUN_PREFLIGHT=0
  prompt_yes_no "Run bootstrap?" y && RUN_BOOTSTRAP=1 || RUN_BOOTSTRAP=0
  prompt_yes_no "Run site deployment?" y && RUN_SITE=1 || RUN_SITE=0
  prompt_yes_no "Run backup setup?" y && RUN_BACKUP=1 || RUN_BACKUP=0
fi

ensure_local_config
[[ -f "$INVENTORY" ]] || { echo "ERROR: inventory not found: $INVENTORY" >&2; exit 1; }

VAULT_ARGS=()
if [[ -n "$VAULT_PASS_FILE" ]]; then
  [[ -f "$VAULT_PASS_FILE" ]] || { echo "ERROR: vault password file not found: $VAULT_PASS_FILE" >&2; exit 1; }
  VAULT_ARGS=(--vault-password-file "$VAULT_PASS_FILE")
fi

run_playbook() {
  local playbook="$1"
  echo "==> ${playbook}"
  ansible-playbook -i "$INVENTORY" "${VAULT_ARGS[@]}" "$playbook"
}

./scripts/install-collections.sh

[[ "$RUN_PREFLIGHT" -eq 1 ]] && run_playbook playbooks/preflight.yml
[[ "$RUN_BOOTSTRAP" -eq 1 ]] && run_playbook playbooks/bootstrap.yml
[[ "$RUN_SITE" -eq 1 ]] && run_playbook playbooks/site.yml
[[ "$RUN_BACKUP" -eq 1 ]] && run_playbook playbooks/backup.yml

echo "Deploy sequence complete."
