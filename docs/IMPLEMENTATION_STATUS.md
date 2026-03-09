# Implementation Status

This file states exactly what is done, what is not done, and what gaps remain.

## Done in this package
- Architecture locked for OVH private core.
- Ansible repo scaffold created.
- Inventory skeleton created.
- Group vars skeleton created.
- Playbooks created:
  - bootstrap-ovh.yml
  - site.yml
  - backup-setup.yml
- Roles created:
  - ops_users
  - base_common
  - base_hardening
  - docker_engine
  - tailscale_host
  - vault_roots
  - agent_vaults
  - traefik_core
  - couchdb_livesync
  - restic_client
  - systemd_timers
  - bootstrap_outputs
- Implemented task coverage for:
  - ops user creation
  - SSH authorized keys
  - SSH hardening drop-in
  - UFW baseline enablement
  - fail2ban baseline enablement
  - Docker apt repo and package install
  - Tailscale install/join placeholder
  - main vault and export directory creation
  - agent vault directory creation and seed README files
  - Traefik config template
  - Traefik compose template and deployment
  - CouchDB config template
  - CouchDB compose template and deployment
  - CouchDB bootstrap helper template
  - restic env files and scripts
  - systemd timers for backup and maintenance
  - handoff markdown output template
- Documentation created:
  - architecture
  - deployment sequence
  - secrets model
  - restore notes
  - package summary

## Not done in this package
- No environment-specific production values are filled.
- No real host IPs or final hostnames are wired.
- No real ops domain is chosen.
- No real DNS provider credentials are wired.
- No certificate issuance has been validated.
- No Traefik deployment has been tested on OVH.
- No CouchDB deployment has been tested on OVH.
- No CouchDB bootstrap execution is automated in a proven-safe idempotent way.
- No Android Obsidian LiveSync validation has been run.
- No kid vault handoff process has been validated in practice.
- No Tailscale ACL/tag policy is implemented beyond variable placeholders.
- No H4F restic target provisioning is included.
- No laptop restic target provisioning is included.
- No backup repo init validation has been run.
- No restore test has been executed.
- No Vaultwarden deployment is included.
- No SimpleLogin deployment is included.
- No agent application containers/services are included.
- No monitoring stack is included.
- No CI pipeline is included.
- No Ansible Vault files are included.

## Gaps that must be filled before deployment
1. Replace all placeholder values in inventory and group vars.
2. Encrypt secrets with Ansible Vault.
3. Decide final `ops_domain`.
4. Choose and wire the ACME DNS provider correctly.
5. Ensure firewall and DNS align with HTTPS issuance path.
6. Verify whether port 443 should be publicly reachable or source-restricted in your exact model.
7. Join OVH to Tailscale with the real auth approach you want.
8. Prepare H4F SSH backup target.
9. Prepare laptop SSH backup target and reachability expectations.
10. Decide how you will store your own LiveSync passphrase.
11. Decide whether the kids set their final LiveSync passphrases during first-run or rotate them immediately after provisioning.
12. Run and validate the package in a controlled sequence.

## Gaps that must be filled after first successful deployment
1. Add restore test evidence.
2. Add verification notes for Android LiveSync.
3. Add Vaultwarden role later.
4. Add agent service roles later.
5. Add monitoring/alerting later.

## Resume point without analysis
If you come back cold, do this in order:
1. Read `docs/DEPLOYMENT_SEQUENCE.md`.
2. Fill inventory and vars.
3. Put secrets into Ansible Vault.
4. Run `bootstrap-ovh.yml`.
5. Run `site.yml`.
6. Run `backup-setup.yml`.
7. Manually validate HTTPS, CouchDB, LiveSync, and backups.
8. Record what failed and patch the relevant role.


## Preflight validation added

The package now includes `playbooks/preflight.yml` and the `preflight_validate` role.
It aggregates configuration issues across inventory, placeholders, vault definitions, backup targets, Tailscale settings, and remote connectivity, writes a local report, and fails only after the full preflight completes.
