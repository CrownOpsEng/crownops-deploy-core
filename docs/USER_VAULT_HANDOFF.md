# User Vault Handoff

Goal: preserve user autonomy so operators cannot access synced vault content without the user's final encryption passphrase.

## Recommended handoff flow
1. Provision the server, database, and per-vault CouchDB credentials.
2. User installs Obsidian + LiveSync.
3. User connects to the provided backend.
4. User sets or rotates the final LiveSync encryption passphrase.
5. Operators do not retain that final passphrase.

## What operators may still know
- that the database exists
- approximate sync timing
- database size and service metadata

## What operators should not know if privacy is real
- final vault content encryption passphrase
- readable vault content
