# Restore Notes

## Synced user vault restore
1. Rebuild host base.
2. Restore Traefik and CouchDB service configuration.
3. Restore CouchDB data from restic.
4. Recreate or verify routing and HTTPS.
5. Confirm database security objects and per-vault users.
6. Reconnect device with correct CouchDB credentials.
7. User supplies correct final LiveSync encryption passphrase.

## Local markdown workspace restore
1. Rebuild host base.
2. Restore `/srv/crownops/vaults/workspaces/*`.
3. Restore permissions and service ownership.
4. Reattach consuming services later.

## Important truth
Sync is not backup. LiveSync restores sync state, not disaster-recovery guarantees.
