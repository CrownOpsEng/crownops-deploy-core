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

Shared host capabilities:

- `crownops.deploy_services.host_traefik`
- `crownops.deploy_services.host_restic`
- `crownops.deploy_base.host_ufw`

`playbooks/backup.yml` uses the `crownops.deploy_services.host_restic` role.

This repo owns one site-local composition step through `roles/platform_bindings`.

That composition layer derives:

- `platform_ingress_routes`
- `platform_backup_datasets`
- `platform_ufw_requests`

The backup layer is modeled as:

- targets: backup destinations and transport credentials
- datasets: composed durable backup scopes owned by the site layer and feature/host boundaries
- jobs: logical host-owned backup policy with schedule and retention
- converge-time performance policy: no fact gathering for the dedicated backup play, SSH pipelining enabled in the repo Ansible config, and package cache reuse controlled through `host.restic.apt_cache_valid_time`
- restore-first scope policy: back up durable state such as host identity, local markdown workspaces, CouchDB data, and Traefik ACME state, not broad service roots that can be rebuilt from Ansible

`playbooks/lockdown.yml` consumes the reusable `crownops.deploy_base.network_lockdown` role so SSH lockdown policy stays consistent across site repos.

This keeps the site repo thin while still allowing features to evolve independently.

## Synced user vaults

- user_a vault
- user_b vault
- user_c vault

Each gets its own:

- CouchDB database
- CouchDB user
- LiveSync encryption passphrase

## Local markdown workspaces

- shared-docs
- operations
- scratch

Each is a plain markdown directory on disk under `/srv/crownops/vaults/workspaces`.
