# Implementation Status

This file states exactly what is done, what is not done, and what gaps remain.

## Done in this package

- Architecture aligned to a provider-agnostic site repo with reusable base and services collections
- Ansible repo scaffold created
- Inventory skeleton created
- Group vars skeleton created
- Playbooks created:
  - `bootstrap.yml`
  - `preflight.yml`
  - `site.yml`
  - `backup.yml`
  - `lockdown.yml`
  - `features/obsidian.yml`
- Roles created:
  - `core_layout`
  - `preflight_validate`
- Wrapper scripts created:
  - `scripts/install-collections.sh`
  - `scripts/deploy.sh`
  - `scripts/init-local-config.sh`

## Not done in this package

- No environment-specific production values are filled
- No live host deployment has been validated end-to-end
- No certificate issuance has been validated
- No Android Obsidian LiveSync validation has been run
- No end-user vault handoff process has been validated in practice
- No Tailscale ACL or tag policy is implemented beyond variable placeholders
- No backup repo init validation has been run
- No restore test has been executed
- No additional feature stacks are included yet
- No Ansible Vault files are included
- The services collection has not yet been validated by a second consuming site repo
- No live staged SSH lockdown has been executed yet

## Gaps that must be filled before deployment

1. Replace all placeholder values in inventory and group vars.
2. Encrypt secrets with Ansible Vault.
3. Choose and wire the ACME DNS provider correctly.
4. Ensure firewall and DNS align with HTTPS issuance path.
5. Verify whether port 443 should be publicly reachable or source-restricted in your exact model.
6. Join the host to Tailscale with the real auth approach you want.
7. Prepare the backup targets and confirm the job/contribution model matches the host role.
8. Decide how you will handle LiveSync passphrase ownership and recovery expectations.
9. Run and validate the package in a controlled sequence, including the staged SSH lockdown.

## Resume point without analysis

If you come back cold, do this in order:

1. Read `docs/DEPLOYMENT_SEQUENCE.md`.
2. Fill inventory and vars.
3. Put secrets into Ansible Vault.
4. Run `playbooks/preflight.yml`.
5. Run `playbooks/bootstrap.yml`.
6. Run `playbooks/site.yml`.
7. Run `playbooks/backup.yml`.
8. Validate Tailscale access and then run `./scripts/lockdown.sh --confirm`.
9. Manually validate HTTPS, CouchDB, LiveSync, and at least one real restore path.
