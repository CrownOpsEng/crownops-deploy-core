# Kid Vault Handoff

Goal: preserve child autonomy so you cannot access vault content without their final encryption passphrase.

## Recommended handoff flow
1. You provision server, DB, and per-vault CouchDB credentials.
2. Child installs Obsidian + LiveSync.
3. Child connects to the provided backend.
4. Child sets or rotates the final LiveSync encryption passphrase.
5. You do not retain that final passphrase.

## What you may still know
- that the database exists
- approximate sync timing
- database size / service metadata

## What you should not know if privacy is real
- final vault content encryption passphrase
- readable vault content
