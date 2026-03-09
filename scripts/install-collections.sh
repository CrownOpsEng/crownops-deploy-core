#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLLECTIONS_PATH="${ROOT_DIR}/.ansible/collections"
PUBLIC_REQUIREMENTS="${ROOT_DIR}/collections/requirements.yml"
BASE_COLLECTION_SOURCE="${CROWNOPS_BASE_COLLECTION_SOURCE:-git+https://github.com/CrownOpsEng/crownops-deploy-base.git}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

retry() {
  local attempt rc
  for attempt in 1 2 3; do
    if "$@"; then
      return 0
    fi
    rc=$?
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

echo "[1/3] Installing public collection dependencies into ${COLLECTIONS_PATH}"
retry ansible-galaxy collection install -p "${COLLECTIONS_PATH}" -r "${PUBLIC_REQUIREMENTS}" --force

echo "[2/3] Installing crownops.deploy_base from ${BASE_COLLECTION_SOURCE}"
retry ansible-galaxy collection install -p "${COLLECTIONS_PATH}" "${BASE_COLLECTION_SOURCE}" --force

echo "[3/3] Installed collections into ${COLLECTIONS_PATH}"

echo "Collections ready."
