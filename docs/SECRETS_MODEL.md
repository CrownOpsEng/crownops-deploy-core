# Secrets Model

## Recommended baseline

Use Ansible Vault as the deployment source of truth.

For this public repo:

- track only `inventories/prod/group_vars/vault.yml.example`
- keep the real `inventories/prod/group_vars/vault.yml` ignored
- encrypt the real `vault.yml` locally before deployment
- keep `inventories/prod/group_vars/all.yml` for non-secret structure that references vault-backed values

Planned configuration workflow:

- `./scripts/configure.sh` will generate or collect secrets, write the same inventory contract already used by this repo, and optionally encrypt `vault.yml` locally
- `./scripts/configure.sh` is only a repo-local wrapper; the shared wizard engine should live in its own repo or installed package
- the wizard design must remain provider-agnostic so future Bitwarden, 1Password, or other external vault drivers can be added without changing the core configuration model
- implementation contract: `docs/CONFIG_WIZARD_SPEC.md`

## Secret classes

### 1. Deployment secrets

- Tailscale auth key
- ACME DNS challenge credentials
- CouchDB admin password
- per-vault CouchDB passwords
- restic passwords
- backup target SSH private keys
- backup target `known_hosts` pins

### 2. User vault content keys

- final LiveSync passphrase for each synced user vault

Do not casually retain user-managed final passphrases if privacy is the goal.

### 3. Operator reference secrets

Can live in Bitwarden or other password manager:

- DNS registrar access
- server bootstrap creds
- supporting operator notes
