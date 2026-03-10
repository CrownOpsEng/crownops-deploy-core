#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - <<'PY' "${ROOT_DIR}"
from pathlib import Path
import types
import sys

repo_root = Path(sys.argv[1])
sys.path.insert(0, str(repo_root))

ansible_config_wizard = types.ModuleType("ansible_config_wizard")
generators = types.ModuleType("ansible_config_wizard.generators")

counter = {"value": 0}

def generate_value(kind):
    counter["value"] += 1
    value = counter["value"]
    return {
        "private_key": f"test-private-key-{value}",
        "public_key": f"ssh-ed25519 AAAATEST{value} generated-{value}@test",
        "fingerprint": f"generated-fingerprint-{value}",
    }

generators.fingerprint = lambda value: f"fingerprint:{value}"
generators.generate_value = generate_value
ansible_config_wizard.generators = generators
sys.modules["ansible_config_wizard"] = ansible_config_wizard
sys.modules["ansible_config_wizard.generators"] = generators

from wizard_support.builders import build_crownops_deploy_core

raw = {
    "repo_root": str(repo_root),
    "wizard_run_dir": str(repo_root / "tmp" / "wizard-run"),
    "host_name": "core-01",
    "base_domain": "example.com",
    "ops_domain": "ops.example.com",
    "ssh_setup_mode": "use_existing_public_keys",
    "ssh_pubkeys": ["ssh-ed25519 AAAATEST example@test"],
    "feature_obsidian_enabled": False,
    "restic_enabled": True,
    "restic_targets_input": [
        {
            "name": "H4F",
            "target_mode": "sftp_ssh",
            "sftp_user": "core-backup",
            "sftp_host": "backup.example.com",
            "sftp_path": "/srv/restic/core",
            "password": "secret-1",
            "generate_ssh_key": True,
            "bootstrap_with_ansible": True,
            "bootstrap_ssh_user": "crown",
            "bootstrap_use_sudo": True,
            "bootstrap_manage_sftp_user": True,
        }
    ],
}

first = build_crownops_deploy_core(raw)
second = build_crownops_deploy_core(raw)

if counter["value"] != 1:
    raise SystemExit(f"expected generated restic keypair to be cached across builder calls, got {counter['value']} generations")

expected_public_key = "ssh-ed25519 AAAATEST1 generated-1@test"
expected_private_key = "test-private-key-1"

for result in (first, second):
    public_keys = [item["public_key"] for item in result["generated_ssh_public_keys"] if item["label"] == "restic target H4F"]
    if public_keys != [expected_public_key]:
        raise SystemExit(f"unexpected generated public keys: {public_keys!r}")

    setup_note = result["restic_target_setup_notes"][0]
    if setup_note["public_key"] != expected_public_key:
        raise SystemExit(f"unexpected setup-note public key: {setup_note['public_key']!r}")

    command = result["backup_destination_bootstrap_plans"][0]["command"]
    if expected_public_key not in command:
        raise SystemExit(f"expected bootstrap command to include current public key, got: {command!r}")

    private_key = result["vault_restic_target_secrets"]["h4f"]["ssh_private_key"]
    if private_key != expected_private_key:
        raise SystemExit(f"unexpected vault private key: {private_key!r}")

print("builder restic target keypair consistency smoke test passed")
PY
