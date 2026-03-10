# Configuration Wizard Specification

## Purpose

Define the delivery contract for a local configuration wizard that prepares Ansible deployment config, generates strong secrets, and stays reusable across multiple deployment repos.

This document is the implementation reference for the first delivery. It is intentionally provider-agnostic so the wizard does not get boxed into a single secret manager.

## Goals

- provide a fast, robust operator setup path for new deployments
- keep the existing Ansible inventory contract stable
- generate strong local secrets by default
- branch the UX so operators only answer relevant questions
- clearly show operator-record details before exiting
- optionally write a sensitive details file
- optionally write a sanitized audit log
- support future secret providers such as Bitwarden, 1Password, Vaultwarden, cloud secret managers, and HashiCorp Vault without redesigning the core wizard

## Non-goals

- replace Ansible playbooks or inventory structure
- invent a second site-specific configuration format
- require a specific hosted secret manager
- store raw secrets in logs
- depend on runtime network access for the initial delivery

## Current repo contract

The wizard must write the same local files already expected by this repo:

- `inventories/prod/hosts.yml`
- `inventories/prod/group_vars/all/main.yml`
- `inventories/prod/group_vars/core_hosts/main.yml`
- `inventories/prod/group_vars/all/vault.yml`

It must preserve the existing split:

- `all/main.yml` for non-secret structure
- `all/vault.yml` for secret values

Default secret storage backend for this repo:

- local `ansible-vault` encrypted `all/vault.yml`

## Delivery shape

The first implementation should be a local Python CLI wizard.

Recommended stack:

- `rich` for layout, review screens, and status output
- `questionary` for prompts, branching, and masked inputs
- `PyYAML` or `ruamel.yaml` for YAML round-tripping and file emission

Bash is not the right long-term surface for conditional flows, masked secret review, provider plugins, or safe atomic writes.

## Core architecture

The wizard should be built from small replaceable parts.

### 1. Profile schema

A deployment profile defines:

- which phases and stages exist
- which fields are required
- which defaults are used
- which conditions control branching
- where each answer is written
- how secrets are sourced and stored

Profiles should live under a dedicated path such as `wizard/profiles/`.

### 2. Wizard engine

The engine is responsible for:

- loading a profile
- evaluating phase, stage, and field conditions
- collecting answers
- validating answers
- generating secrets when needed
- rendering a final review screen
- writing outputs

The engine must not contain provider-specific logic.

### 3. Secret source layer

Every secret field must resolve through a generic source model:

- `generate`
- `prompt`
- `env`
- `file`
- `external_vault`

This is the key abstraction that keeps the system portable.

### 4. Secret storage backend layer

The place where a secret ends up is separate from how it was obtained.

Supported backend types should include:

- `ansible_vault_file`
- `sops_file`
- `runtime_lookup`

The first delivery only needs to fully implement `ansible_vault_file`.

### 5. Vault driver layer

External secret managers must be pluggable through vendor drivers rather than special cases in the core engine.

Expected drivers:

- `bitwarden`
- `1password`
- `vaultwarden`
- `aws_secrets_manager`
- `gcp_secret_manager`
- `hashicorp_vault`

The first planned external-vault design target is Bitwarden Secrets Manager, but the interfaces must remain generic.

## Provider model

The internal model should use three concepts.

### Secret source

Describes where a value comes from.

Examples:

- generate a random password locally
- prompt the operator to paste a DNS API token
- read a value from an environment variable
- fetch a secret from an external vault

### Secret backend

Describes how the deployment consumes the value.

Examples:

- materialize into `inventories/prod/group_vars/all/vault.yml`
- materialize into a future `sops` file
- leave as a runtime lookup expression

### Vault driver

Describes how a specific vendor is accessed.

Examples:

- Bitwarden Secrets Manager
- 1Password service account / CLI / SDK
- cloud-managed secret stores

The core wizard must not assume one provider's auth style, path format, or naming model.

## Field schema

Each field should be declared in data, not hardcoded into prompt logic.

Minimum field contract:

```yaml
id: couchdb_admin_password
label: CouchDB admin password
type: secret
stage: features
required: true
when: feature_obsidian_enabled == true
default: null
target:
  file: inventories/prod/group_vars/all/vault.yml
  path: vault_couchdb_admin_password
source:
  kind: generate
  generator: password
  params:
    length: 32
storage:
  backend: ansible_vault_file
review:
  mask_by_default: true
record_policy: operator_record
rotation_policy: replace_on_regenerate
```

Future external-vault example:

```yaml
source:
  kind: external_vault
  driver: bitwarden
  ref:
    secret_id: 00000000-0000-0000-0000-000000000000
storage:
  backend: ansible_vault_file
```

Future runtime lookup example:

```yaml
source:
  kind: external_vault
  driver: bitwarden
  ref:
    secret_id: 00000000-0000-0000-0000-000000000000
storage:
  backend: runtime_lookup
```

## Secret generation standards

Generated secrets must be created locally using cryptographically strong randomness.

Defaults:

- machine passwords and tokens: high-entropy random strings
- human-recorded passphrases: memorable multi-word passphrases
- SSH keys: Ed25519 by default

The wizard must never auto-generate credentials that are issued by third-party systems and must be provisioned elsewhere, such as:

- DNS provider API tokens
- Tailscale auth keys
- cloud account credentials

Those values should be prompted for or referenced from an external vault.

## UX flow

The wizard should be short by default and branch only when needed.

Recommended top-level flow:

1. choose deployment profile
2. choose mode: quick setup or customize
3. collect host and operator basics
4. collect feature toggles
5. branch into enabled feature stages only
6. resolve secret sources and generate values where applicable
7. show review screen
8. show operator record screen
9. choose optional outputs
10. write files
11. optionally encrypt `vault.yml`
12. optionally run preflight

UX requirements:

- sensible defaults
- clear required vs optional labels
- masked secret display by default
- reveal-on-demand for operator review
- explicit keep/edit/rotate behavior on reruns
- no dead-end branches

## Operator record screen

Before any write completes, the wizard must show the details the operator may need to retain.

Examples:

- generated SSH public keys
- secret fingerprints
- generated passphrases that will not be re-shown later
- backup public-key install text
- vault password file path if one is created
- external secret references when a provider is used

The operator record screen must be separate from the sanitized log.

## Optional file outputs

### Sensitive details file

Purpose:

- optional operator record or break-glass record

Rules:

- off by default
- explicit opt-in
- `0600` permissions
- atomic write
- never committed
- may contain raw secrets only when the operator explicitly chooses that mode

### Sanitized audit log

Purpose:

- show what happened without leaking secrets

Allowed content:

- timestamps
- selected profile
- completed stages
- file write targets
- whether secrets were generated, prompted, or externally resolved
- secret fingerprints or IDs where appropriate

Forbidden content:

- raw passwords
- raw tokens
- private keys
- full secret values fetched from providers

## Security requirements

- generate secrets locally using Python `secrets`
- use atomic writes for all config and record files
- set secret-bearing file permissions to `0600`
- do not echo raw secrets to stdout except in the dedicated review/record screens
- do not store raw secrets in logs
- clear in-memory secret material when practical after writes
- require explicit confirmation before overwriting existing secret material
- support immediate `ansible-vault encrypt` at the end of the flow

## Rerun behavior

Reruns must be safe and predictable.

For existing values, the wizard should offer:

- keep
- edit
- rotate
- re-resolve from provider

It must not silently overwrite existing secrets.

## Repo integration points

Planned repo integration:

- `scripts/setup.sh` becomes the preferred operator entrypoint
- `scripts/init-local-config.sh` remains as a simple compatibility scaffold
- `scripts/deploy.sh` remains the lower-level deployment runner
- `scripts/ssh-lockdown.sh` remains the lower-level SSH hardening runner
- the wizard owns the interactive stage model instead of handing off to another interactive peer UI
- preflight remains the validation gate after config generation

The wizard should emit the same variable shapes currently expected by:

- inventory files
- `playbooks/preflight.yml`
- `playbooks/bootstrap.yml`
- `playbooks/site.yml`
- `playbooks/backup.yml`
- `playbooks/lockdown.yml`

## External vault readiness

The implementation must be flexible enough to add Bitwarden, 1Password, or another secret vault later without changing the engine or profile schema.

That means:

- provider auth must be driver-specific
- secret references must use a normalized internal shape
- capability checks must be declarative
- unsupported driver features must degrade cleanly to prompt or generate flows

Suggested driver capability flags:

- `can_read`
- `can_write`
- `can_list`
- `supports_runtime_lookup`
- `supports_binary`

## Bitwarden planning note

The first external-vault target should be Bitwarden Secrets Manager, not a personal password-vault-only workflow.

Reason:

- better match for infrastructure automation
- supports machine-oriented access tokens
- aligns with Ansible-oriented secret retrieval patterns

This is a planning target only. The core design must remain vendor-neutral.

## Implementation phases

### Phase 1

- implement the Python wizard engine
- support the current `crownops-deploy-core` profile
- write `hosts.yml`, `all.yml`, `core_hosts.yml`, and `vault.yml`
- support local secret generation
- support optional sensitive details file
- support optional sanitized log
- support end-of-run `ansible-vault encrypt`
- support optional preflight execution

### Phase 2

- add rerun-safe rotation behavior
- add profile packs for additional Ansible deployment repos
- add richer validation before file write

### Phase 3

- add external vault driver support
- start with Bitwarden driver implementation
- add runtime lookup backend where useful

## Acceptance criteria

The first delivery is acceptable when:

- a new operator can complete a minimal deployment config without manual YAML editing
- feature-disabled stages are skipped automatically
- generated secrets are strong and written only to approved destinations
- `vault.yml` can be encrypted immediately at the end of the flow
- the wizard can produce the current repo's expected config shape
- the design clearly supports future external vault drivers without core refactor

## Decision summary

- keep Ansible Vault as the default storage model for this repo
- implement the wizard as a local Python CLI
- make the schema data-driven
- separate secret source, secret backend, and vault driver concerns
- design for future Bitwarden and 1Password support without special-casing either in the core
