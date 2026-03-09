# Package Summary at Handoff

## What this package is

A structured Ansible deployment scaffold for a CrownOps remote environment that can expand with additional internal services over time.

## Architectural baseline locked into this package

- generic fresh-host bootstrap consumed from `crownops.deploy_base`
- reusable service stacks and backup automation consumed from `crownops.deploy_services`
- feature-oriented application deployment via `playbooks/features/`
- HTTPS required for Obsidian LiveSync mobile compatibility
- Tailscale install/join during bootstrap with optional manual-join path
- staged post-join SSH lockdown with explicit enable and confirm gates
- CouchDB backend for human Obsidian vaults
- separate CouchDB database and user per human vault
- plain markdown vault directories for agents
- encrypted restic backups to primary and secondary targets

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
- select and wire real DNS provider and ACME DNS challenge settings
- join the target host to Tailscale if you are not using an auth key
- validate Traefik HTTPS path
- validate CouchDB behind Traefik
- validate Android Obsidian LiveSync end-to-end
- validate backups and restore
- run staged lockdown after confirming SSH via Tailscale or another restrictive path
- hand off kid vault setup with user-owned final encryption passphrases
