# Secrets Model

## Recommended baseline
Use Ansible Vault as the deployment source of truth.

## Bitwarden role for now
Use your existing Bitwarden cloud vault as operator reference storage and optional input helper, not as the sole machine secret backend.

## Secret classes
### 1. Deployment secrets
- Tailscale auth key
- ACME DNS challenge credentials
- CouchDB admin password
- per-vault CouchDB passwords
- restic passwords
- backup target SSH access

### 2. Human vault content keys
- your LiveSync passphrase
- kid1 final LiveSync passphrase
- kid2 final LiveSync passphrase

Do not casually retain the kids' final passphrases if privacy is the goal.

### 3. Operator reference secrets
Can live in Bitwarden:
- DNS registrar access
- server bootstrap creds
- supporting operator notes
