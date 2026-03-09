#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLLECTIONS_PATH="${ROOT_DIR}/.ansible/collections"
PUBLIC_REQUIREMENTS="${ROOT_DIR}/collections/requirements.yml"
BASE_REPO_DEFAULT="${ROOT_DIR}/../../000-vps-base/crownops-vps-base"
BASE_REPO="${CROWNOPS_VPS_BASE_REPO:-${BASE_REPO_DEFAULT}}"
BUILD_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT

die() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v ansible-galaxy >/dev/null 2>&1 || die "ansible-galaxy is required on the control host."
[[ -f "${PUBLIC_REQUIREMENTS}" ]] || die "Missing requirements file: ${PUBLIC_REQUIREMENTS}"
[[ -f "${BASE_REPO}/galaxy.yml" ]] || die "Base collection repo not found at ${BASE_REPO}"

mkdir -p "${COLLECTIONS_PATH}"

echo "[1/3] Installing public collection dependencies into ${COLLECTIONS_PATH}"
ansible-galaxy collection install -p "${COLLECTIONS_PATH}" -r "${PUBLIC_REQUIREMENTS}"

echo "[2/3] Building local base collection from ${BASE_REPO}"
ansible-galaxy collection build "${BASE_REPO}" --output-path "${BUILD_DIR}" >/dev/null

BASE_ARTIFACT="$(find "${BUILD_DIR}" -maxdepth 1 -type f -name '*-vps_base-*.tar.gz' | head -n 1)"
[[ -n "${BASE_ARTIFACT}" ]] || die "Failed to build the vps_base collection artifact."

echo "[3/3] Installing vps_base into ${COLLECTIONS_PATH}"
ansible-galaxy collection install -p "${COLLECTIONS_PATH}" "${BASE_ARTIFACT}" --force

echo "Collections ready."
