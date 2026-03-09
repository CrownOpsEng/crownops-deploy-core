# Quick Start

This is the shortest supported path from a brand new Ubuntu install to a full deployment.

## Repos

Use the split as:

```text
VPS/
  crownops-deploy-base/
  crownops-deploy-services/
  crownops-deploy-core/
  crownops-deploy-edge/
```

- `crownops-deploy-base` is the reusable collection repo
- `crownops-deploy-services` is the reusable services collection repo
- `crownops-deploy-core` is the site deployment repo with inventory, wrappers, and operator docs
- `crownops-deploy-edge` is a separate deployment repo for edge services, not part of the core inventory path

## One-command path

The preferred operator entrypoint is:

```bash
./scripts/init-local-config.sh
./scripts/deploy.sh
```

It will:
- install required collections from GitHub
- run preflight
- bootstrap a brand new host when needed
- deploy enabled features
- configure backup jobs
- optionally run SSH lockdown when you pass `--lockdown`

By default it prompts before each phase. Use `--yes` for unattended execution.

## Minimum target requirements

- fresh Ubuntu 22.04 or 24.04 host
- SSH reachable from the control machine
- a valid first-login account in inventory, usually `root`

## Minimum repo setup

Tracked templates:
- `inventories/prod/hosts.yml.example`
- `inventories/prod/group_vars/all.yml.example`
- `inventories/prod/group_vars/core_hosts.yml.example`
- `inventories/prod/group_vars/vault.yml.example`

Local working files created by `./scripts/init-local-config.sh`:
- `inventories/prod/hosts.yml`
- `inventories/prod/group_vars/all.yml`
- `inventories/prod/group_vars/core_hosts.yml`
- `inventories/prod/group_vars/vault.yml`

At minimum set:
- `ansible_host`
- `bootstrap_ansible_user`
- `ansible_user`
- `bootstrap_target_ubuntu_release`
- `ssh_pubkeys`
- DNS and ACME values if HTTPS-backed features are enabled
- CouchDB credentials if Obsidian is enabled
- backup target credentials
- Tailscale values if Tailscale is enabled

Notes:
- Tailscale join is automated during bootstrap when `tailscale_auth_key` is set
- if you intentionally leave `tailscale_auth_key` blank, join manually and then run `./scripts/lockdown.sh` after confirming SSH over Tailscale works
- backup transport supports SSH keys by setting the `restic_*_ssh_private_key` and `restic_*_ssh_known_hosts` variables

## Secrets

Put secret values in `inventories/prod/group_vars/vault.yml`, then encrypt that file with Ansible Vault before the first real deployment.

## Manual phase commands

If you need explicit control instead of the wrapper:

```bash
./scripts/init-local-config.sh
./scripts/install-collections.sh
ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/bootstrap.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/backup.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/lockdown.yml
```

## Feature model

`playbooks/site.yml` imports feature playbooks from `playbooks/features/`.

Current feature set:
- Obsidian via Traefik + CouchDB LiveSync

This keeps application features removable without changing the baseline deployment path.
