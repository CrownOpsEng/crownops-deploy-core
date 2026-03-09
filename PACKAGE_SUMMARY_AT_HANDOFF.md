# Package Summary at Handoff

## What this package is
A structured Ansible deployment scaffold for the OVHcloud private core host that will later expand to additional internal services.

## Architectural baseline locked into this package
- OVH = private core
- Docker + Compose plugin
- Traefik from day one
- HTTPS required for Obsidian LiveSync mobile compatibility
- Tailscale-only access for now
- CouchDB backend for human Obsidian vaults
- Separate CouchDB database/user per human vault
- Plain markdown vault directories for agents
- restic encrypted backups to H4F and laptop

## Human vault plan
- you
- kid1
- kid2

Each vault gets:
- dedicated CouchDB database
- dedicated CouchDB user
- dedicated LiveSync encryption passphrase
- dedicated backup coverage

## Agent vault plan
One vault per agent:
- Aegis
- Helios
- Relay
- Quartermaster

## What remains before production use
- fill all environment-specific variables and secrets
- select and wire real DNS provider / ACME DNS challenge settings
- join OVH to Tailscale
- validate Traefik HTTPS path
- validate CouchDB behind Traefik
- validate Android Obsidian LiveSync end-to-end
- validate backups and restore
- hand off kid vault setup with user-owned final encryption passphrases


## Preflight validation added

The package now includes `playbooks/preflight.yml` and the `preflight_validate` role.
It aggregates configuration issues across inventory, placeholders, vault definitions, backup targets, Tailscale settings, and remote connectivity, writes a local report, and fails only after the full preflight completes.
