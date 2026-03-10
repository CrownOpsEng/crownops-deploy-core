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

## Wizard-first path

The primary operator entrypoint is:

```bash
./scripts/setup.sh
```

For local development in this workspace, keep the shared wizard repo as a sibling checkout:

```text
VPS/
  ansible-config-wizard/
  crownops-deploy-core/
```

`./scripts/setup.sh` will use the sibling repo automatically when present. In other environments it can also run an installed wizard binary or a path supplied through `ANSIBLE_CONFIG_WIZARD_PROJECT`.

When this repo is developed in a multi-checkout workspace, `./scripts/install-collections.sh` also prefers sibling `crownops-deploy-base/` and `crownops-deploy-services/` checkouts before falling back to the remote default branches. Set `CROWNOPS_BASE_COLLECTION_SOURCE` or `CROWNOPS_SERVICES_COLLECTION_SOURCE` to override that resolution explicitly.

It will:

- collect or generate configuration interactively
- generate or reuse a managed Ed25519 Ansible SSH key under `~/.ssh/ansible-config-wizard/` when you do not already have authorized keys ready
- write `ansible_ssh_private_key_file` into local inventory when it manages that key for you
- optionally install that managed key immediately by prompting once for the current bootstrap account password
- if you prefer, pause with exact `ssh-copy-id` and `ssh -i` guidance so you can install and test access before continuing
- write a 0600 resume-state file only when you actually pause and exit
- write inventory, non-secret settings, and local secret material
- optionally write a sensitive details file
- optionally write a sanitized audit log
- guide vault password strategy before any preparation or deployment stage runs
- optionally encrypt or re-encrypt `inventories/prod/group_vars/vault.yml`
- install required collections from GitHub
- optionally run prerequisite, collection, preflight, bootstrap, deploy, backup, verification, and SSH hardening stages as explicit wizard stages

Use `./scripts/deploy.sh` only when you want the lower-level deployment runner directly, and `./scripts/ssh-lockdown.sh` only when you want the lower-level hardening runner directly.

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

Local working files created by `./scripts/setup.sh`:

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
- either `ssh_pubkeys` or let the wizard generate or reuse a managed Ansible SSH key and derive the first authorized key automatically
- choose `public_https` or `private_mesh` for Obsidian when that feature is enabled
- DNS and ACME values only for `public_https`
- a concrete private mesh base URL only for `private_mesh`
- keep `5984` off the public firewall in `private_mesh`; that path assumes your VPN or mesh provides reachability
- synced account structure in `all.yml` and CouchDB passwords in `vault.yml` if Obsidian is enabled
- local markdown workspace names in `all.yml` if you want local-only content directories scaffolded
- backup targets, backup jobs, and contribution wiring
- Tailscale hostname/tags in `all.yml` and optional auth key in `vault.yml`

Notes:

- when the wizard manages an SSH key for you, it stores that long-term key under `~/.ssh/ansible-config-wizard/<repo>/`, points local inventory at it with `ansible_ssh_private_key_file`, and pauses before the rest of the questions so you can install the public key on the host and verify access
- the automatic managed-key install path disables agent-based key offers so it avoids the common `Too many authentication failures` failure mode caused by clients offering every key from `ssh-agent`
- resume a paused run with `./scripts/setup.sh --answers-file <saved-state.yml>`
- after a successful resumed run, the wizard best-effort securely deletes its own temporary resume-state file
- Tailscale join is automated during bootstrap when `tailscale_auth_key` is set
- if you intentionally leave `tailscale_auth_key` blank, join manually and then run `./scripts/ssh-lockdown.sh --confirm` after confirming SSH over Tailscale works
- SFTP backup transport supports SSH keys on a per-target basis by storing `ssh_private_key` and `ssh_known_hosts` under each `restic_targets` entry, but the wizard now asks for a local `ssh_private_key_file` path so the key itself does not have to be pasted into the terminal or resume state
- the wizard can guide SFTP backup targets by asking for host, user, path, and port, then deriving the restic repository URL and attempting `ssh-keyscan` automatically
- for Linux backup destinations you control, the wizard can still generate a prerequisite setup script that prepares backup users, SSH keys, and repository paths first
- staged SSH lockdown is two-phase: `./scripts/ssh-lockdown.sh --phase1-only` validates while preserving public SSH, and `./scripts/ssh-lockdown.sh --confirm` enables the restrictive path
- break-glass file `lockdown_break_glass_file` short-circuits restrictive changes if recovery is needed

## Secrets

Put secret values in `inventories/prod/group_vars/vault.yml`, then encrypt that file with Ansible Vault before the first real deployment.

Recommended split:

- `all.yml`: domains, feature flags, ports, paths, usernames, and other non-secret structure
- `vault.yml`: passwords, SSH private keys, pinned `known_hosts`, and optional `tailscale_auth_key`

## Manual phase commands

If you need explicit control instead of the wizard-owned workflow stages:

```bash
./scripts/deploy.sh
./scripts/install-collections.sh
ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/bootstrap.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/backup.yml
./scripts/ssh-lockdown.sh --confirm
```

## Feature model

`playbooks/site.yml` imports feature playbooks from `playbooks/features/`.

Current feature set:

- Obsidian via CouchDB LiveSync, with either `public_https` (Traefik + ACME) or `private_mesh` access

This keeps application features removable without changing the baseline deployment path.
