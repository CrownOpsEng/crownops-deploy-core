# Preflight Validation

This package now includes an aggregated preflight validation layer.

## Goal

Surface as many configuration and topology issues as possible in one pass, then fail once at the end.

This avoids the usual bad Ansible workflow where one placeholder or missing variable stops execution, you fix it, rerun, then hit the next one.

## Playbook

```bash
ansible-playbook -i inventories/prod/hosts.yml playbooks/preflight.yml
```

## What it checks

- inventory group population
- host placeholder values
- `ansible_host` placeholder or loopback values
- `ansible_user` and `bootstrap_ansible_user` presence
- base/ops domain presence and placeholder values
- SSH public key population
- HTTPS firewall exposure for Traefik on TCP 443
- Traefik ACME email and DNS provider configuration
- ACME provider env placeholders
- CouchDB admin credentials
- human vault definitions for `you`, `kid1`, `kid2`
- duplicate vault names, DB names, or users
- placeholder human vault passwords
- exact expected agent vault set: `aegis`, `helios`, `relay`, `quartermaster`
- path collisions between `vault_root` and `exports_root`
- restic repository and password placeholders
- Tailscale auth/bootstrap placeholders
- placeholder marker sweep across key variables
- remote connectivity probe

## Output

The role writes a local report to:

- `reports/preflight-ovh_core.txt`

The playbook prints warnings and errors, then fails only after the full validation pass if any errors remain.

## Important limitation

This is a **configuration and readiness preflight**, not full deployment proof.
It does not replace live validation of:

- DNS correctness
- ACME issuance success
- Android LiveSync sync success
- backup restore correctness

Those still require execution and verification.
