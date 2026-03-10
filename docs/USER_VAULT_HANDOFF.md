# User Vault Handoff

Goal: preserve user autonomy so operators cannot access synced vault content without the user's final encryption passphrase.

## Recommended handoff flow

1. Provision the server, database, and per-vault CouchDB credentials.
2. Generate a per-vault setup URI plus a separate setup-URI passphrase.
3. User installs Obsidian + LiveSync.
4. User imports the setup URI and unlocks it with the setup-URI passphrase.
5. User records and then rotates the bootstrap LiveSync vault passphrase if operator privacy is required.
6. Operators do not retain that final passphrase.

## What operators may still know

- that the database exists
- approximate sync timing
- database size and service metadata

## What operators should not know if privacy is real

- final vault content encryption passphrase
- readable vault content

## Practical note

The setup URI is a bootstrap artifact, not the privacy end-state. If operators generate or retain the bootstrap vault passphrase, users should rotate it after the first successful sync and remove any retained copies from operator-controlled records.
