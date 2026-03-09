# Preflight Validation

This package includes an aggregated preflight validation layer.

## Goal

Surface as many configuration and topology issues as possible in one pass, then fail once at the end.

## Playbook

```bash
ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml
```

## What it checks

- inventory group population
- host placeholder values
- `ansible_host` placeholder or loopback values
- `ansible_user` and `bootstrap_ansible_user` presence
- base and ops domain presence and placeholder values
- SSH public key population
- Ubuntu release selector validity
- HTTPS firewall exposure for Traefik on TCP 443 when enabled features require it
- Traefik ACME email and DNS provider configuration
- ACME provider env placeholders
- CouchDB admin credentials when Obsidian is enabled
- synced Obsidian account definitions
- duplicate vault names, database names, or users
- placeholder synced account passwords
- path collisions between `vault_root` and `exports_root`
- restic repository and password placeholders
- Tailscale auth and bootstrap placeholders
- placeholder marker sweep across key variables
- remote connectivity probe

## Output

The role writes a local report to:

- `reports/preflight-core_hosts.txt`

The playbook prints warnings and errors, then fails only after the full validation pass if any errors remain.
