#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

target_name=""
host=""
port="22"
bootstrap_ssh_user=""
target_user=""
repository_path=""
public_key=""
private_key_file=""
use_sudo=0
manage_target_user=0
ask_pass=0
ask_become=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-name)
      target_name="$2"
      shift 2
      ;;
    --host)
      host="$2"
      shift 2
      ;;
    --port)
      port="$2"
      shift 2
      ;;
    --bootstrap-ssh-user)
      bootstrap_ssh_user="$2"
      shift 2
      ;;
    --target-user)
      target_user="$2"
      shift 2
      ;;
    --repository-path)
      repository_path="$2"
      shift 2
      ;;
    --public-key)
      public_key="$2"
      shift 2
      ;;
    --private-key-file)
      private_key_file="$2"
      shift 2
      ;;
    --use-sudo)
      use_sudo=1
      shift
      ;;
    --manage-target-user)
      manage_target_user=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: scripts/bootstrap-backup-target.sh [options]

Bootstrap an SFTP backup destination with Ansible.

Required:
  --target-name NAME
  --host HOST
  --bootstrap-ssh-user USER
  --target-user USER
  --repository-path PATH
  --public-key KEY

Optional:
  --port PORT
  --private-key-file PATH
  --use-sudo
  --manage-target-user
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${target_name}" || -z "${host}" || -z "${bootstrap_ssh_user}" || -z "${target_user}" || -z "${repository_path}" || -z "${public_key}" ]]; then
  echo "Missing required arguments. Use --help for usage." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmpdir}"
}
trap cleanup EXIT

verify_ssh_access() {
  local ssh_command=(
    ssh
    -o BatchMode=no
    -o ConnectTimeout=10
    -p "${port}"
  )

  if [[ -n "${private_key_file}" ]]; then
    ssh_command+=(-i "${private_key_file}")
  fi

  ssh_command+=("${bootstrap_ssh_user}@${host}" true)

  printf 'Verifying SSH access with a direct probe before Ansible...\n'
  printf '  %q' "${ssh_command[@]}"
  printf '\n\n'
  "${ssh_command[@]}"
}

inventory_file="${tmpdir}/inventory.yml"
vars_file="${tmpdir}/vars.json"

python3 - <<'PY' "${inventory_file}" "${host}" "${bootstrap_ssh_user}" "${port}" "${private_key_file}"
import sys

path, host, ssh_user, port, private_key_file = sys.argv[1:]
lines = [
    "all:",
    "  children:",
    "    backup_destination:",
    "      hosts:",
    "        target:",
    f"          ansible_host: {host!r}",
    f"          ansible_user: {ssh_user!r}",
    f"          ansible_port: {int(port)}",
    "          ansible_python_interpreter: auto_silent",
]
if private_key_file:
    lines.append(f"          ansible_ssh_private_key_file: {private_key_file!r}")
with open(path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines) + "\n")
PY

python3 - <<'PY' "${vars_file}" "${use_sudo}" "${target_user}" "${manage_target_user}" "${repository_path}" "${public_key}"
import json
import sys

path, use_sudo, target_user, manage_target_user, repository_path, public_key = sys.argv[1:]
payload = {
    "backup_target_bootstrap_become": use_sudo == "1",
    "backup_target_account": target_user,
    "backup_target_manage_user": manage_target_user == "1",
    "backup_target_repository_path": repository_path,
    "backup_target_authorized_keys": [public_key],
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY

printf '\nBootstrapping backup destination "%s"\n' "${target_name}"
printf '  Host: %s:%s\n' "${host}" "${port}"
printf '  Setup user: %s\n' "${bootstrap_ssh_user}"
printf '  Target user: %s\n' "${target_user}"
printf '  Repository path: %s\n\n' "${repository_path}"

if [[ -x "${ROOT_DIR}/scripts/install-collections.sh" ]]; then
  printf 'Refreshing required Ansible collections...\n\n'
  "${ROOT_DIR}/scripts/install-collections.sh"
fi

choices=("Use existing SSH access")
if [[ "${use_sudo}" -eq 1 ]]; then
  choices+=("Prompt for sudo password")
fi
choices+=("Prompt for SSH password")
if [[ "${use_sudo}" -eq 1 ]]; then
  choices+=("Prompt for SSH and sudo passwords")
fi
choices+=("Cancel")

printf 'Choose how Ansible should connect:\n'
select choice in "${choices[@]}"; do
  case "${choice:-}" in
    "Use existing SSH access")
      break
      ;;
    "Prompt for sudo password")
      ask_become=1
      break
      ;;
    "Prompt for SSH password")
      ask_pass=1
      break
      ;;
    "Prompt for SSH and sudo passwords")
      ask_pass=1
      ask_become=1
      break
      ;;
    "Cancel")
      exit 0
      ;;
    *)
      printf 'Select one of the listed options.\n'
      ;;
  esac
done

if [[ "${ask_pass:-0}" -eq 0 ]]; then
  verify_ssh_access
  printf '\n'
fi

command=(
  ansible-playbook
  -i "${inventory_file}"
  playbooks/backup-target-bootstrap.yml
  -e "@${vars_file}"
)

if [[ "${ask_pass:-0}" -eq 1 ]]; then
  command+=(--ask-pass)
fi
if [[ "${ask_become:-0}" -eq 1 ]]; then
  command+=(--ask-become-pass)
fi

printf '\nRunning:\n'
printf '  %q' "${command[@]}"
printf '\n\n'
"${command[@]}"
