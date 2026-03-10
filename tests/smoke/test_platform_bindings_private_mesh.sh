#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/inventories/prod/group_vars/all" "${TMP_DIR}/playbooks/roles"
cp -R "${ROOT_DIR}/roles/platform_bindings" "${TMP_DIR}/playbooks/roles/platform_bindings"
cp "${ROOT_DIR}/inventories/prod/group_vars/all/main.yml.example" "${TMP_DIR}/inventories/prod/group_vars/all/main.yml"
cp "${ROOT_DIR}/inventories/prod/group_vars/all/vault.yml.example" "${TMP_DIR}/inventories/prod/group_vars/all/vault.yml"

sed -i "s/example.invalid/example.com/g" "${TMP_DIR}/inventories/prod/group_vars/all/main.yml"
sed -i "s/change-me@example.com/ops@example.com/g" "${TMP_DIR}/inventories/prod/group_vars/all/main.yml"
sed -i "s/REPLACE_ME/test-value/g" "${TMP_DIR}/inventories/prod/group_vars/all/main.yml"
sed -i "s/REPLACE_ME/test-secret/g" "${TMP_DIR}/inventories/prod/group_vars/all/vault.yml"
python3 - <<'PY' "${TMP_DIR}/inventories/prod/group_vars/all/main.yml"
from pathlib import Path
import sys

path = Path(sys.argv[1])
content = path.read_text()
content = content.replace("access_mode: public_https", "access_mode: private_mesh")
content = content.replace("base_url: https://notes.ops.example.com", "base_url: http://core-01.tailnet.ts.net:5984")
content = content.replace("tailnet_name: \"\"", "tailnet_name: tailnet")
content = content.replace("  traefik:\n    enabled: true", "  traefik:\n    enabled: false", 1)
content = content.replace("      bind_host: 127.0.0.1", "      bind_host: 0.0.0.0")
path.write_text(content)
PY

cat > "${TMP_DIR}/playbooks/platform-bindings.yml" <<'EOF'
---
- name: Compose private mesh platform bindings
  hosts: localhost
  connection: local
  gather_facts: false
  pre_tasks:
    - name: Load inventory variables
      ansible.builtin.include_vars:
        file: "{{ item }}"
      loop:
        - "{{ playbook_dir }}/../inventories/prod/group_vars/all/main.yml"
        - "{{ playbook_dir }}/../inventories/prod/group_vars/all/vault.yml"
  roles:
    - role: platform_bindings
  tasks:
    - name: Show composed ingress routes
      ansible.builtin.debug:
        var: platform_ingress_routes
    - name: Show composed backup datasets
      ansible.builtin.debug:
        var: platform_backup_datasets
    - name: Show composed ufw requests
      ansible.builtin.debug:
        var: platform_ufw_requests
EOF

OUTPUT="$(
  cd "${TMP_DIR}" &&
    ansible-playbook -i localhost, playbooks/platform-bindings.yml 2>&1
)"

if [[ "${OUTPUT}" != *"\"platform_ingress_routes\": []"* ]]; then
  echo "expected private mesh bindings to skip ingress route composition" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

if [[ "${OUTPUT}" != *"obsidian-couchdb-data"* ]]; then
  echo "expected private mesh bindings to keep the obsidian dataset" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

if [[ "${OUTPUT}" != *"\"platform_ufw_requests\": []"* ]]; then
  echo "expected private mesh bindings to skip public https ufw requests" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

printf 'platform bindings private_mesh smoke test passed\n'
