#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

INVENTORY="inventories/prod/hosts.yml"
VAULT_FILE="inventories/prod/group_vars/vault.yml"
VAULT_PASS_FILE=""
CONFIGURED_VAULT_PASS_FILE=""
ASK_VAULT_PASS=0
ENABLE_LOCKDOWN=1
CONFIRM_LOCKDOWN=0

usage() {
  cat <<'USAGE'
Usage: scripts/lockdown.sh [options]

Options:
  -i <inventory>           Inventory path (default: inventories/prod/hosts.yml)
  -p <vault pass file>     Optional Ansible Vault password file
  --ask-vault-pass         Prompt for the Ansible Vault password interactively
  --phase1-only            Run validation-only lockdown phase and preserve public SSH
  --confirm                Confirm restrictive SSH changes if runtime checks pass
  -h, --help               Show this help
USAGE
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

prompt_for_vault_access() {
  echo "Encrypted vault detected at ${VAULT_FILE}."
  if [[ -n "$CONFIGURED_VAULT_PASS_FILE" ]]; then
    echo "Configured default vault password file: ${CONFIGURED_VAULT_PASS_FILE}"
  fi
  PS3="Vault access method: "
  local options=(
    "Prompt for vault password interactively"
    "Use vault password file"
  )
  select choice in "${options[@]}"; do
    case "${choice:-}" in
      "Prompt for vault password interactively")
        ASK_VAULT_PASS=1
        return 0
        ;;
      "Use vault password file")
        if [[ -n "$CONFIGURED_VAULT_PASS_FILE" ]]; then
          read -r -p "Vault password file [${CONFIGURED_VAULT_PASS_FILE}]: " vault_answer
          VAULT_PASS_FILE="${vault_answer:-$CONFIGURED_VAULT_PASS_FILE}"
        else
          read -r -p "Vault password file: " vault_answer
          VAULT_PASS_FILE="$vault_answer"
        fi
        VAULT_PASS_FILE="$(expand_path "$VAULT_PASS_FILE")"
        return 0
        ;;
      *)
        echo "Select one of the listed options."
        ;;
    esac
  done
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
    --phase1-only)
      ENABLE_LOCKDOWN=1
      CONFIRM_LOCKDOWN=0
      shift
      ;;
    --confirm)
      CONFIRM_LOCKDOWN=1
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

[[ -f "$INVENTORY" ]] || { echo "ERROR: inventory not found: $INVENTORY" >&2; exit 1; }

CONFIGURED_VAULT_PASS_FILE="$(configured_vault_password_file)"
CONFIGURED_VAULT_PASS_FILE="$(expand_path "$CONFIGURED_VAULT_PASS_FILE")"
if [[ -n "$VAULT_PASS_FILE" ]]; then
  VAULT_PASS_FILE="$(expand_path "$VAULT_PASS_FILE")"
elif [[ -f "$VAULT_FILE" ]] && is_encrypted_vault_file "$VAULT_FILE" && [[ -t 0 ]]; then
  prompt_for_vault_access
fi

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

if [[ "$CONFIRM_LOCKDOWN" -eq 1 && "$ENABLE_LOCKDOWN" -eq 0 ]]; then
  echo "ERROR: --confirm requires lockdown to be enabled." >&2
  exit 2
fi

echo "This playbook uses staged lockdown gates."
echo "Without --confirm, it runs phase-one checks and preserves public SSH."
echo "Use --confirm only after verifying SSH over Tailscale or another restrictive path."

ansible-playbook -i "$INVENTORY" "${VAULT_ARGS[@]}" playbooks/lockdown.yml \
  -e "lockdown_enabled=${ENABLE_LOCKDOWN}" \
  -e "lockdown_confirmed=${CONFIRM_LOCKDOWN}"
