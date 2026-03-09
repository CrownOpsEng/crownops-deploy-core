# Secrets Model

## Recommended baseline
Use Ansible Vault as the deployment source of truth.

For this public repo:
- track only `inventories/prod/group_vars/vault.yml.example`
- keep the real `inventories/prod/group_vars/vault.yml` ignored
- encrypt the real `vault.yml` locally before deployment
- keep `inventories/prod/group_vars/all.yml` for non-secret structure that references vault-backed values

## Bitwarden role for now
Use your existing Bitwarden cloud vault as operator reference storage and optional input helper, not as the sole machine secret backend.

## Secret classes
### 1. Deployment secrets
- Tailscale auth key
- ACME DNS challenge credentials
- CouchDB admin password
- per-vault CouchDB passwords
- restic passwords
- backup target SSH private keys
- backup target `known_hosts` pins

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
