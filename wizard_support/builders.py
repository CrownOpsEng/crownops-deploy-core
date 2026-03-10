from __future__ import annotations

import copy
import re
import shlex
from pathlib import Path
from typing import Any

from ansible_config_wizard.generators import fingerprint, generate_value

from wizard_support.obsidian_livesync import build_livesync_settings, build_setup_uri

_RESTIC_TARGET_KEYPAIR_CACHE: dict[tuple[str, str], dict[str, str]] = {}
_OBSIDIAN_LIVESYNC_BOOTSTRAP_SECRET_CACHE: dict[tuple[str, str], dict[str, str]] = {}
_OBSIDIAN_LIVESYNC_HANDOFF_CACHE: dict[tuple[str, str], dict[str, Any]] = {}


def sanitize_identifier(value: str) -> str:
    sanitized = re.sub(r"[^a-zA-Z0-9_]+", "_", value.strip().lower()).strip("_")
    return sanitized or "item"


def read_local_secret_file(path_value: str, repo_root: str) -> str:
    candidate = Path(path_value).expanduser()
    if not candidate.is_absolute():
        candidate = Path(repo_root) / candidate
    try:
        return candidate.read_text(encoding="utf-8").rstrip()
    except OSError as exc:
        raise ValueError(f"Unable to read secret file: {candidate}") from exc


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


def cached_restic_target_keypair(data: dict[str, Any], target_key: str) -> dict[str, str]:
    run_scope = str(data.get("wizard_run_dir") or data.get("repo_root") or "")
    cache_key = (run_scope, target_key)
    keypair = _RESTIC_TARGET_KEYPAIR_CACHE.get(cache_key)
    if keypair is None:
        keypair = generate_value("ed25519_keypair")
        _RESTIC_TARGET_KEYPAIR_CACHE[cache_key] = copy.deepcopy(keypair)
    return copy.deepcopy(keypair)


def cached_obsidian_livesync_handoff(
    data: dict[str, Any],
    account: dict[str, Any],
    bootstrap_secret: dict[str, str],
) -> dict[str, Any]:
    run_scope = str(data.get("wizard_run_dir") or data.get("repo_root") or "")
    cache_key = (run_scope, account["secret_key"])
    handoff = _OBSIDIAN_LIVESYNC_HANDOFF_CACHE.get(cache_key)
    if handoff is None:
        settings = build_livesync_settings(
            couchdb_uri=data["obsidian_base_url"],
            couchdb_user=account["user"],
            couchdb_password=account["password"],
            couchdb_dbname=account["db_name"],
            vault_passphrase=bootstrap_secret["vault_passphrase"],
        )
        handoff = {
            "name": account["name"],
            "secret_key": account["secret_key"],
            "couchdb_uri": data["obsidian_base_url"],
            "db_name": account["db_name"],
            "user": account["user"],
            "password": account["password"],
            "vault_passphrase": bootstrap_secret["vault_passphrase"],
            "setup_uri_passphrase": bootstrap_secret["setup_uri_passphrase"],
            "setup_uri": build_setup_uri(settings, bootstrap_secret["setup_uri_passphrase"]),
        }
        _OBSIDIAN_LIVESYNC_HANDOFF_CACHE[cache_key] = copy.deepcopy(handoff)
    return copy.deepcopy(handoff)


def cached_obsidian_livesync_bootstrap_secret(
    data: dict[str, Any],
    account_key: str,
    existing_secret: dict[str, str] | None = None,
) -> dict[str, str]:
    if existing_secret:
        return {
            "vault_passphrase": existing_secret["vault_passphrase"],
            "setup_uri_passphrase": existing_secret["setup_uri_passphrase"],
        }

    run_scope = str(data.get("wizard_run_dir") or data.get("repo_root") or "")
    cache_key = (run_scope, account_key)
    bootstrap_secret = _OBSIDIAN_LIVESYNC_BOOTSTRAP_SECRET_CACHE.get(cache_key)
    if bootstrap_secret is None:
        bootstrap_secret = {
            "vault_passphrase": generate_value("passphrase", {"words": 8}),
            "setup_uri_passphrase": generate_value("passphrase", {"words": 4}),
        }
        _OBSIDIAN_LIVESYNC_BOOTSTRAP_SECRET_CACHE[cache_key] = copy.deepcopy(bootstrap_secret)
    return copy.deepcopy(bootstrap_secret)


def build_crownops_deploy_core(raw: dict[str, Any]) -> dict[str, Any]:
    data = copy.deepcopy(raw)
    data["setup_command"] = "./scripts/setup.sh"
    data["deploy_command"] = "./scripts/deploy.sh"
    data["ssh_lockdown_command"] = "./scripts/ssh-lockdown.sh"
    host_name = data["host_name"]
    obsidian_enabled = bool(data.get("feature_obsidian_enabled", True))
    obsidian_access_mode = data.get("obsidian_access_mode") or "public_https"
    private_mesh_url_strategy = data.get("private_mesh_url_strategy") or "tailscale_magicdns"
    restic_enabled = bool(data.get("restic_enabled", True))

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

    if obsidian_enabled:
        if obsidian_access_mode == "public_https":
            data["obsidian_base_url"] = data.get("obsidian_base_url") or (
                f"https://{data['obsidian_service_subdomain']}.{data['ops_domain']}"
            )
            data["couchdb_bind_host"] = data.get("couchdb_bind_host") or "127.0.0.1"
        else:
            if private_mesh_url_strategy == "tailscale_magicdns" and data.get("tailscale_tailnet_name"):
                data["obsidian_base_url"] = data.get("obsidian_base_url") or (
                    f"http://{data['tailscale_hostname']}.{data['tailscale_tailnet_name']}.ts.net:{data['couchdb_port']}"
                )
            data["couchdb_bind_host"] = data.get("couchdb_bind_host") or "0.0.0.0"
        data["obsidian_cors_origins"] = copy.deepcopy(data.get("obsidian_cors_origins", []) or [])

        accounts = []
        account_passwords: dict[str, str] = {}
        existing_bootstrap_secrets = copy.deepcopy(data.get("vault_obsidian_livesync_bootstrap_accounts", {}) or {})
        bootstrap_secrets: dict[str, dict[str, str]] = {}
        obsidian_vault_handoffs = []
        for item in data.get("obsidian_vault_accounts", []):
            key = sanitize_identifier(item["name"])
            account_passwords[key] = item["password"]
            account = {
                "name": item["name"],
                "secret_key": key,
                "db_name": item.get("db_name") or f"vault_{key}",
                "user": item.get("user") or f"vault_{key}_user",
                "password": item["password"],
                "password_reference": f"{{{{ vault_couchdb_account_passwords.{key} }}}}",
            }
            accounts.append(account)
            bootstrap_secret = cached_obsidian_livesync_bootstrap_secret(
                data,
                key,
                existing_bootstrap_secrets.get(key),
            )
            bootstrap_secrets[key] = {
                "vault_passphrase": bootstrap_secret["vault_passphrase"],
                "setup_uri_passphrase": bootstrap_secret["setup_uri_passphrase"],
            }
            obsidian_vault_handoffs.append(
                cached_obsidian_livesync_handoff(data, account, bootstrap_secrets[key])
            )
        data["couchdb_vaults"] = accounts
        data["vault_couchdb_account_passwords"] = account_passwords
        data["vault_obsidian_livesync_bootstrap_accounts"] = bootstrap_secrets
        data["obsidian_vault_handoffs"] = obsidian_vault_handoffs
    else:
        data["couchdb_vaults"] = []
        data["vault_couchdb_account_passwords"] = {}
        data["vault_obsidian_livesync_bootstrap_accounts"] = {}
        data["vault_couchdb_admin_password"] = ""
        data["obsidian_base_url"] = ""
        data["obsidian_cors_origins"] = []
        data["obsidian_vault_handoffs"] = []

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
            keypair = cached_restic_target_keypair(data, key)
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
            if item.get("ssh_private_key_file"):
                ssh_private_key = read_local_secret_file(item["ssh_private_key_file"], data["repo_root"])
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
                "name": key,
                "display_name": item["name"],
                "repository": repository,
                "sftp_port": int(item.get("sftp_port", 22)),
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
    host_ufw_baseline_tcp_public = [int(port) for port in copy.deepcopy(data.get("ufw_allowed_tcp_public", []) or [])]
    if obsidian_enabled and obsidian_access_mode == "public_https" and 443 not in host_ufw_baseline_tcp_public:
        host_ufw_baseline_tcp_public.append(443)

    host_restic_jobs: list[dict[str, Any]] = []
    if restic_enabled:
        host_restic_jobs = [
            {
                "name": "host-foundation",
                "selector_tags": ["class:host-foundation"],
                "target_names": target_names,
            },
            {
                "name": "application-data",
                "selector_tags": ["class:application-data"],
                "target_names": target_names,
                "backup_schedule": "*-*-* 03:30:00",
                "backup_randomized_delay": "20m",
                "maintenance_schedule": "Sun *-*-* 05:30:00",
                "maintenance_randomized_delay": "30m",
                "retention_daily": 14,
                "retention_weekly": 8,
                "retention_monthly": 6,
            },
        ]

    data["features"] = {
        "obsidian_livesync": {
            "enabled": obsidian_enabled,
            "access_mode": obsidian_access_mode,
            "base_url": data.get("obsidian_base_url", ""),
            "private_mesh": {
                "url_strategy": private_mesh_url_strategy,
                "tailnet_name": data.get("tailscale_tailnet_name", ""),
            },
            "ingress": {
                "route_name": "obsidian-couchdb",
            },
            "couchdb": {
                "dir": data.get("couchdb_dir", "/opt/couchdb"),
                "container_name": data.get("couchdb_container_name", "couchdb"),
                "internal_network_name": data.get("internal_network_name", "internal"),
                "bind_host": data.get("couchdb_bind_host", ""),
                "port": int(data.get("couchdb_port", 5984)),
                "admin_user": data.get("couchdb_admin_user", "admin"),
                "admin_password": data["couchdb_admin_password_ref"],
                "cors_origins": data.get("obsidian_cors_origins", []),
                "vaults": data.get("couchdb_vaults", []),
            },
        }
    }
    data["host"] = {
        "traefik": {
            "enabled": obsidian_enabled and obsidian_access_mode == "public_https",
            "manage_mode": "managed",
            "layout_root": data.get("traefik_dir", "/opt/traefik"),
            "static_config_path": f"{data.get('traefik_dir', '/opt/traefik')}/traefik.yml",
            "dynamic_config_root": f"{data.get('traefik_dir', '/opt/traefik')}/dynamic",
            "dynamic_routes_dir": f"{data.get('traefik_dir', '/opt/traefik')}/dynamic/routes",
            "acme_storage_path": data.get("traefik_acme_storage", "/opt/traefik/acme/acme.json"),
            "proxy_network_name": data.get("traefik_network_name", "proxy"),
            "container_name": "traefik",
            "compose_project_name": "traefik",
            "certificate_resolver_name": data.get("traefik_certresolver_name", "dnsresolver"),
            "acme_email": data.get("traefik_acme_email", ""),
            "dns_provider": data.get("acme_dns_provider", ""),
            "dns_env": copy.deepcopy(data.get("acme_env", {}) or {}),
            "https_entrypoint_name": "websecure",
            "https_port": 443,
            "log_level": "INFO",
        },
        "restic": {
            "enabled": restic_enabled,
            "install_package": True,
            "package_name": "restic",
            "apt_cache_valid_time": int(data.get("restic_apt_cache_valid_time", 86400)),
            "backup_root": "/opt/crownops-backup",
            "targets_dir": "/opt/crownops-backup/targets",
            "jobs_dir": "/opt/crownops-backup/jobs",
            "passwords_dir": "/opt/crownops-backup/passwords",
            "backup_script_path": "/usr/local/sbin/crownops-restic-backup",
            "maintain_script_path": "/usr/local/sbin/crownops-restic-maintain",
            "ssh_dir": "/opt/crownops-backup/ssh",
            "targets": restic_targets,
            "jobs": host_restic_jobs,
            "feature_owned_jobs": [],
        },
        "ufw": {
            "enabled": True,
            "logging": "low",
            "default_incoming_policy": "deny",
            "default_outgoing_policy": "allow",
            "managed_state_dir": "/etc/crownops",
            "managed_state_file": "/etc/crownops/host-ufw-rules.json",
            "baseline_tcp_public": host_ufw_baseline_tcp_public,
            "baseline_udp_public": [int(port) for port in copy.deepcopy(data.get("ufw_allowed_udp_public", []) or [])],
            "requests": [],
        },
    }

    for legacy_key in [
        "feature_obsidian_enabled",
        "obsidian_access_mode",
        "private_mesh_url_strategy",
        "obsidian_service_subdomain",
        "obsidian_cors_origins",
        "acme_dns_provider",
        "acme_env",
        "ufw_allowed_tcp_public",
        "ufw_allowed_udp_public",
        "traefik_dir",
        "traefik_network_name",
        "traefik_certresolver_name",
        "traefik_acme_storage",
        "couchdb_dir",
        "couchdb_container_name",
        "couchdb_bind_host",
        "couchdb_port",
        "restic_enabled",
        "restic_apt_cache_valid_time",
        "restic_targets_input",
        "restic_targets",
        "restic_backup_jobs",
        "restic_backup_contributions",
    ]:
        data.pop(legacy_key, None)

    data["generated_secret_fingerprints"] = []
    if data.get("vault_couchdb_admin_password"):
        data["generated_secret_fingerprints"].append(
            {"label": "CouchDB admin password", "fingerprint": fingerprint(data["vault_couchdb_admin_password"])}
        )
    for key, value in data.get("vault_couchdb_account_passwords", {}).items():
        data["generated_secret_fingerprints"].append(
            {"label": f"CouchDB account password: {key}", "fingerprint": fingerprint(value)}
        )
    for key, value in data.get("vault_obsidian_livesync_bootstrap_accounts", {}).items():
        data["generated_secret_fingerprints"].append(
            {
                "label": f"Obsidian bootstrap vault passphrase: {key}",
                "fingerprint": fingerprint(value["vault_passphrase"]),
            }
        )
        data["generated_secret_fingerprints"].append(
            {
                "label": f"Obsidian setup URI passphrase: {key}",
                "fingerprint": fingerprint(value["setup_uri_passphrase"]),
            }
        )
    for key, value in data.get("vault_restic_target_secrets", {}).items():
        data["generated_secret_fingerprints"].append(
            {"label": f"Restic target password: {key}", "fingerprint": fingerprint(value["password"])}
        )

    data["vault_reference_summary"] = []
    return data
