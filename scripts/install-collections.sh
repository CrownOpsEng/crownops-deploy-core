#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_DIR="$(dirname "${ROOT_DIR}")"
COLLECTIONS_PATH="${ROOT_DIR}/.ansible/collections"
STATE_PATH="${ROOT_DIR}/.ansible/collection-state"
LOCAL_TEMP_PATH="${ROOT_DIR}/.ansible/tmp"
PUBLIC_REQUIREMENTS="${ROOT_DIR}/collections/requirements.yml"
BASE_COLLECTION_REMOTE_DEFAULT="git+https://github.com/CrownOpsEng/crownops-deploy-base.git"
SERVICES_COLLECTION_REMOTE_DEFAULT="git+https://github.com/CrownOpsEng/crownops-deploy-services.git"
REFRESH_COLLECTIONS="${CROWNOPS_COLLECTIONS_REFRESH:-0}"

resolve_collection_source() {
  local source_override="$1"
  local sibling_checkout_name="$2"
  local remote_default="$3"
  local sibling_checkout="${WORKSPACE_DIR}/${sibling_checkout_name}"

  if [[ -n "${source_override}" ]]; then
    echo "${source_override}"
    return 0
  fi

  if [[ -f "${sibling_checkout}/galaxy.yml" ]]; then
    echo "${sibling_checkout}"
    return 0
  fi

  echo "${remote_default}"
}

BASE_COLLECTION_SOURCE="$(
  resolve_collection_source \
    "${CROWNOPS_BASE_COLLECTION_SOURCE:-}" \
    "crownops-deploy-base" \
    "${BASE_COLLECTION_REMOTE_DEFAULT}"
)"
SERVICES_COLLECTION_SOURCE="$(
  resolve_collection_source \
    "${CROWNOPS_SERVICES_COLLECTION_SOURCE:-}" \
    "crownops-deploy-services" \
    "${SERVICES_COLLECTION_REMOTE_DEFAULT}"
)"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

retry() {
  local attempt rc
  for attempt in 1 2 3; do
    if "$@"; then
      return 0
    else
      rc=$?
    fi
    echo "attempt ${attempt} failed with rc=${rc}: $*" >&2
    if [ "$attempt" -lt 3 ]; then
      sleep 15
    fi
  done
  return "$rc"
}

is_truthy() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

slugify() {
  echo "$1" | tr '/: +' '____'
}

state_file() {
  echo "${STATE_PATH}/$(slugify "$1")"
}

write_state() {
  local key="$1"
  local value="$2"
  mkdir -p "${STATE_PATH}"
  printf '%s\n' "${value}" > "$(state_file "${key}")"
}

read_state() {
  local key="$1"
  local path
  path="$(state_file "${key}")"
  [[ -f "${path}" ]] || return 1
  cat "${path}"
}

state_matches() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(read_state "${key}" 2>/dev/null || true)"
  [[ -n "${actual}" && "${actual}" == "${expected}" ]]
}

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

requirements_names() {
  awk '/- name:/{print $3}' "$1"
}

collection_dir() {
  local fqcn="$1"
  local namespace="${fqcn%%.*}"
  local name="${fqcn#*.}"
  echo "${COLLECTIONS_PATH}/ansible_collections/${namespace}/${name}"
}

collection_installed() {
  local fqcn="$1"
  [[ -f "$(collection_dir "${fqcn}")/MANIFEST.json" ]]
}

all_collections_installed() {
  local fqcn
  for fqcn in "$@"; do
    collection_installed "${fqcn}" || return 1
  done
}

source_fingerprint() {
  local source="$1"
  if [[ -d "${source}/.git" ]]; then
    printf 'git:%s:%s\n' "$(cd "${source}" && pwd)" "$(git -C "${source}" rev-parse HEAD)"
    return 0
  fi
  if [[ -d "${source}" && -f "${source}/galaxy.yml" ]]; then
    printf 'dir:%s:%s\n' "$(cd "${source}" && pwd)" "$(sha256_file "${source}/galaxy.yml")"
    return 0
  fi
  printf 'source:%s\n' "${source}"
}

refresh_requested() {
  is_truthy "${REFRESH_COLLECTIONS}"
}

install_requirements() {
  local fingerprint
  local required=()
  local name
  fingerprint="$(sha256_file "${PUBLIC_REQUIREMENTS}")"
  while IFS= read -r name; do
    [[ -n "${name}" ]] && required+=("${name}")
  done < <(requirements_names "${PUBLIC_REQUIREMENTS}")

  if ! refresh_requested && state_matches "public-requirements" "${fingerprint}" && all_collections_installed "${required[@]}"; then
    echo "[1/4] Public collection dependencies already satisfy ${PUBLIC_REQUIREMENTS}; skipping."
    return 0
  fi

  echo "[1/4] Installing public collection dependencies into ${COLLECTIONS_PATH}"
  if retry ansible-galaxy collection install -p "${COLLECTIONS_PATH}" -r "${PUBLIC_REQUIREMENTS}" --upgrade; then
    write_state "public-requirements" "${fingerprint}"
    return 0
  fi

  if all_collections_installed "${required[@]}"; then
    echo "[1/4] WARNING: refresh failed; using existing installed public collections." >&2
    return 0
  fi

  die "Unable to install required public collections from ${PUBLIC_REQUIREMENTS}."
}

install_named_collection() {
  local step="$1"
  local fqcn="$2"
  local source="$3"
  local fingerprint
  fingerprint="$(source_fingerprint "${source}")"

  if ! refresh_requested && state_matches "${fqcn}" "${fingerprint}" && collection_installed "${fqcn}"; then
    echo "[${step}/4] ${fqcn} already matches ${source}; skipping."
    return 0
  fi

  echo "[${step}/4] Installing ${fqcn} from ${source}"
  if retry ansible-galaxy collection install -p "${COLLECTIONS_PATH}" "${source}" --force; then
    write_state "${fqcn}" "${fingerprint}"
    return 0
  fi

  if collection_installed "${fqcn}"; then
    echo "[${step}/4] WARNING: refresh failed; using existing installed ${fqcn} collection." >&2
    return 0
  fi

  die "Unable to install ${fqcn} from ${source}."
}

command -v ansible-galaxy >/dev/null 2>&1 || die "ansible-galaxy is required on the control host."
[[ -f "${PUBLIC_REQUIREMENTS}" ]] || die "Missing requirements file: ${PUBLIC_REQUIREMENTS}"

mkdir -p "${COLLECTIONS_PATH}"
mkdir -p "${STATE_PATH}"
mkdir -p "${LOCAL_TEMP_PATH}"

chmod 700 "${LOCAL_TEMP_PATH}"
export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-${LOCAL_TEMP_PATH}}"

install_requirements
install_named_collection 2 "crownops.deploy_base" "${BASE_COLLECTION_SOURCE}"
install_named_collection 3 "crownops.deploy_services" "${SERVICES_COLLECTION_SOURCE}"

echo "[4/4] Installed collections into ${COLLECTIONS_PATH}"

echo "Collections ready."
