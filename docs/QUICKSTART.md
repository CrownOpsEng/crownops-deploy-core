# Quick Start

This is the shortest supported path from a brand new Ubuntu install to a full deployment.

## Repos

Use the split as:

```text
VPS/
  crownops-deploy-base/
  crownops-deploy-core/
  crownops-deploy-edge/
```

- `crownops-deploy-base` is the reusable collection repo
- `crownops-deploy-core` is the deployment repo with playbooks, features, and operator docs
- `crownops-deploy-edge` is where environment-specific inventory and secret overlays can live if you want them isolated from the shared deploy repos

## One-command path

The preferred operator entrypoint is:

```bash
./scripts/deploy.sh
```

It will:
- install required collections from GitHub
- run preflight
- bootstrap a brand new host when needed
- deploy enabled features
- configure backup jobs

By default it prompts before each phase. Use `--yes` for unattended execution.

## Minimum target requirements

- fresh Ubuntu 22.04 or 24.04 host
- SSH reachable from the control machine
- a valid first-login account in inventory, usually `root`

## Minimum repo setup

Fill these before the first real run:
- `inventories/prod/hosts.yml`
- `inventories/prod/group_vars/all.yml`
- `inventories/prod/group_vars/core_hosts.yml`

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

## Secrets

Put secret values in Ansible Vault before the first real deployment.

## Manual phase commands

If you need explicit control instead of the wrapper:

```bash
./scripts/install-collections.sh
ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/bootstrap.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/backup.yml
```

## Feature model

`playbooks/site.yml` imports feature playbooks from `playbooks/features/`.

Current feature set:
- Obsidian via Traefik + CouchDB LiveSync

This keeps application features removable without changing the baseline deployment path.
