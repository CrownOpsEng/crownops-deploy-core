#!/usr/bin/env bash
set -euo pipefail

runner_die() {
  echo "ERROR: $*" >&2
  exit 1
}

runner_expand_path() {
  local value="$1"
  if [[ "$value" == "~/"* ]]; then
    printf '%s\n' "${HOME}/${value#~/}"
    return 0
  fi
  printf '%s\n' "$value"
}

runner_is_encrypted_vault_file() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  local first_line
  IFS= read -r first_line < "$path" || true
  [[ "$first_line" == \$ANSIBLE_VAULT\;* ]]
}

runner_configured_vault_password_file() {
  local root_dir="$1"
  if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
    printf '%s\n' "${ANSIBLE_VAULT_PASSWORD_FILE}"
    return 0
  fi
  [[ -f "${root_dir}/ansible.cfg" ]] || return 0
  awk -F '=' '
    /^[[:space:]]*vault_password_file[[:space:]]*=/ {
      value=$2
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "${root_dir}/ansible.cfg"
}

runner_default_repo_vault_password_file() {
  local root_dir="$1"
  if [[ -f "${root_dir}/.vault_pass" ]]; then
    printf '%s\n' "${root_dir}/.vault_pass"
  fi
}

runner_require_file() {
  local path="$1"
  [[ -f "$path" ]] || runner_die "file not found: $path"
}

runner_resolve_vault_args() {
  local root_dir="$1"
  local vault_file="$2"
  local explicit_vault_password_file="${3:-}"
  local ask_vault_pass="${4:-0}"

  if [[ -n "${explicit_vault_password_file}" && "${ask_vault_pass}" -eq 1 ]]; then
    runner_die "choose either --vault-password-file or --ask-vault-pass, not both"
  fi

  RUNNER_VAULT_ARGS=()
  if ! runner_is_encrypted_vault_file "${vault_file}"; then
    return 0
  fi

  local candidate=""
  if [[ -n "${explicit_vault_password_file}" ]]; then
    candidate="$(runner_expand_path "${explicit_vault_password_file}")"
  elif [[ "${ask_vault_pass}" -eq 1 ]]; then
    RUNNER_VAULT_ARGS=(--ask-vault-pass)
    return 0
  else
    candidate="$(runner_configured_vault_password_file "${root_dir}")"
    if [[ -z "${candidate}" ]]; then
      candidate="$(runner_default_repo_vault_password_file "${root_dir}")"
    fi
    if [[ -n "${candidate}" ]]; then
      candidate="$(runner_expand_path "${candidate}")"
    fi
  fi

  if [[ -n "${candidate}" ]]; then
    runner_require_file "${candidate}"
    RUNNER_VAULT_ARGS=(--vault-password-file "${candidate}")
    return 0
  fi

  runner_die \
    "vault access is required for ${vault_file}. Provide --ask-vault-pass, provide --vault-password-file, set ANSIBLE_VAULT_PASSWORD_FILE, or create .vault_pass."
}
