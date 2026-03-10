#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/inventories/prod/group_vars" "${TMP_DIR}/playbooks" "${TMP_DIR}/roles" "${TMP_DIR}/scripts"
mkdir -p "${TMP_DIR}/inventories/prod/group_vars/all" "${TMP_DIR}/inventories/prod/group_vars/core_hosts"
cp "${ROOT_DIR}/ansible.cfg" "${TMP_DIR}/ansible.cfg"
cp "${ROOT_DIR}/scripts/init-local-config.sh" "${TMP_DIR}/scripts/init-local-config.sh"
cp "${ROOT_DIR}/playbooks/preflight.yml" "${TMP_DIR}/playbooks/preflight.yml"
cp -R "${ROOT_DIR}/roles/preflight_validate" "${TMP_DIR}/roles/preflight_validate"
cp "${ROOT_DIR}/inventories/prod/hosts.yml.example" "${TMP_DIR}/inventories/prod/hosts.yml.example"
cp "${ROOT_DIR}/inventories/prod/group_vars/all/main.yml.example" "${TMP_DIR}/inventories/prod/group_vars/all/main.yml.example"
cp "${ROOT_DIR}/inventories/prod/group_vars/all/vault.yml.example" "${TMP_DIR}/inventories/prod/group_vars/all/vault.yml.example"
cp "${ROOT_DIR}/inventories/prod/group_vars/core_hosts/main.yml.example" "${TMP_DIR}/inventories/prod/group_vars/core_hosts/main.yml.example"
printf 'test-only\n' > "${TMP_DIR}/.vault_pass"

(cd "${TMP_DIR}" && bash ./scripts/init-local-config.sh >/dev/null)

set +e
OUTPUT="$(
  cd "${TMP_DIR}" &&
    ANSIBLE_CONFIG="${TMP_DIR}/ansible.cfg" ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml 2>&1
)"
STATUS=$?
set -e

if [[ ${STATUS} -eq 0 ]]; then
  echo "expected scaffold preflight to fail on placeholder validation" >&2
  exit 1
fi

if [[ "${OUTPUT}" == *"is undefined"* ]]; then
  echo "preflight should report placeholder validation, not undefined-variable crashes" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

if [[ "${OUTPUT}" != *"Placeholder markers remain in inventory variables."* ]]; then
  echo "expected placeholder validation error in preflight output" >&2
  printf '%s\n' "${OUTPUT}" >&2
  exit 1
fi

printf 'preflight placeholder smoke test passed\n'
