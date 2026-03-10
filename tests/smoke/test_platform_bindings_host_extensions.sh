#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/tests/smoke/lib.bash"
TMP_DIR="$(create_smoke_tmpdir "${ROOT_DIR}")"
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
content = content.replace(
    "    https_port: 443\n    log_level: INFO\n",
    "    https_port: 443\n    log_level: INFO\n    routes:\n      - name: ops-dashboard\n        rule: Host(`ops.example.com`)\n        service_url: http://grafana:3000\n",
    1,
)
content = content.replace(
    "    jobs:\n",
    "    datasets:\n      - name: operator-notes\n        owner: operator\n        paths:\n          - /srv/operator-notes\n        tags:\n          - class:application-data\n    jobs:\n",
    1,
)
content = content.replace(
    "    requests: []\n",
    "    requests:\n      - name: ssh-public-alt\n        port: 2222\n        proto: tcp\n        from: any\n",
    1,
)
path.write_text(content)
PY

cat > "${TMP_DIR}/playbooks/platform-bindings.yml" <<'EOF'
---
- name: Compose extended platform bindings
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
    - name: Show effective Traefik contract
      ansible.builtin.debug:
        var: platform_host_traefik
    - name: Show effective restic contract
      ansible.builtin.debug:
        var: platform_host_restic
    - name: Show effective UFW contract
      ansible.builtin.debug:
        var: platform_host_ufw
EOF

OUTPUT="$(
  cd "${TMP_DIR}" &&
    ansible-playbook -i localhost, playbooks/platform-bindings.yml 2>&1
)"

for expected in 'ops-dashboard' 'obsidian-couchdb' 'operator-notes' 'workspace-data' 'ssh-public-alt' 'https-public'; do
  if [[ "${OUTPUT}" != *"${expected}"* ]]; then
    echo "expected merged platform contract output to include ${expected}" >&2
    printf '%s\n' "${OUTPUT}" >&2
    exit 1
  fi
done

printf 'platform bindings host extension merge smoke test passed\n'
