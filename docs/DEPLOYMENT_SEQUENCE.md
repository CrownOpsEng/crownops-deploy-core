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

## 3. Run preflight

`ansible-playbook playbooks/preflight.yml`

## 4. Bootstrap the fresh host

`ansible-playbook playbooks/bootstrap.yml`

## 5. Deploy enabled features

`ansible-playbook playbooks/site.yml`

## 6. Configure backup jobs

`ansible-playbook playbooks/backup.yml`

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

## 8. Handoff kid vaults

Each kid should complete or rotate their final LiveSync encryption passphrase.
