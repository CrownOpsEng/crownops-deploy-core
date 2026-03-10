# Restore Notes

## Synced user vault restore

1. Rebuild host base.
2. Reapply service configuration from Ansible so `docker-compose.yml`, `local.ini`, and routing config are recreated from source of truth.
3. Restore the `obsidian-couchdb-data` dataset after stopping CouchDB.
4. If public HTTPS is enabled, restore the `traefik-acme` dataset so Traefik keeps its ACME account and issued certificates.
5. Recreate or verify routing and HTTPS.
6. Confirm database security objects and per-vault users.
7. Reconnect device with correct CouchDB credentials.
8. User supplies correct final LiveSync encryption passphrase.

## Local markdown workspace restore

1. Rebuild host base.
2. Restore `{{ vault_root }}/workspaces`.
3. Restore permissions and service ownership.
4. Reattach consuming services later.

## Important truth

Sync is not backup. LiveSync restores sync state, not disaster-recovery guarantees.

## Backup scope

Back up durable state only:

- host identity and operator-managed security config under `/etc/ssh`, `/etc/fail2ban`, and `/etc/ufw`
- local markdown workspaces under `{{ vault_root }}/workspaces`
- CouchDB data under `features.obsidian_livesync.couchdb.dir + '/data'`
- Traefik ACME state under `host.traefik.acme_storage_path` when public HTTPS is enabled

Do not treat generated compose files, rendered service config, package caches, or broad parent directories such as `/srv/crownops`, `features.obsidian_livesync.couchdb.dir`, or `host.traefik.layout_root` as primary backup scope when the deployment is reproducible from Ansible.
