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
- nested `features.*` and `host.*` contract presence
- flat legacy inventory variables that should no longer exist
- Obsidian access mode, URL, CouchDB contract, and sync-account uniqueness
- public HTTPS bindings through `host.traefik`
- private mesh planning inputs and public-firewall leakage
- restic target and job structure under `host.restic`
- unsupported `host.restic.feature_owned_jobs`
- composed platform bindings such as ingress routes, datasets, and firewall requests
- path collisions between `vault_root` and `exports_root`
- restic repository and password placeholders
- broad backup dataset root warnings
- Tailscale auth and bootstrap placeholders
- placeholder marker sweep across key variables
- remote connectivity probe

## Output

The role writes a local report to:

- `reports/preflight-core_hosts.txt`

The playbook prints warnings and errors, then fails only after the full validation pass if any errors remain.
