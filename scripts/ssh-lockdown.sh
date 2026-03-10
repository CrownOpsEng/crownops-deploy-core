#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source "${ROOT_DIR}/scripts/lib/ansible-runner.sh"

INVENTORY="inventories/prod/hosts.yml"
VAULT_FILE="inventories/prod/group_vars/vault.yml"
VAULT_PASS_FILE=""
ASK_VAULT_PASS=0
CONFIRM_LOCKDOWN=0

usage() {
  cat <<'USAGE'
Usage: scripts/ssh-lockdown.sh [options]

Lower-level staged SSH hardening runner.

Options:
  -i <inventory>               Inventory path (default: inventories/prod/hosts.yml)
  --vault-password-file <path> Vault password file
  --ask-vault-pass            Prompt for the vault password interactively
  --confirm                   Confirm restrictive SSH changes if runtime checks pass
  --phase1-only               Validation-only alias; preserve public SSH
  -h, --help                  Show this help
USAGE
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
    --confirm)
      CONFIRM_LOCKDOWN=1
      shift
      ;;
    --phase1-only)
      CONFIRM_LOCKDOWN=0
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

runner_require_file "${INVENTORY}"
runner_resolve_vault_args "${ROOT_DIR}" "${VAULT_FILE}" "${VAULT_PASS_FILE}" "${ASK_VAULT_PASS}"

echo "This runner uses staged lockdown gates."
echo "Without --confirm, it runs validation-only checks and preserves public SSH."
echo "Use --confirm only after verifying restrictive SSH access."

ansible-playbook \
  -i "${INVENTORY}" \
  "${RUNNER_VAULT_ARGS[@]}" \
  playbooks/lockdown.yml \
  -e "lockdown_enabled=true" \
  -e "lockdown_confirmed=${CONFIRM_LOCKDOWN}"
