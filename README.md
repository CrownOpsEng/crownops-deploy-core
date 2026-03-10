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

- `inventories/prod/group_vars/all/main.yml` is the primary non-secret configuration surface
- `inventories/prod/group_vars/all/vault.yml` holds secret values only
- `.vault_pass` is the repo-local default Ansible Vault password file; keep it local, `0600`, and untracked
- shared host capabilities live under `host.*`
- feature contracts live under `features.*`
- site-local composition derives shared ingress, backup datasets, and firewall requests before host roles reconcile them
- host-owned `host.traefik.routes`, `host.restic.datasets`, and `host.ufw.requests` remain additive extension points and are preserved when the site layer composes shared inputs

Read first:

- `docs/QUICKSTART.md`
- `docs/CONFIG_WIZARD_SPEC.md`
- `docs/IMPLEMENTATION_STATUS.md`
- `docs/DEPLOYMENT_SEQUENCE.md`
- `docs/SECRETS_MODEL.md`
- `docs/RESTORE.md`
- `PACKAGE_SUMMARY_AT_HANDOFF.md`

## Preflight

Use the guided setup flow first. It owns configuration, vault handling, collection install, preflight, bootstrap, site deploy, backup setup, and optional SSH lockdown in one explicit stage sequence:

```bash
./scripts/setup.sh
```

When you need the lower-level runners directly:

```bash
./scripts/deploy.sh --skip-bootstrap --skip-site --skip-backup
./scripts/ssh-lockdown.sh --phase1-only
```

Behavior:

- aggregates all validation findings first
- writes a local report under `reports/`
- fails only after the full validation pass completes

Public repo hygiene:

- tracked files end in `.example`
- real local inventory and vars stay untracked
- `ansible.cfg` points Ansible at `.vault_pass` by default; the wizard can create that file for you and the lower-level runners will use it automatically when present
- `scripts/setup.sh` is the primary interactive operator entrypoint
- `scripts/deploy.sh` is the lower-level deployment runner for explicit phase execution
- `scripts/ssh-lockdown.sh` is the lower-level staged SSH hardening runner
- on a first run, `scripts/setup.sh` can generate or reuse a managed Ed25519 Ansible key under `~/.ssh/ansible-config-wizard/`, write `ansible_ssh_private_key_file` into local inventory, and either install that key automatically with a one-shot password prompt or pause with exact commands and resume guidance
- for Linux SFTP backup destinations you control, the wizard can prepare the backup prerequisite script and still keep the main setup flow inside `scripts/setup.sh`
- when you already have a backup transport key, point the wizard at the local private key file instead of pasting the key into the terminal
- the Obsidian feature supports two access modes: `public_https` for Traefik + ACME on `443`, and `private_mesh` for VPN or mesh-only reachability without public ingress; preflight rejects a public `5984` firewall rule in `private_mesh`
- the shared wizard implementation lives outside this repo; this repo only carries the profile, templates, and builder hook
- `scripts/init-local-config.sh` remains available as a simple scaffold-from-examples fallback

Quality controls:

- GitHub Actions CI scaffolds example local config, installs collections from GitHub, and syntax-checks the site playbooks
- staged lockdown uses explicit validation-only and `--confirm` paths plus break-glass support, so a casual deploy run does not remove public SSH

Use this before:

- `playbooks/bootstrap.yml`
- `playbooks/site.yml`
- `playbooks/backup.yml`
- `playbooks/lockdown.yml`
