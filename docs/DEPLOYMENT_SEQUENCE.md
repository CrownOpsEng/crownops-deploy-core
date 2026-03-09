# Deployment Sequence

## 1. Fill variables and secrets
Update:
- inventories/prod/hosts.yml
- inventories/prod/group_vars/all.yml
- inventories/prod/group_vars/ovh_core.yml

Important:
- set `bootstrap_ansible_user` to the existing first-login account on the host, usually `root`
- keep `ansible_user` as the steady-state operator account Ansible should use after bootstrap, usually `deploy`
- set `ovh_bootstrap_ubuntu_release` to `jammy` for Ubuntu 22.04 or `noble` for Ubuntu 24.04

## 2. Install collections
`./scripts/install-collections.sh`

## 3. Bootstrap OVH host
`ansible-playbook playbooks/bootstrap-ovh.yml`

## 4. Deploy core services
`ansible-playbook playbooks/site.yml`

## 5. Configure backup jobs
`ansible-playbook playbooks/backup-setup.yml`

## 6. Validate manually
- SSH access works
- Docker works
- Tailscale joins cleanly
- Traefik container healthy
- HTTPS certificate issued successfully
- CouchDB reachable through Traefik
- run CouchDB bootstrap helper if not automated yet
- Android Obsidian LiveSync works for your vault
- restic backup to H4F works
- restic backup to laptop works when reachable

## 7. Handoff kid vaults
Each kid should complete or rotate their final LiveSync encryption passphrase.
