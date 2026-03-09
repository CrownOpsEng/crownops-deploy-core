# Architecture

## Deployment role

This repo is the environment-specific deployment layer for remote hosts.

## Dependency layers

- fresh-host bootstrap delegated to `crownops.deploy_base`
- staged network lockdown delegated to `crownops.deploy_base`
- reusable service and backup stacks delegated to `crownops.deploy_services`
- site-local layout and readiness validation kept in this repo

Dependency direction:
- inventory and examples in `crownops-deploy-core`
- site playbooks in `crownops-deploy-core`
- reusable service stacks in `crownops.deploy_services`
- reusable host foundation in `crownops.deploy_base`

## Feature structure

`playbooks/site.yml` imports feature playbooks from `playbooks/features/`.

Current feature set:
- Obsidian via the `crownops.deploy_services.obsidian_livesync` role

`playbooks/backup.yml` uses the `crownops.deploy_services.restic_host_backups` role.

`playbooks/lockdown.yml` consumes the reusable `crownops.deploy_base.network_lockdown` role so SSH lockdown policy stays consistent across site repos.

This keeps the site repo thin while still allowing features to evolve independently.

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
