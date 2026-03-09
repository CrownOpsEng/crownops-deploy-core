# Ops Runbook

## Core commands
Bootstrap:
`ansible-playbook playbooks/bootstrap-ovh.yml`

Deploy services:
`ansible-playbook playbooks/site.yml`

Deploy backup jobs:
`ansible-playbook playbooks/backup-setup.yml`

## Manual checks
Docker:
`docker ps`

Traefik:
`docker logs traefik --tail 200`

CouchDB:
`docker logs couchdb --tail 200`

Backup timer state:
`systemctl list-timers | grep crownops-restic`
