#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source "${ROOT_DIR}/scripts/lib/ansible-runner.sh"

INVENTORY="inventories/prod/hosts.yml"
VAULT_FILE="inventories/prod/group_vars/vault.yml"
VAULT_PASS_FILE=""
ASK_VAULT_PASS=0
RUN_COLLECTIONS=1
RUN_PREFLIGHT=1
RUN_BOOTSTRAP=1
RUN_SITE=1
RUN_BACKUP=1

usage() {
  cat <<'USAGE'
Usage: scripts/deploy.sh [options]

Lower-level deployment runner for explicit Ansible phases.

Options:
  -i <inventory>               Inventory path (default: inventories/prod/hosts.yml)
  --vault-password-file <path> Vault password file
  --ask-vault-pass            Prompt for the vault password interactively
  --skip-collections          Skip collection installation
  --skip-preflight            Skip preflight
  --skip-bootstrap            Skip bootstrap
  --skip-site                 Skip site deployment
  --skip-backup               Skip backup setup
  -h, --help                  Show this help
USAGE
}

ensure_local_config() {
  local required_files=(
    "inventories/prod/hosts.yml"
    "inventories/prod/group_vars/all.yml"
    "inventories/prod/group_vars/core_hosts.yml"
    "inventories/prod/group_vars/vault.yml"
  )
  local file
  for file in "${required_files[@]}"; do
    if [[ ! -f "${file}" ]]; then
      echo "Local deployment config is missing." >&2
      echo "Run ./scripts/setup.sh to generate local config and secrets." >&2
      exit 1
    fi
  done
}

run_playbook() {
  local playbook="$1"
  shift || true
  echo "==> ${playbook}"
  ansible-playbook -i "${INVENTORY}" "${RUNNER_VAULT_ARGS[@]}" "${playbook}" "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      INVENTORY="$2"
      shift 2
      ;;
    --vault-password-file|-p)
      VAULT_PASS_FILE="$2"
      shift 2
      ;;
    --ask-vault-pass)
      ASK_VAULT_PASS=1
      shift
      ;;
    --skip-collections)
      RUN_COLLECTIONS=0
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

ensure_local_config
runner_require_file "${INVENTORY}"
runner_resolve_vault_args "${ROOT_DIR}" "${VAULT_FILE}" "${VAULT_PASS_FILE}" "${ASK_VAULT_PASS}"

if [[ "${RUN_COLLECTIONS}" -eq 1 ]]; then
  "${ROOT_DIR}/scripts/install-collections.sh"
fi
if [[ "${RUN_PREFLIGHT}" -eq 1 ]]; then
  run_playbook playbooks/preflight.yml
fi
if [[ "${RUN_BOOTSTRAP}" -eq 1 ]]; then
  run_playbook playbooks/bootstrap.yml
fi
if [[ "${RUN_SITE}" -eq 1 ]]; then
  run_playbook playbooks/site.yml
fi
if [[ "${RUN_BACKUP}" -eq 1 ]]; then
  run_playbook playbooks/backup.yml
fi

echo "Deployment sequence complete."
