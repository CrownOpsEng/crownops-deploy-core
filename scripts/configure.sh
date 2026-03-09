#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

WIZARD_PROJECT="${ANSIBLE_CONFIG_WIZARD_PROJECT:-${ROOT_DIR}/../ansible-config-wizard}"
WIZARD_BIN="${ANSIBLE_CONFIG_WIZARD_BIN:-}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: scripts/configure.sh [wizard options]

Repo-local wrapper for the configuration wizard.

Common options:
  --answers-file <path>     Pre-seed answers from YAML
  -y, --yes                 Non-interactive mode for defaults or answers files
  --encrypt-vault           Encrypt inventories/prod/group_vars/vault.yml after write
  --skip-encrypt-vault      Skip vault encryption
  --run-preflight           Run playbooks/preflight.yml after write
  --skip-preflight          Skip preflight

Environment:
  ANSIBLE_CONFIG_WIZARD_PROJECT  Override the sibling wizard repo path
  ANSIBLE_CONFIG_WIZARD_BIN      Run an already-installed wizard binary instead
  ANSIBLE_CONFIG_WIZARD_STATE_HOME  Override where wizard state and generated bootstrap keys are stored

The repo profile and repo root are provided by this wrapper automatically.
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
