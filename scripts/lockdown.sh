#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

INVENTORY="inventories/prod/hosts.yml"
VAULT_PASS_FILE=""

usage() {
  cat <<'USAGE'
Usage: scripts/lockdown.sh [options]

Options:
  -i <inventory>           Inventory path (default: inventories/prod/hosts.yml)
  -p <vault pass file>     Optional Ansible Vault password file
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

echo "This playbook will allow SSH on tailscale0 and remove public SSH if enabled."
echo "Run it only after confirming you can reach the host over Tailscale."

ansible-playbook -i "$INVENTORY" "${VAULT_ARGS[@]}" playbooks/lockdown.yml
