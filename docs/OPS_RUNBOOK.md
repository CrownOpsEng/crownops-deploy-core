# Ops Runbook

## Core commands

Preferred wrapper:
`./scripts/deploy.sh`

Collection install only:
`./scripts/install-collections.sh`

Bootstrap only:
`ansible-playbook playbooks/bootstrap.yml`

Deploy enabled features:
`ansible-playbook playbooks/site.yml`

Deploy backup jobs:
`ansible-playbook playbooks/backup.yml`

Lock down public SSH after Tailscale validation:
`./scripts/lockdown.sh`

## Manual checks

Docker:
`docker ps`

Traefik:
`docker logs traefik --tail 200`

CouchDB:
`docker logs couchdb --tail 200`

Backup timer state:
`systemctl list-timers | grep crownops-restic`
