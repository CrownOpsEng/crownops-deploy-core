#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_DIR="$(dirname "${ROOT_DIR}")"
COLLECTIONS_PATH="${ROOT_DIR}/.ansible/collections"
PUBLIC_REQUIREMENTS="${ROOT_DIR}/collections/requirements.yml"
BASE_COLLECTION_REMOTE_DEFAULT="git+https://github.com/CrownOpsEng/crownops-deploy-base.git"
SERVICES_COLLECTION_REMOTE_DEFAULT="git+https://github.com/CrownOpsEng/crownops-deploy-services.git"

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

command -v ansible-galaxy >/dev/null 2>&1 || die "ansible-galaxy is required on the control host."
[[ -f "${PUBLIC_REQUIREMENTS}" ]] || die "Missing requirements file: ${PUBLIC_REQUIREMENTS}"

mkdir -p "${COLLECTIONS_PATH}"

echo "[1/4] Installing public collection dependencies into ${COLLECTIONS_PATH}"
retry ansible-galaxy collection install -p "${COLLECTIONS_PATH}" -r "${PUBLIC_REQUIREMENTS}" --force

echo "[2/4] Installing crownops.deploy_base from ${BASE_COLLECTION_SOURCE}"
retry ansible-galaxy collection install -p "${COLLECTIONS_PATH}" "${BASE_COLLECTION_SOURCE}" --force

echo "[3/4] Installing crownops.deploy_services from ${SERVICES_COLLECTION_SOURCE}"
retry ansible-galaxy collection install -p "${COLLECTIONS_PATH}" "${SERVICES_COLLECTION_SOURCE}" --force

echo "[4/4] Installed collections into ${COLLECTIONS_PATH}"

echo "Collections ready."
