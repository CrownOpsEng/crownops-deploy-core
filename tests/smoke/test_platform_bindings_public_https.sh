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

cat > "${TMP_DIR}/playbooks/platform-bindings.yml" <<'EOF'
---
- name: Compose public HTTPS platform bindings
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
    - name: Show composed obsidian contract
      ansible.builtin.debug:
        var: platform_obsidian_livesync
EOF

OUTPUT="$(
  cd "${TMP_DIR}" &&
    ansible-playbook -i localhost, playbooks/platform-bindings.yml 2>&1
)"

if [[ "${OUTPUT}" != *"obsidian-couchdb"* ]]; then
  echo "expected public HTTPS bindings to compose the obsidian ingress route" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

if [[ "${OUTPUT}" != *"traefik-acme"* ]]; then
  echo "expected public HTTPS bindings to compose the traefik acme dataset" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

if [[ "${OUTPUT}" != *"https-public"* ]]; then
  echo "expected public HTTPS bindings to compose the https ufw request" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

if [[ "${OUTPUT}" != *"shared_network_name\": \"proxy"* ]]; then
  echo "expected public HTTPS bindings to hand the proxy network to obsidian" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

printf 'platform bindings public_https smoke test passed\n'
