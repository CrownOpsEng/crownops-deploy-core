#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

INVENTORY="inventories/prod/hosts.yml"
VAULT_PASS_FILE=""
ENABLE_LOCKDOWN=1
CONFIRM_LOCKDOWN=0

usage() {
  cat <<'USAGE'
Usage: scripts/lockdown.sh [options]

Options:
  -i <inventory>           Inventory path (default: inventories/prod/hosts.yml)
  -p <vault pass file>     Optional Ansible Vault password file
  --phase1-only            Run validation-only lockdown phase and preserve public SSH
  --confirm                Confirm restrictive SSH changes if runtime checks pass
  -h, --help               Show this help
USAGE
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

VAULT_ARGS=()
if [[ -n "$VAULT_PASS_FILE" ]]; then
  [[ -f "$VAULT_PASS_FILE" ]] || { echo "ERROR: vault password file not found: $VAULT_PASS_FILE" >&2; exit 1; }
  VAULT_ARGS=(--vault-password-file "$VAULT_PASS_FILE")
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
