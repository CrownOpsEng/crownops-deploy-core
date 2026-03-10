#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - <<'PY' "${ROOT_DIR}"
from pathlib import Path
import sys
import types

repo_root = Path(sys.argv[1])
sys.path.insert(0, str(repo_root))

ansible_config_wizard = types.ModuleType("ansible_config_wizard")
generators = types.ModuleType("ansible_config_wizard.generators")

counter = {"value": 0}


def generate_value(kind, params=None):
    if kind == "passphrase":
        counter["value"] += 1
        words = int((params or {}).get("words", 0))
        return f"generated-{words}-word-passphrase-{counter['value']}"
    raise SystemExit(f"unexpected generator request: {kind!r}")


generators.fingerprint = lambda value: f"fingerprint:{value}"
generators.generate_value = generate_value
ansible_config_wizard.generators = generators
sys.modules["ansible_config_wizard"] = ansible_config_wizard
sys.modules["ansible_config_wizard.generators"] = generators

from wizard_support.builders import build_crownops_deploy_core
from wizard_support.obsidian_livesync import decrypt_setup_uri

raw = {
    "repo_root": str(repo_root),
    "wizard_run_dir": str(repo_root / "tmp" / "wizard-run"),
    "host_name": "core-01",
    "base_domain": "example.com",
    "ops_domain": "ops.example.com",
    "ssh_setup_mode": "use_existing_public_keys",
    "ssh_pubkeys": ["ssh-ed25519 AAAATEST example@test"],
    "feature_obsidian_enabled": True,
    "obsidian_access_mode": "private_mesh",
    "obsidian_base_url": "http://core.example.ts.net:5984",
    "obsidian_vault_accounts": [
        {
            "name": "Chris",
            "db_name": "chris",
            "user": "chris",
            "password": "couch-password-1",
        }
    ],
    "restic_enabled": False,
    "restic_targets_input": [],
}

first = build_crownops_deploy_core(raw)
second = build_crownops_deploy_core(raw)

if "feature_obsidian_enabled" in first or "restic_targets" in first:
    raise SystemExit("builder should not expose removed flat inventory keys in rendered context")

if counter["value"] != 2:
    raise SystemExit(f"expected two generated passphrases, got {counter['value']}")

first_secret = first["vault_obsidian_livesync_bootstrap_accounts"]["chris"]
second_secret = second["vault_obsidian_livesync_bootstrap_accounts"]["chris"]
if first_secret != second_secret:
    raise SystemExit(f"expected bootstrap secrets to remain stable across builder calls, got {first_secret!r} vs {second_secret!r}")

first_handoff = first["obsidian_vault_handoffs"][0]
second_handoff = second["obsidian_vault_handoffs"][0]
if first_handoff["setup_uri"] != second_handoff["setup_uri"]:
    raise SystemExit("expected setup URI to remain stable across builder calls within the same run scope")

settings = decrypt_setup_uri(first_handoff["setup_uri"], first_handoff["setup_uri_passphrase"])
expected = {
    "couchDB_URI": "http://core.example.ts.net:5984",
    "couchDB_USER": "chris",
    "couchDB_PASSWORD": "couch-password-1",
    "couchDB_DBNAME": "chris",
    "passphrase": "generated-8-word-passphrase-1",
}
for key, value in expected.items():
    if settings.get(key) != value:
        raise SystemExit(f"unexpected {key}: {settings.get(key)!r}")

for key, value in {
    "encrypt": True,
    "usePathObfuscation": True,
    "syncOnStart": True,
    "periodicReplication": True,
    "syncOnFileOpen": True,
    "disableRequestURI": True,
    "settingVersion": 10,
}.items():
    if settings.get(key) != value:
        raise SystemExit(f"unexpected secure default {key}: {settings.get(key)!r}")

obsidian_config = first["features"]["obsidian_livesync"]
if not obsidian_config["enabled"]:
    raise SystemExit("expected obsidian feature config to stay enabled")
if obsidian_config["private_mesh"]["url_strategy"] != "tailscale_magicdns":
    raise SystemExit(f"unexpected private mesh strategy: {obsidian_config['private_mesh']['url_strategy']!r}")
if obsidian_config["base_url"] != "http://core.example.ts.net:5984":
    raise SystemExit(f"unexpected nested obsidian base URL: {obsidian_config['base_url']!r}")

print("builder obsidian setup URI generation smoke test passed")
PY
