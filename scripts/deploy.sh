#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

INVENTORY="inventories/prod/hosts.yml"
VAULT_FILE="inventories/prod/group_vars/vault.yml"
VAULT_PASS_FILE=""
CONFIGURED_VAULT_PASS_FILE=""
ASK_VAULT_PASS=0
ASSUME_YES=0
RUN_PREFLIGHT=1
RUN_BOOTSTRAP=1
RUN_SITE=1
RUN_BACKUP=1
RUN_LOCKDOWN=0
CONFIRM_LOCKDOWN=0

usage() {
  cat <<'USAGE'
Usage: scripts/deploy.sh [options]

Options:
  -i <inventory>           Inventory path (default: inventories/prod/hosts.yml)
  -p <vault pass file>     Optional Ansible Vault password file
  --ask-vault-pass         Prompt for the Ansible Vault password interactively
  -y, --yes                Non-interactive mode; accept defaults
  --skip-preflight         Skip preflight
  --skip-bootstrap         Skip bootstrap
  --skip-site              Skip site deployment
  --skip-backup            Skip backup configuration
  --enable-lockdown        Run the staged SSH lockdown phase after deployment phases
  --confirm-lockdown       Confirm restrictive SSH changes during the lockdown phase
  --lockdown               Deprecated alias for --enable-lockdown
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
  if [[ -x "./scripts/configure.sh" ]]; then
    echo "Run ./scripts/configure.sh to generate local config and secrets."
  else
    echo "Bootstrapping local working files from tracked .example files."
    ./scripts/init-local-config.sh
    echo "Edit the generated local files, encrypt inventories/prod/group_vars/vault.yml, then rerun deploy."
  fi
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

configured_vault_password_file() {
  if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
    printf '%s\n' "${ANSIBLE_VAULT_PASSWORD_FILE}"
    return 0
  fi
  [[ -f "${ROOT_DIR}/ansible.cfg" ]] || return 0
  awk -F '=' '
    /^[[:space:]]*vault_password_file[[:space:]]*=/ {
      value=$2
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "${ROOT_DIR}/ansible.cfg"
}

is_encrypted_vault_file() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  local first_line
  IFS= read -r first_line < "$path" || true
  [[ "$first_line" == \$ANSIBLE_VAULT\;* ]]
}

expand_path() {
  local value="$1"
  if [[ "$value" == "~/"* ]]; then
    printf '%s\n' "${HOME}/${value#~/}"
    return 0
  fi
  printf '%s\n' "$value"
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
    --ask-vault-pass)
      ASK_VAULT_PASS=1
      shift
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
    --enable-lockdown)
      RUN_LOCKDOWN=1
      shift
      ;;
    --confirm-lockdown)
      CONFIRM_LOCKDOWN=1
      shift
      ;;
    --lockdown)
      RUN_LOCKDOWN=1
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

CONFIGURED_VAULT_PASS_FILE="$(configured_vault_password_file)"
CONFIGURED_VAULT_PASS_FILE="$(expand_path "$CONFIGURED_VAULT_PASS_FILE")"
if [[ -n "$VAULT_PASS_FILE" ]]; then
  VAULT_PASS_FILE="$(expand_path "$VAULT_PASS_FILE")"
fi

if [[ "$ASSUME_YES" -eq 0 ]]; then
  read -r -p "Inventory path [${INVENTORY}]: " inventory_answer
  INVENTORY="${inventory_answer:-$INVENTORY}"

  if [[ -n "$VAULT_PASS_FILE" ]]; then
    read -r -p "Vault password file (leave blank to prompt for the vault password when needed) [${VAULT_PASS_FILE}]: " vault_answer
    VAULT_PASS_FILE="${vault_answer:-$VAULT_PASS_FILE}"
  elif [[ -n "$CONFIGURED_VAULT_PASS_FILE" && -f "$CONFIGURED_VAULT_PASS_FILE" ]]; then
    read -r -p "Vault password file (leave blank to use ${CONFIGURED_VAULT_PASS_FILE}, or type a different path): " vault_answer
    VAULT_PASS_FILE="${vault_answer:-$CONFIGURED_VAULT_PASS_FILE}"
  else
    if [[ -n "$CONFIGURED_VAULT_PASS_FILE" ]]; then
      echo "Configured default vault password file: ${CONFIGURED_VAULT_PASS_FILE}"
    fi
    read -r -p "Vault password file (leave blank to prompt for the vault password when needed): " vault_answer
    VAULT_PASS_FILE="$vault_answer"
  fi
  if [[ -n "$VAULT_PASS_FILE" ]]; then
    VAULT_PASS_FILE="$(expand_path "$VAULT_PASS_FILE")"
  fi

  prompt_yes_no "Run preflight?" y && RUN_PREFLIGHT=1 || RUN_PREFLIGHT=0
  prompt_yes_no "Run bootstrap?" y && RUN_BOOTSTRAP=1 || RUN_BOOTSTRAP=0
  prompt_yes_no "Run site deployment?" y && RUN_SITE=1 || RUN_SITE=0
  prompt_yes_no "Run backup setup?" y && RUN_BACKUP=1 || RUN_BACKUP=0
  prompt_yes_no "Run staged SSH lockdown phase?" n && RUN_LOCKDOWN=1 || RUN_LOCKDOWN=0
  if [[ "$RUN_LOCKDOWN" -eq 1 ]]; then
    prompt_yes_no "Confirm restrictive SSH changes if runtime checks pass?" n && CONFIRM_LOCKDOWN=1 || CONFIRM_LOCKDOWN=0
  fi
fi

if [[ "$CONFIRM_LOCKDOWN" -eq 1 && "$RUN_LOCKDOWN" -eq 0 ]]; then
  echo "ERROR: --confirm-lockdown requires --enable-lockdown." >&2
  exit 2
fi

ensure_local_config
[[ -f "$INVENTORY" ]] || { echo "ERROR: inventory not found: $INVENTORY" >&2; exit 1; }

if [[ -n "$VAULT_PASS_FILE" && "$ASK_VAULT_PASS" -eq 1 ]]; then
  echo "ERROR: choose either -p <vault pass file> or --ask-vault-pass, not both." >&2
  exit 2
fi

VAULT_ARGS=()
if [[ -n "$VAULT_PASS_FILE" ]]; then
  [[ -f "$VAULT_PASS_FILE" ]] || { echo "ERROR: vault password file not found: $VAULT_PASS_FILE" >&2; exit 1; }
  VAULT_ARGS=(--vault-password-file "$VAULT_PASS_FILE")
elif [[ -n "$CONFIGURED_VAULT_PASS_FILE" && -f "$CONFIGURED_VAULT_PASS_FILE" ]]; then
  VAULT_ARGS=(--vault-password-file "$CONFIGURED_VAULT_PASS_FILE")
elif [[ "$ASK_VAULT_PASS" -eq 1 ]]; then
  VAULT_ARGS=(--ask-vault-pass)
elif [[ -f "$VAULT_FILE" ]] && is_encrypted_vault_file "$VAULT_FILE"; then
  VAULT_ARGS=(--ask-vault-pass)
fi

run_playbook() {
  local playbook="$1"
  shift || true
  echo "==> ${playbook}"
  ansible-playbook -i "$INVENTORY" "${VAULT_ARGS[@]}" "$playbook" "$@"
}

./scripts/install-collections.sh

[[ "$RUN_PREFLIGHT" -eq 1 ]] && run_playbook playbooks/preflight.yml
[[ "$RUN_BOOTSTRAP" -eq 1 ]] && run_playbook playbooks/bootstrap.yml
[[ "$RUN_SITE" -eq 1 ]] && run_playbook playbooks/site.yml
[[ "$RUN_BACKUP" -eq 1 ]] && run_playbook playbooks/backup.yml
if [[ "$RUN_LOCKDOWN" -eq 1 ]]; then
  if [[ "$CONFIRM_LOCKDOWN" -eq 0 ]]; then
    echo "==> lockdown phase requested without explicit confirmation; runtime checks will run but public SSH will be preserved."
  fi
  run_playbook playbooks/lockdown.yml -e "lockdown_enabled=true" -e "lockdown_confirmed=${CONFIRM_LOCKDOWN}"
fi

echo "Deploy sequence complete."
