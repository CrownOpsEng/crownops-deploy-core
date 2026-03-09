#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

copy_if_missing() {
  local target="$1"
  local example="${target}.example"

  if [[ -f "${target}" ]]; then
    echo "exists: ${target}"
    return 0
  fi

  if [[ ! -f "${example}" ]]; then
    echo "ERROR: missing example file: ${example}" >&2
    return 1
  fi

  cp "${example}" "${target}"
  echo "created: ${target} (from ${example})"
}

copy_if_missing "inventories/prod/hosts.yml"
copy_if_missing "inventories/prod/group_vars/all.yml"
copy_if_missing "inventories/prod/group_vars/core_hosts.yml"
copy_if_missing "inventories/prod/group_vars/vault.yml"

cat <<'EOF'

Local config scaffolded from examples.
Next steps:
1. For guided setup, prefer ./scripts/configure.sh.
2. Fill inventories/prod/hosts.yml with real hosts and SSH users.
3. Fill inventories/prod/group_vars/all.yml with real non-secret settings.
4. Put secret values in inventories/prod/group_vars/vault.yml.
5. Encrypt inventories/prod/group_vars/vault.yml with ansible-vault.
EOF
