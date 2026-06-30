# Agent Notes

This directory is a declarative Talos-on-libvirt Kubernetes lab. Keep edits aligned with the current split of responsibilities:

```text
mise      -> tool versions, env vars, repeatable tasks
OpenTofu  -> libvirt network, storage pool, VM disks, VM domains
SOPS/age  -> encrypted Talos secrets
talosctl  -> Talos machine configs, apply, bootstrap, kubeconfig
Flux      -> future GitOps add-ons and workloads
```

## Current Topology

```text
default nodes:
  iots-lab-cp-1      192.168.130.11  control-plane only
  iots-lab-worker-1  192.168.130.12  workload node

libvirt network:    iots-lab
CIDR:               192.168.130.0/24
gateway/DNS:        192.168.130.1
Talos version:      v1.13.5
Kubernetes:         1.36.1
node inventory:     tofu output -json nodes
```

The control-plane must not run normal workloads. This is declared in
`talos/patches/controlplane.yaml`:

```yaml
cluster:
  allowSchedulingOnControlPlanes: false
```

## What To Edit

- VM count, shape, disks, MACs, static IP reservations:
  edit `tofu/variables.tf`, `tofu/main.tf`, `tofu/outputs.tf`, and `tofu/terraform.tfvars.example`.
- Talos static network settings and hostnames:
  generated from `tofu output -json nodes` by `scripts/talos-gen-config.sh`.
- Talos role-wide patches:
  edit `talos/patches/controlplane.yaml` and/or `talos/patches/worker.yaml`.
- Project tools and operational commands:
  edit `.mise.toml`.
- Host runtime networking for libvirt through sing-box:
  edit `scripts/host-singbox-libvirt.sh`, `.mise.toml`, and `README.md`.
- SOPS recipients:
  edit `.sops.yaml`.
- User-facing setup docs:
  edit `README.md` and `TALOS.md`.

When adding nodes, prefer changing only the Tofu variables:

```hcl
controlplane_count = 3
worker_count       = 2
```

Keep generated IP/MAC ranges non-overlapping. `mise run talos:gen-config`
derives per-node Talos configs from OpenTofu outputs, so do not add separate
hand-written per-node Talos patch files.

## Generated Or Sensitive Files

Do not commit plaintext secrets or generated client configs:

```text
talos/secrets.yaml
talos/generated/
talos/talosconfig
kubeconfig/*.yaml
tofu/.terraform/
tofu/*.tfstate
tofu/*.tfstate.*
```

The encrypted Talos secrets file is intended to be committed:

```text
talos/secrets.sops.yaml
```

OpenTofu state currently manages only libvirt resources. Talos secrets are kept outside Tofu state and are managed through `talos/secrets.yaml` plus `talos/secrets.sops.yaml`.

## Prek Hooks

This repo uses `prek`, not `pre-commit`. The hook config is `prek.toml`.

Install hooks after cloning or after `git init`:

```bash
mise trust
mise install
mise run hooks:install
```

Run hooks manually:

```bash
mise run hooks:run
```

Current hooks:

```text
tofu-state-sops-guard
  script: scripts/tofu-state-guard.sh
  purpose:
    - If tofu/terraform.tfstate exists, encrypt it to tofu/terraform.tfstate.sops.json.
    - Verify the encrypted state decrypts back to the plaintext state.
    - git add tofu/terraform.tfstate.sops.json during pre-commit.
    - Refuse commits that stage plaintext tofu/terraform.tfstate or terraform.tfstate.backup.

no-plaintext-secrets
  script: scripts/no-plaintext-secrets.sh
  purpose:
    - Refuse staged plaintext secret/state files.
    - Verify staged *.sops.yaml, *.sops.yml, *.sops.json, and tofu/terraform.tfstate.sops.json are actually SOPS-encrypted.
```

The hooks check staged files rather than every ignored file in the working tree. This is intentional: plaintext files such as `talos/secrets.yaml`, `talos/talosconfig`, generated Talos configs, kubeconfigs, and local OpenTofu state may exist locally while operating the lab, but must not be committed.

OpenTofu state workflow:

```bash
mise run tofu:state:decrypt  # no-op when no encrypted state exists yet
mise run tofu:apply          # or mise run tofu:apply:safe
mise run tofu:state:encrypt
mise run hooks:run
```

The file intended for Git is:

```text
tofu/terraform.tfstate.sops.json
```

## Common Commands

Run from `iots/`:

```bash
mise trust
mise install
mise run hooks:install
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
```

Secrets:

```bash
mise run talos:gen-secrets
mise run talos:encrypt-secrets
mise run talos:decrypt-secrets
```

VMs:

```bash
mise run tofu:init
mise run tofu:plan
mise run tofu:apply
mise run host:singbox-libvirt
```

Talos/Kubernetes bootstrap:

```bash
mise run host:singbox-libvirt
mise run talos:install-media:attach
mise run talos:gen-config   # generates talos/generated/<node>.yaml
mise run talos:apply-config # applies every generated node config
mise run talos:bootstrap
mise run talos:kubeconfig
```

Checks:

```bash
mise run talos:health
mise run k8s:nodes
for f in talos/generated/iots-lab-*.yaml; do talosctl validate --mode metal --config "$f"; done
mise run hooks:run
```

## Editing Rules

- Prefer changing declarative sources over generated files.
- Do not manually edit files under `talos/generated/`; regenerate with `mise run talos:gen-config`.
- Do not put Talos secrets back into OpenTofu resources/providers/state.
- Keep `prek.toml` hooks active: `tofu-state-sops-guard` encrypts state, and `no-plaintext-secrets` blocks staged plaintext secrets while verifying SOPS files.
- If Git hooks appear missing, rerun `mise run hooks:install`.
- Keep node inventory in Tofu. Do not duplicate static IPs in Talos patches.
- Talos NTP is intentionally local to the host gateway `192.168.130.1`; reuse the host's existing chronyd rather than adding a new NTP component. If chronyd is present, it must allow `192.168.130.0/24`, and firewalld `libvirt` zone must allow `123/udp`.
- VM egress should go through sing-box TUN. Re-run `mise run host:singbox-libvirt` after sing-box, Docker, firewalld, or libvirt restarts; it restores the VM fwmark rule, route table entry, Docker forwarding accepts, and `sing-box-tun` `rp_filter=0`.
- First boot needs `mise run talos:install-media:attach` because Talos ISO boots reliably as a SATA CD-ROM, while the libvirt provider can only refresh safely when the OpenTofu model keeps ISO volumes as normal disks. After install, run `mise run talos:install-media:detach`, reboot existing domains, then run `tofu plan`.
- After HCL edits, run `mise exec -- tofu fmt -recursive tofu`.
- After Talos patch edits, run `mise run talos:gen-config` and validate both generated machine configs.
- If `.mise.toml` tasks change, update `README.md` and `TALOS.md` when the user workflow changes.
