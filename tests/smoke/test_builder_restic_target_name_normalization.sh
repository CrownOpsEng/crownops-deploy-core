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
generators.fingerprint = lambda value: f"fingerprint:{value}"
generators.generate_value = lambda kind: {
    "private_key": "test-private-key",
    "public_key": "ssh-ed25519 AAAATEST generated@test",
    "fingerprint": "generated-fingerprint",
}
ansible_config_wizard.generators = generators
sys.modules["ansible_config_wizard"] = ansible_config_wizard
sys.modules["ansible_config_wizard.generators"] = generators

from wizard_support.builders import build_crownops_deploy_core

result = build_crownops_deploy_core(
    {
        "repo_root": str(repo_root),
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
                "sftp_user": "backup",
                "sftp_host": "backup.example.com",
                "sftp_port": 2222,
                "sftp_path": "/srv/restic/core",
                "password": "secret-1",
            },
            {
                "name": "Laptop Backup",
                "target_mode": "local_path",
                "local_path": "/srv/restic/laptop",
                "password": "secret-2",
            },
        ],
    }
)

if "restic_targets" in result or "restic_backup_jobs" in result or "restic_backup_contributions" in result:
    raise SystemExit("builder should not expose removed flat backup keys")

target_names = [item["name"] for item in result["host"]["restic"]["targets"]]
if target_names != ["h4f", "laptop_backup"]:
    raise SystemExit(f"unexpected normalized restic target names: {target_names!r}")

if result["host"]["restic"]["targets"][0]["sftp_port"] != 2222:
    raise SystemExit(f"expected first restic target to preserve sftp_port, got {result['host']['restic']['targets'][0]['sftp_port']!r}")

for job in result["host"]["restic"]["jobs"]:
    if job["target_names"] != ["h4f", "laptop_backup"]:
        raise SystemExit(f"unexpected backup job target names: {job['target_names']!r}")
    if "selector_tags" not in job:
        raise SystemExit(f"expected dataset selector_tags in nested restic job, got {job!r}")

vault_keys = list(result["vault_restic_target_secrets"].keys())
if vault_keys != ["h4f", "laptop_backup"]:
    raise SystemExit(f"unexpected vault target secret keys: {vault_keys!r}")

application_job = next(job for job in result["host"]["restic"]["jobs"] if job["name"] == "application-data")
if application_job["selector_tags"] != ["class:application-data"]:
    raise SystemExit(f"unexpected application-data dataset selectors: {application_job['selector_tags']!r}")
if result["host"]["traefik"]["enabled"]:
    raise SystemExit("traefik should stay disabled for the non-obsidian builder scenario")

obsidian_result = build_crownops_deploy_core(
    {
        "repo_root": str(repo_root),
        "host_name": "core-01",
        "base_domain": "example.com",
        "ops_domain": "ops.example.com",
        "ssh_setup_mode": "use_existing_public_keys",
        "ssh_pubkeys": ["ssh-ed25519 AAAATEST example@test"],
        "feature_obsidian_enabled": True,
        "obsidian_access_mode": "public_https",
        "obsidian_service_subdomain": "notes",
        "traefik_acme_email": "ops@example.com",
        "acme_dns_provider": "cloudflare",
        "acme_env": {"CF_DNS_API_TOKEN": "token"},
        "restic_enabled": True,
        "restic_targets_input": [
            {
                "name": "Primary",
                "target_mode": "local_path",
                "local_path": "/srv/restic/primary",
                "password": "secret-1",
            }
        ],
    }
)

if not obsidian_result["host"]["traefik"]["enabled"]:
    raise SystemExit("expected public_https obsidian deployment to enable nested host traefik config")

obsidian_job_targets = [job["target_names"] for job in obsidian_result["host"]["restic"]["jobs"]]
if obsidian_job_targets != [["primary"], ["primary"]]:
    raise SystemExit(f"unexpected nested restic job targets: {obsidian_job_targets!r}")

if obsidian_result["features"]["obsidian_livesync"]["ingress"]["route_name"] != "obsidian-couchdb":
    raise SystemExit("expected obsidian ingress route name in nested feature contract")

print("builder restic target name normalization smoke test passed")
PY
