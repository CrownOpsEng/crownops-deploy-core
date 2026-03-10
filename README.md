# CrownOps Deploy Core

Modular Ansible deployment repo for CrownOps remote environments.

This repo is the environment-facing deployment layer:

- consume the shared `crownops.deploy_base` collection for fresh-host bootstrap
- consume the shared `crownops.deploy_base` collection for staged post-join SSH lockdown
- consume the shared `crownops.deploy_services` collection for reusable service stacks and composable host backup automation
- keep inventory, deployment flow, and feature wiring separate from the reusable collections
- let features such as Obsidian be enabled, disabled, or replaced without rewriting the base deployment path

This repo should stay thin:

- local inventory and examples
- wrapper scripts and operator docs
- site playbooks
- only truly site-local roles such as layout and preflight

Configuration model:

- `inventories/prod/group_vars/all.yml` is the primary non-secret configuration surface
- `inventories/prod/group_vars/vault.yml` holds secret values only
- backup policy is expressed as `restic_targets`, `restic_backup_jobs`, and `restic_backup_contributions`

Read first:

- `docs/QUICKSTART.md`
- `docs/CONFIG_WIZARD_SPEC.md`
- `docs/IMPLEMENTATION_STATUS.md`
- `docs/DEPLOYMENT_SEQUENCE.md`
- `docs/SECRETS_MODEL.md`
- `docs/RESTORE.md`
- `PACKAGE_SUMMARY_AT_HANDOFF.md`

## Preflight

Run preflight before any bootstrap or deploy action:

```bash
./scripts/configure.sh
./scripts/install-collections.sh
ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml
```

Behavior:

- aggregates all validation findings first
- writes a local report under `reports/`
- fails only after the full validation pass completes

Public repo hygiene:

- tracked files end in `.example`
- real local inventory and vars stay untracked
- `scripts/configure.sh` is the preferred local config entrypoint
- on a first run, `scripts/configure.sh` can generate or reuse a managed Ed25519 Ansible key under `~/.ssh/ansible-config-wizard/`, write `ansible_ssh_private_key_file` into local inventory, and either install that key automatically with a one-shot password prompt or pause with exact commands and resume guidance
- for Linux SFTP backup destinations you control, the wizard can offer either the full deployment run or a generated prerequisite setup step that prepares backup users, SSH keys, and repository paths before deployment
- when you already have a backup transport key, point the wizard at the local private key file instead of pasting the key into the terminal
- the Obsidian feature supports two access modes: `public_https` for Traefik + ACME on `443`, and `private_mesh` for VPN or mesh-only reachability without public ingress; preflight rejects a public `5984` firewall rule in `private_mesh`
- the shared wizard implementation lives outside this repo; this repo only carries the profile, templates, and builder hook
- `scripts/init-local-config.sh` remains available as a simple scaffold-from-examples fallback

Quality controls:

- GitHub Actions CI scaffolds example local config, installs collections from GitHub, and syntax-checks the site playbooks
- staged lockdown uses explicit enable and confirm gates plus break-glass support, so a casual deploy run does not remove public SSH

Use this before:

- `playbooks/bootstrap.yml`
- `playbooks/site.yml`
- `playbooks/backup.yml`
- `playbooks/lockdown.yml`
