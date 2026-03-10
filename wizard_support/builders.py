from __future__ import annotations

import copy
import re
import shlex
from typing import Any

from ansible_config_wizard.generators import fingerprint, generate_value


def sanitize_identifier(value: str) -> str:
    sanitized = re.sub(r"[^a-zA-Z0-9_]+", "_", value.strip().lower()).strip("_")
    return sanitized or "item"


def build_backup_target_bootstrap_command(
    data: dict[str, Any],
    item: dict[str, Any],
    ssh_public_key: str,
) -> str:
    parts = [
        "./scripts/bootstrap-backup-target.sh",
        "--target-name",
        item["name"],
        "--host",
        item["sftp_host"],
        "--port",
        str(item.get("sftp_port", 22)),
        "--bootstrap-ssh-user",
        item["bootstrap_ssh_user"],
        "--target-user",
        item["sftp_user"],
        "--repository-path",
        item["sftp_path"],
        "--public-key",
        ssh_public_key,
    ]
    if item.get("bootstrap_use_sudo", True):
        parts.append("--use-sudo")
    if item.get("bootstrap_manage_sftp_user", False):
        parts.append("--manage-target-user")
    if item.get("bootstrap_ssh_private_key_file"):
        parts.extend(["--private-key-file", item["bootstrap_ssh_private_key_file"]])
    return " ".join(shlex.quote(part) for part in parts)


def build_crownops_deploy_core(raw: dict[str, Any]) -> dict[str, Any]:
    data = copy.deepcopy(raw)
    host_name = data["host_name"]
    data["feature_obsidian_enabled"] = bool(data.get("feature_obsidian_enabled", True))
    data["obsidian_access_mode"] = data.get("obsidian_access_mode") or "public_https"
    data["private_mesh_url_strategy"] = data.get("private_mesh_url_strategy") or "tailscale_magicdns"

    data["ops_domain"] = data.get("ops_domain") or f"ops.{data['base_domain']}"
    data["tailscale_hostname"] = data.get("tailscale_hostname") or host_name
    data["tailscale_auth_key"] = data.get("tailscale_auth_key") or ""

    data["couchdb_admin_password_ref"] = "{{ vault_couchdb_admin_password }}"
    data["tailscale_auth_key_ref"] = "{{ vault_tailscale_auth_key | default('') }}"

    generated_ssh_public_keys: list[dict[str, str]] = []
    ssh_pubkeys = copy.deepcopy(data.get("ssh_pubkeys", []) or [])
    data["ansible_ssh_private_key_file"] = ""
    if data.get("ssh_setup_mode") == "generate_managed_key":
        managed_keypair = data.get("managed_ssh_keypair") or {}
        managed_public_key = managed_keypair.get("public_key", "").strip()
        if managed_public_key:
            ssh_pubkeys = [managed_public_key, *copy.deepcopy(data.get("additional_ssh_pubkeys", []) or [])]
            data["ansible_ssh_private_key_file"] = managed_keypair.get("private_key_path", "")
            generated_ssh_public_keys.append(
                {
                    "label": f"managed ansible access for {host_name}",
                    "public_key": managed_public_key,
                    "fingerprint": managed_keypair.get("fingerprint", ""),
                    "private_key_path": managed_keypair.get("private_key_path", ""),
                    "public_key_path": managed_keypair.get("public_key_path", ""),
                }
            )
    data["ssh_pubkeys"] = ssh_pubkeys

    if data.get("feature_obsidian_enabled", False):
        if data["obsidian_access_mode"] == "public_https":
            data["obsidian_base_url"] = data.get("obsidian_base_url") or (
                f"https://{data['obsidian_service_subdomain']}.{data['ops_domain']}"
            )
            data["couchdb_bind_host"] = data.get("couchdb_bind_host") or "127.0.0.1"
        else:
            if data["private_mesh_url_strategy"] == "tailscale_magicdns" and data.get("tailscale_tailnet_name"):
                data["obsidian_base_url"] = data.get("obsidian_base_url") or (
                    f"http://{data['tailscale_hostname']}.{data['tailscale_tailnet_name']}.ts.net:{data['couchdb_port']}"
                )
            data["couchdb_bind_host"] = data.get("couchdb_bind_host") or "0.0.0.0"
        data["obsidian_cors_origins"] = copy.deepcopy(data.get("obsidian_cors_origins", []) or [])

        accounts = []
        account_passwords: dict[str, str] = {}
        for item in data.get("obsidian_vault_accounts", []):
            key = sanitize_identifier(item["name"])
            account_passwords[key] = item["password"]
            accounts.append(
                {
                    "name": item["name"],
                    "secret_key": key,
                    "db_name": item.get("db_name") or f"vault_{key}",
                    "user": item.get("user") or f"vault_{key}_user",
                    "password_reference": f"{{{{ vault_couchdb_account_passwords.{key} }}}}",
                }
            )
        data["couchdb_vaults"] = accounts
        data["vault_couchdb_account_passwords"] = account_passwords
    else:
        data["couchdb_vaults"] = []
        data["vault_couchdb_account_passwords"] = {}
        data["vault_couchdb_admin_password"] = ""
        data["obsidian_base_url"] = ""
        data["obsidian_cors_origins"] = []

    restic_targets = []
    vault_restic_target_secrets: dict[str, dict[str, Any]] = {}
    restic_target_setup_notes = []
    backup_destination_bootstrap_plans = []
    for item in data.get("restic_targets_input", []):
        key = sanitize_identifier(item["name"])
        target_mode = item.get("target_mode") or "sftp_ssh"
        repository = item.get("repository", "")
        known_hosts = item.get("ssh_known_hosts", "") or ""
        if target_mode == "sftp_ssh":
            repository = f"sftp:{item['sftp_user']}@{item['sftp_host']}:{item['sftp_path']}"
        elif target_mode == "local_path":
            repository = item["local_path"]

        if target_mode == "sftp_ssh" and item.get("generate_ssh_key", False):
            keypair = generate_value("ed25519_keypair")
            ssh_private_key = keypair["private_key"]
            ssh_public_key = keypair["public_key"]
            generated_ssh_public_keys.append(
                {
                    "label": f"restic target {item['name']}",
                    "public_key": ssh_public_key,
                    "fingerprint": keypair["fingerprint"],
                }
            )
        else:
            ssh_private_key = item.get("ssh_private_key", "")
            ssh_public_key = item.get("ssh_public_key", "")
            if ssh_public_key:
                generated_ssh_public_keys.append(
                    {
                        "label": f"restic target {item['name']}",
                        "public_key": ssh_public_key,
                        "fingerprint": fingerprint(ssh_public_key),
                    }
                )

        if target_mode == "sftp_ssh":
            restic_target_setup_notes.append(
                {
                    "name": item["name"],
                    "host": item["sftp_host"],
                    "port": item.get("sftp_port", 22),
                    "user": item["sftp_user"],
                    "path": item["sftp_path"],
                    "repository": repository,
                    "public_key": ssh_public_key,
                    "known_hosts": known_hosts,
                }
            )
            if item.get("bootstrap_with_ansible", False) and ssh_public_key:
                backup_destination_bootstrap_plans.append(
                    {
                        "name": item["name"],
                        "bootstrap_enabled": True,
                        "host": item["sftp_host"],
                        "port": item.get("sftp_port", 22),
                        "bootstrap_ssh_user": item.get("bootstrap_ssh_user") or item["sftp_user"],
                        "target_user": item["sftp_user"],
                        "repository_path": item["sftp_path"],
                        "bootstrap_use_sudo": bool(item.get("bootstrap_use_sudo", True)),
                        "bootstrap_manage_sftp_user": bool(item.get("bootstrap_manage_sftp_user", False)),
                        "command": build_backup_target_bootstrap_command(data, item, ssh_public_key),
                    }
                )

        vault_restic_target_secrets[key] = {
            "password": item["password"],
            "ssh_private_key": ssh_private_key or "",
            "ssh_known_hosts": known_hosts,
            "environment": item.get("environment", {}) or {},
        }

        restic_targets.append(
            {
                "name": item["name"],
                "repository": repository,
                "password_reference": f"{{{{ vault_restic_target_secrets.{key}.password }}}}",
                "ssh_private_key_reference": f"{{{{ vault_restic_target_secrets.{key}.ssh_private_key | default('') }}}}",
                "ssh_known_hosts_reference": f"{{{{ vault_restic_target_secrets.{key}.ssh_known_hosts | default('') }}}}",
                "environment_reference": f"{{{{ vault_restic_target_secrets.{key}.environment | default({{}}) }}}}",
            }
        )

    data["restic_targets"] = restic_targets
    data["vault_restic_target_secrets"] = vault_restic_target_secrets
    data["generated_ssh_public_keys"] = generated_ssh_public_keys
    data["restic_target_setup_notes"] = restic_target_setup_notes
    data["backup_destination_bootstrap_plans"] = backup_destination_bootstrap_plans

    target_names = [item["name"] for item in restic_targets]
    if data.get("restic_enabled", True) and target_names:
        host_foundation_paths = ["/etc/ssh", "/etc/fail2ban", "/etc/ufw"]
        if data.get("feature_obsidian_enabled", False) and data.get("obsidian_access_mode") == "public_https":
            host_foundation_paths.append("/opt/traefik")

        data["restic_backup_jobs"] = [
            {
                "name": "host-foundation",
                "paths": host_foundation_paths,
                "target_names": target_names,
                "tags": ["profile:stateful-app", "class:host"],
            },
            {
                "name": "application-data",
                "paths": [],
                "target_names": target_names,
                "backup_schedule": "*-*-* 03:30:00",
                "backup_randomized_delay": "20m",
                "maintenance_schedule": "Sun *-*-* 05:30:00",
                "maintenance_randomized_delay": "30m",
                "retention_daily": 14,
                "retention_weekly": 8,
                "retention_monthly": 6,
                "tags": ["profile:stateful-app", "class:data"],
            },
        ]
        restic_backup_contributions = []
        if data.get("feature_obsidian_enabled", False) and data.get("obsidian_access_mode") == "public_https":
            restic_backup_contributions.append(
                {
                    "job": "host-foundation",
                    "paths": ["/opt/traefik"],
                    "tags": ["feature:edge-proxy"],
                }
            )
        if data.get("feature_obsidian_enabled", False):
            restic_backup_contributions.append(
                {
                    "job": "application-data",
                    "paths": ["/opt/couchdb", "/srv/crownops"],
                    "pre_commands": ["docker compose -f /opt/couchdb/docker-compose.yml stop couchdb"],
                    "post_commands": ["docker compose -f /opt/couchdb/docker-compose.yml start couchdb"],
                    "tags": ["feature:obsidian-livesync"],
                }
            )
        data["restic_backup_contributions"] = restic_backup_contributions
    else:
        data["restic_backup_jobs"] = []
        data["restic_backup_contributions"] = []
        data["restic_enabled"] = False

    data["generated_secret_fingerprints"] = []
    if data.get("vault_couchdb_admin_password"):
        data["generated_secret_fingerprints"].append(
            {"label": "CouchDB admin password", "fingerprint": fingerprint(data["vault_couchdb_admin_password"])}
        )
    for key, value in data.get("vault_couchdb_account_passwords", {}).items():
        data["generated_secret_fingerprints"].append(
            {"label": f"CouchDB account password: {key}", "fingerprint": fingerprint(value)}
        )
    for key, value in data.get("vault_restic_target_secrets", {}).items():
        data["generated_secret_fingerprints"].append(
            {"label": f"Restic target password: {key}", "fingerprint": fingerprint(value["password"])}
        )

    data["vault_reference_summary"] = []
    return data
