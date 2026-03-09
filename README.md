# CrownOps Deploy Core

Modular Ansible deployment repo for CrownOps remote environments.

This repo is the environment-facing deployment layer:
- consume the shared `crownops.deploy_base` collection for fresh-host bootstrap
- keep inventory, deployment flow, and feature wiring separate from the reusable baseline
- let features such as Obsidian be enabled, disabled, or replaced without rewriting the base deployment path

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
./scripts/install-collections.sh
ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml
```

Behavior:
- aggregates all validation findings first
- writes a local report under `reports/`
- fails only after the full validation pass completes

Use this before:
- `playbooks/bootstrap.yml`
- `playbooks/site.yml`
- `playbooks/backup.yml`
