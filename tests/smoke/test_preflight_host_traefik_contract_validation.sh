#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/tests/smoke/lib.bash"
TMP_DIR="$(create_smoke_tmpdir "${ROOT_DIR}")"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/inventories/prod/group_vars/all" "${TMP_DIR}/inventories/prod/group_vars/core_hosts" "${TMP_DIR}/playbooks" "${TMP_DIR}/roles" "${TMP_DIR}/scripts"
cp "${ROOT_DIR}/ansible.cfg" "${TMP_DIR}/ansible.cfg"
cp "${ROOT_DIR}/scripts/init-local-config.sh" "${TMP_DIR}/scripts/init-local-config.sh"
cp "${ROOT_DIR}/playbooks/preflight.yml" "${TMP_DIR}/playbooks/preflight.yml"
cp -R "${ROOT_DIR}/roles/preflight_validate" "${TMP_DIR}/roles/preflight_validate"
cp -R "${ROOT_DIR}/roles/platform_bindings" "${TMP_DIR}/roles/platform_bindings"
cp "${ROOT_DIR}/inventories/prod/hosts.yml.example" "${TMP_DIR}/inventories/prod/hosts.yml.example"
cp "${ROOT_DIR}/inventories/prod/group_vars/all/main.yml.example" "${TMP_DIR}/inventories/prod/group_vars/all/main.yml.example"
cp "${ROOT_DIR}/inventories/prod/group_vars/all/vault.yml.example" "${TMP_DIR}/inventories/prod/group_vars/all/vault.yml.example"
cp "${ROOT_DIR}/inventories/prod/group_vars/core_hosts/main.yml.example" "${TMP_DIR}/inventories/prod/group_vars/core_hosts/main.yml.example"
printf 'test-only\n' > "${TMP_DIR}/.vault_pass"

(cd "${TMP_DIR}" && bash ./scripts/init-local-config.sh >/dev/null)

sed -i "s/203.0.113.10/192.0.2.10/" "${TMP_DIR}/inventories/prod/hosts.yml"
sed -i "s/example.invalid/example.com/g" "${TMP_DIR}/inventories/prod/group_vars/all/main.yml"
sed -i "s/change-me@example.com/ops@example.com/g" "${TMP_DIR}/inventories/prod/group_vars/all/main.yml"
sed -i "s/REPLACE_ME/test-value/g" "${TMP_DIR}/inventories/prod/group_vars/all/main.yml"
sed -i "s/REPLACE_ME/test-secret/g" "${TMP_DIR}/inventories/prod/group_vars/all/vault.yml"
python3 - <<'PY' "${TMP_DIR}/inventories/prod/group_vars/all/main.yml"
from pathlib import Path
import sys
import yaml

path = Path(sys.argv[1])
content = yaml.safe_load(path.read_text())
content["features"]["obsidian_livesync"]["enabled"] = False
content["features"]["obsidian_livesync"]["access_mode"] = "private_mesh"
content["host"]["traefik"]["enabled"] = True
content["host"]["traefik"]["dns_env"] = {}
content["host"]["traefik"]["routes"] = [
    {
        "name": "admin",
        "rule": "Host(`admin.example.com`)",
        "service_url": "http://admin:8080",
        "entrypoints": ["websecure"],
    }
]
path.write_text(yaml.safe_dump(content, sort_keys=False))
PY

set +e
OUTPUT="$(
  cd "${TMP_DIR}" &&
    ANSIBLE_CONFIG="${TMP_DIR}/ansible.cfg" ansible-playbook -e preflight_validate_remote_connectivity=false -i inventories/prod/hosts.yml playbooks/preflight.yml 2>&1
)"
STATUS=$?
set -e

if [[ ${STATUS} -eq 0 ]]; then
  echo "expected preflight to fail when enabled host.traefik is missing dns_env" >&2
  exit 1
fi

if [[ "${OUTPUT}" != *"host.traefik.enabled=true requires layout_root, static_config_path, dynamic_config_root, dynamic_routes_dir, acme_storage_path, proxy_network_name, container_name, certificate_resolver_name, acme_email, dns_provider, and dns_env."* ]]; then
  echo "expected host.traefik contract validation error in preflight output" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

printf 'preflight host.traefik contract validation smoke test passed\n'
