# CrownOps Deploy Core

Modular Ansible deployment repo for CrownOps remote environments.

This repo is the environment-facing deployment layer:
- consume the shared `crownops.deploy_base` collection for fresh-host bootstrap
- consume the shared `crownops.deploy_services` collection for reusable service stacks and host backup automation
- keep inventory, deployment flow, and feature wiring separate from the reusable collections
- let features such as Obsidian be enabled, disabled, or replaced without rewriting the base deployment path

This repo should stay thin:
- local inventory and examples
- wrapper scripts and operator docs
- site playbooks
- only truly site-local roles such as layout and preflight

Read first:
- `docs/QUICKSTART.md`
- `docs/IMPLEMENTATION_STATUS.md`
- `docs/DEPLOYMENT_SEQUENCE.md`
- `docs/SECRETS_MODEL.md`
- `docs/RESTORE.md`
- `PACKAGE_SUMMARY_AT_HANDOFF.md`

## Preflight

Run preflight before any bootstrap or deploy action:

```bash
./scripts/init-local-config.sh
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
- `scripts/init-local-config.sh` creates the local working files from examples

Use this before:
- `playbooks/bootstrap.yml`
- `playbooks/site.yml`
- `playbooks/backup.yml`
