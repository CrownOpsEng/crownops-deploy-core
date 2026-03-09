# Architecture

## OVH role
Private core host for stateful and sensitive services.

## Stack baseline
- Docker Engine + Compose plugin
- Traefik reverse proxy
- HTTPS required for Obsidian LiveSync Android compatibility
- Tailscale-only access for now
- CouchDB backend for human vaults
- Plain markdown on-disk agent vaults
- restic encrypted backups to H4F and laptop

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
