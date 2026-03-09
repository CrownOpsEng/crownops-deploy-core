# Deployment Sequence

## 1. Fill variables and secrets

First run:
- `./scripts/init-local-config.sh`

Then update:
- `inventories/prod/hosts.yml`
- `inventories/prod/group_vars/all.yml`
- `inventories/prod/group_vars/core_hosts.yml`
- `inventories/prod/group_vars/vault.yml`

Important:
- set `bootstrap_ansible_user` to the existing first-login account on the host, usually `root`
- keep `ansible_user` as the steady-state operator account Ansible should use after bootstrap, usually `deploy`
- set `bootstrap_target_ubuntu_release` to `jammy` for Ubuntu 22.04 or `noble` for Ubuntu 24.04

## 2. Install collections

`./scripts/install-collections.sh`

This installs:
- `crownops.deploy_base`
- `crownops.deploy_services`

## 3. Run preflight

`ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml`

## 4. Bootstrap the fresh host

`ansible-playbook -i inventories/prod/hosts.yml playbooks/bootstrap.yml`

## 5. Deploy enabled features

`ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml`

## 6. Configure backup jobs

`ansible-playbook -i inventories/prod/hosts.yml playbooks/backup.yml`

## 7. Validate manually

- SSH access works
- Docker works
- Tailscale joins cleanly if enabled
- Traefik container is healthy when ingress-backed features are enabled
- HTTPS certificate issued successfully
- CouchDB reachable through Traefik when Obsidian is enabled
- Android Obsidian LiveSync works for your vault
- restic backup to the primary target works
- restic backup to the secondary target works when reachable

## 8. Run staged SSH lockdown after Tailscale access is confirmed

Validation-only phase:
`./scripts/lockdown.sh --phase1-only`

Restrictive phase:
`./scripts/lockdown.sh --confirm`

This phase:
- requires both `lockdown_enabled=true` and `lockdown_confirmed=true`
- short-circuits when `lockdown_break_glass_file` exists
- verifies `tailscale0`, `tailscale status --json`, and a Tailscale IPv4 address before broad SSH removal
- allows SSH on `tailscale0` or configured CIDRs first, then removes public SSH when `lockdown_disable_public_ssh` is enabled

## 9. Handoff synced vaults

Each user should complete or rotate their final LiveSync encryption passphrase.
