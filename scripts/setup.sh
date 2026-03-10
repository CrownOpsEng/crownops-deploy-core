#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

WIZARD_PROJECT="${ANSIBLE_CONFIG_WIZARD_PROJECT:-${ROOT_DIR}/../ansible-config-wizard}"
WIZARD_BIN="${ANSIBLE_CONFIG_WIZARD_BIN:-}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: scripts/setup.sh [wizard options]

Primary interactive operator entrypoint for guided setup.

Common options:
  --answers-file <path>         Resume or pre-seed answers from YAML
  --vault-password-file <path>  Optional vault password file for non-interactive steps
  -y, --yes                     Use defaults or answers files without interactive prompts

Environment:
  ANSIBLE_CONFIG_WIZARD_PROJECT     Override the sibling wizard repo path
  ANSIBLE_CONFIG_WIZARD_BIN         Run an already-installed wizard binary instead
  ANSIBLE_CONFIG_WIZARD_STATE_HOME  Override wizard state storage
  ANSIBLE_CONFIG_WIZARD_SSH_HOME    Override managed SSH key storage
EOF
  exit 0
fi

if [[ -n "${WIZARD_BIN}" ]]; then
  exec "${WIZARD_BIN}" \
    --profile "${ROOT_DIR}/wizard_profiles/crownops-deploy-core.yml" \
    --repo-root "${ROOT_DIR}" \
    "$@"
fi

if [[ -f "${WIZARD_PROJECT}/pyproject.toml" ]]; then
  exec uv run --project "${WIZARD_PROJECT}" ansible-config-wizard \
    --profile "${ROOT_DIR}/wizard_profiles/crownops-deploy-core.yml" \
    --repo-root "${ROOT_DIR}" \
    "$@"
fi

exec uv tool run ansible-config-wizard \
  --profile "${ROOT_DIR}/wizard_profiles/crownops-deploy-core.yml" \
  --repo-root "${ROOT_DIR}" \
  "$@"
