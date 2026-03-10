# Deployment Sequence

## 1. Run the guided setup flow

Preferred path:

- `./scripts/setup.sh`

The guided workflow is organized into phases and stages:

1. Configure
2. Prepare
3. Deploy

Within those phases, the default stage map is:

1. Host Access
2. Platform
3. Features
4. Backups
5. Advanced
6. Review
7. Vault
8. Prerequisites
9. Collections
10. Preflight
11. Bootstrap
12. Deploy
13. Backup
14. Verification
15. Hardening

The wizard makes each stage explicit, so configure-only, configure-plus-prepare, and full deployment are all first-class paths.

## 2. Lower-level phase runners

When you need direct control instead of the wizard-owned workflow stages:

- `./scripts/deploy.sh`
- `./scripts/ssh-lockdown.sh`

The generated config still lives in:

- `inventories/prod/hosts.yml`
- `inventories/prod/group_vars/all.yml`
- `inventories/prod/group_vars/core_hosts.yml`
- `inventories/prod/group_vars/vault.yml`

Important:

- set `bootstrap_ansible_user` to the existing first-login account on the host, usually `root`
- keep `ansible_user` as the steady-state operator account Ansible should use after bootstrap, usually `deploy`
- set `bootstrap_target_ubuntu_release` to `jammy` for Ubuntu 22.04 or `noble` for Ubuntu 24.04

## 3. Install collections

`./scripts/install-collections.sh`

This installs:

- `crownops.deploy_base`
- `crownops.deploy_services`

## 4. Run preflight

`ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml`

## 5. Bootstrap the fresh host

`ansible-playbook -i inventories/prod/hosts.yml playbooks/bootstrap.yml`

## 6. Deploy enabled features

`ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml`

## 7. Configure backup jobs

`ansible-playbook -i inventories/prod/hosts.yml playbooks/backup.yml`

## 8. Validate manually

- SSH access works
- Docker works
- Tailscale joins cleanly if enabled
- Traefik container is healthy when ingress-backed features are enabled
- HTTPS certificate issued successfully
- CouchDB reachable through Traefik when Obsidian is enabled
- Android Obsidian LiveSync works for your vault
- every required backup job runs successfully to its configured target set
- at least one restore path has been tested for the highest-value data job

## 9. Run staged SSH lockdown after Tailscale access is confirmed

Validation-only phase:
`./scripts/ssh-lockdown.sh --phase1-only`

Restrictive phase:
`./scripts/ssh-lockdown.sh --confirm`

This phase:

- requires both `lockdown_enabled=true` and `lockdown_confirmed=true`
- short-circuits when `lockdown_break_glass_file` exists
- verifies `tailscale0`, `tailscale status --json`, and a Tailscale IPv4 address before broad SSH removal
- allows SSH on `tailscale0` or configured CIDRs first, then removes public SSH when `lockdown_disable_public_ssh` is enabled

## 10. Handoff synced vaults

Each user should complete or rotate their final LiveSync encryption passphrase.
