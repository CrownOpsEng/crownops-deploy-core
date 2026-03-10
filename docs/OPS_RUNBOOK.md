# Ops Runbook

## Core commands

Primary interactive path:
`./scripts/setup.sh`

Lower-level deployment runner:
`./scripts/deploy.sh`

Collection install only:
`./scripts/install-collections.sh`

Bootstrap only:
`ansible-playbook playbooks/bootstrap.yml`

Deploy enabled features:
`ansible-playbook playbooks/site.yml`

Deploy backup jobs:
`ansible-playbook playbooks/backup.yml`

Test one backup execution without rerunning the full converge:
`sudo systemctl start crownops-restic-backup-<job>-<target>.service`

Lock down public SSH after Tailscale validation:
`./scripts/ssh-lockdown.sh --confirm`

Validation-only lockdown phase:
`./scripts/ssh-lockdown.sh --phase1-only`

## Manual checks

Docker:
`docker ps`

Traefik:
`docker logs traefik --tail 200`

CouchDB:
`docker logs couchdb --tail 200`

Backup timer state:
`systemctl list-timers 'crownops-restic*'`

Backup service logs:
`sudo journalctl -u crownops-restic-backup-<job>-<target>.service -n 200 --no-pager`

UFW posture:
`sudo ufw status numbered`

Tailscale posture:
`sudo tailscale status`
