# Quick Start: Fresh Ubuntu Host

This is the shortest supported path from a brand new Ubuntu VPS to the full OVH deployment.

## Repo layout

Keep the reusable base collection separate from the OVH deployment repo:

```text
vps/
  000-vps-base/
    crownops-vps-base/
  002-ovh-4-8-75n/
    crownops-ovh-obsidian-ansible-package/
```

This keeps GitHub clean:
- `000-vps-base` holds only shared bootstrap logic
- `002-ovh-...` holds OVH-specific inventory, secrets, and application roles

## 1. Prepare the fresh VPS

Requirements on the target host:
- fresh Ubuntu 22.04 or 24.04 install
- inbound SSH reachable
- you can log in with the `bootstrap_ansible_user`, usually `root`

Requirements on the control host:
- Ansible installed
- access to both local repos above

## 2. Fill inventory and vars

Update:
- `inventories/prod/hosts.yml`
- `inventories/prod/group_vars/all.yml`
- `inventories/prod/group_vars/ovh_core.yml`

Required minimum decisions:
- real `ansible_host`
- `bootstrap_ansible_user`
- steady-state `ansible_user`
- `ovh_bootstrap_ubuntu_release`
- real SSH public key(s)
- real DNS and ACME settings
- real CouchDB credentials
- real restic targets and passwords
- real Tailscale auth key

## 3. Encrypt secrets

Move secret values into Ansible Vault before first real deploy.

## 4. Install collections

Run:

```bash
./scripts/install-collections.sh
```

What it does:
- installs public collection dependencies into `./.ansible/collections`
- builds the sibling `000-vps-base/crownops-vps-base` collection
- installs that collection locally into the OVH repo

## 5. Run preflight

```bash
ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml
```

Expected result before deploy:
- no placeholder values remain
- SSH/bootstrap users are set correctly
- Ubuntu release selector is valid
- HTTPS port 443 is allowed
- backup and Tailscale values are real

## 6. Bootstrap the fresh host

```bash
ansible-playbook -i inventories/prod/hosts.yml playbooks/bootstrap-ovh.yml
```

This step now uses the shared collection role:
- `crownops.vps_base.bootstrap_host`

That baseline handles:
- package updates
- admin user creation
- SSH hardening
- UFW
- fail2ban
- unattended upgrades
- Docker install
- Tailscale install/join

Then the OVH repo adds:
- vault/export directory layout
- agent vault directories

## 7. Deploy OVH services

```bash
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml
ansible-playbook -i inventories/prod/hosts.yml playbooks/backup-setup.yml
```

## 8. Validate manually

- SSH works as the steady-state operator user
- Docker is healthy
- Tailscale is up
- Traefik issued certificates
- CouchDB is reachable at `https://notes.<ops_domain>`
- restic backups run successfully

## 9. Publish the base repo later

When you are ready to move beyond local sibling repos, publish `000-vps-base/crownops-vps-base` as its own Git repo.

Keep this rule:
- shared bootstrap logic lives in the base repo
- deployment inventories and secrets stay in deployment repos
