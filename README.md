# CrownOps OVH Core Ansible Package

Private-repo-ready Ansible scaffold for the OVHcloud private core host.

Primary objective in this package:
- stand up the OVH private core foundation
- prepare Traefik + HTTPS + CouchDB for Obsidian LiveSync human vaults
- prepare plain on-disk agent vaults
- prepare encrypted restic backup jobs to H4F and laptop

Read first:
- `docs/QUICKSTART_FRESH_HOST.md`
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
- `playbooks/bootstrap-ovh.yml`
- `playbooks/site.yml`
- `playbooks/backup-setup.yml`
