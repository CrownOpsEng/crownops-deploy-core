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
./scripts/configure.sh
./scripts/deploy.sh
```

For local development in this workspace, keep the shared wizard repo as a sibling checkout:

```text
VPS/
  ansible-config-wizard/
  crownops-deploy-core/
```

`./scripts/configure.sh` will use the sibling repo automatically when present. In other environments it can also run an installed wizard binary or a path supplied through `ANSIBLE_CONFIG_WIZARD_PROJECT`.

It will:

- collect or generate configuration interactively
- generate a bootstrap Ed25519 SSH key on first run when you do not already have authorized keys ready
- pause with exact `ssh-copy-id` and `ssh -i` guidance so you can install and test access before continuing
- write a 0600 resume-state file so the wizard can continue from the same point later
- write inventory, non-secret settings, and local secret material
- optionally write a sensitive details file
- optionally write a sanitized audit log
- optionally encrypt `inventories/prod/group_vars/vault.yml`
- install required collections from GitHub
- run preflight
- bootstrap a brand new host when needed
- deploy enabled features
- configure backup jobs
- optionally run the staged SSH lockdown phase when you pass `--enable-lockdown`

By default it prompts before each phase. Use `--yes` for unattended execution.

## Minimum target requirements

- fresh Ubuntu 22.04 or 24.04 host
- SSH reachable from the control machine
- a valid first-login account in inventory, usually `root`

## Minimum repo setup

Primary configuration surface:

- `inventories/prod/group_vars/all.yml`

That file should remain the main place where you enable features and define non-secret behavior:

- domains and ingress settings
- host bootstrap settings
- synced Obsidian account definitions
- local markdown workspace names
- backup targets, logical jobs, feature contributions, and lockdown behavior

Secrets belong in:

- `inventories/prod/group_vars/vault.yml`

Tracked templates:

- `inventories/prod/hosts.yml.example`
- `inventories/prod/group_vars/all.yml.example`
- `inventories/prod/group_vars/core_hosts.yml.example`
- `inventories/prod/group_vars/vault.yml.example`

Local working files created by `./scripts/configure.sh`:

- `inventories/prod/hosts.yml`
- `inventories/prod/group_vars/all.yml`
- `inventories/prod/group_vars/core_hosts.yml`
- `inventories/prod/group_vars/vault.yml`

Fallback:

- `./scripts/init-local-config.sh` still exists if you only want a raw scaffold from `.example` files

At minimum set:

- `ansible_host`
- `bootstrap_ansible_user`
- `ansible_user`
- `bootstrap_target_ubuntu_release`
- either `ssh_pubkeys` or let the wizard generate a bootstrap SSH key and derive the first authorized key automatically
- DNS and ACME values if HTTPS-backed features are enabled
- synced account structure in `all.yml` and CouchDB passwords in `vault.yml` if Obsidian is enabled
- local markdown workspace names in `all.yml` if you want local-only content directories scaffolded
- backup targets, backup jobs, and contribution wiring
- Tailscale hostname/tags in `all.yml` and optional auth key in `vault.yml`

Notes:

- when the wizard generates a bootstrap SSH key, it writes the key pair under the local wizard state directory, by default `~/.local/state/ansible-config-wizard/<profile>/<repo>/bootstrap-ssh/`, and pauses before the rest of the questions so you can install the public key on the host and verify access
- resume a paused run with `./scripts/configure.sh --answers-file <saved-state.yml>`
- Tailscale join is automated during bootstrap when `tailscale_auth_key` is set
- if you intentionally leave `tailscale_auth_key` blank, join manually and then run `./scripts/lockdown.sh --confirm` after confirming SSH over Tailscale works
- SFTP backup transport supports SSH keys on a per-target basis by setting `ssh_private_key` and `ssh_known_hosts` under each `restic_targets` entry
- staged SSH lockdown is two-phase: `--enable-lockdown` runs the phase, `--confirm-lockdown` is required before public SSH can actually be removed
- break-glass file `lockdown_break_glass_file` short-circuits restrictive changes if recovery is needed

## Secrets

Put secret values in `inventories/prod/group_vars/vault.yml`, then encrypt that file with Ansible Vault before the first real deployment.

Recommended split:

- `all.yml`: domains, feature flags, ports, paths, usernames, and other non-secret structure
- `vault.yml`: passwords, SSH private keys, pinned `known_hosts`, and optional `tailscale_auth_key`

## Manual phase commands

If you need explicit control instead of the wrapper:

```bash
./scripts/configure.sh
./scripts/install-collections.sh
ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/bootstrap.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/backup.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/lockdown.yml -e lockdown_enabled=true -e lockdown_confirmed=true
```

## Feature model

`playbooks/site.yml` imports feature playbooks from `playbooks/features/`.

Current feature set:

- Obsidian via Traefik + CouchDB LiveSync

This keeps application features removable without changing the baseline deployment path.
