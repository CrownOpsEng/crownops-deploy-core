# Architecture

## Deployment role

This repo is the environment-specific deployment layer for remote hosts.

## Stack baseline

- fresh-host bootstrap delegated to `crownops.deploy_base`
- Docker Engine + Compose plugin
- Traefik reverse proxy
- HTTPS required for Obsidian LiveSync Android compatibility
- Tailscale support
- CouchDB backend for human vaults
- plain markdown on-disk agent vaults
- restic encrypted backups to primary and secondary targets

## Feature structure

`playbooks/site.yml` imports feature playbooks from `playbooks/features/`.

Current feature set:
- Obsidian via Traefik + CouchDB LiveSync

This keeps feature deployments removable without changing the baseline bootstrap path.

## Human vaults

- your vault
- kid1 vault
- kid2 vault

Each gets its own:
- CouchDB database
- CouchDB user
- LiveSync encryption passphrase

## Agent vaults

- Aegis
- Helios
- Relay
- Quartermaster

Each is a plain markdown directory on disk under `/srv/crownops/vaults/agents`.
