# Talos VM Plan

This is the immutable/declarative route:

```text
OpenTofu -> libvirt VM
SOPS -> encrypted Talos secrets
talosctl -> machine config, apply, bootstrap
Talos Linux -> immutable Kubernetes node OS
Flux -> cluster add-ons and workloads, added after the base cluster boots
```

## VM Shape

Default two-node lab:

```text
name: iots-lab-cp-1
role: control-plane only
vCPU: 4
memory: 4096 MiB
disk: 80 GiB qcow2
static IP: 192.168.130.11/24

name: iots-lab-worker-1
role: workloads
vCPU: 6
memory: 6144 MiB
disk: 100 GiB qcow2
static IP: 192.168.130.12/24

network: dedicated libvirt NAT, 192.168.130.0/24
gateway: 192.168.130.1
DNS: 192.168.130.1, 1.1.1.1
NTP: 192.168.130.1
boot: Talos metal ISO, install to /dev/vda
Kubernetes endpoint: 192.168.130.11:6443
Talos API endpoint: 192.168.130.11:50000
```

The control-plane node sets `cluster.allowSchedulingOnControlPlanes: false`, so normal workloads should land on the worker.

## Commands

Project tools are declared in `.mise.toml`:

```bash
cd /home/iots/github.com/reonokiy/iots
mise install
```

Then bootstrap with:

```bash
cd /home/iots/github.com/reonokiy/iots
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
mise run talos:gen-secrets
mise run talos:encrypt-secrets
mise run tofu:init
mise run tofu:apply
mise run host:singbox-libvirt
mise run talos:install-media:attach
mise run talos:gen-config
mise run talos:apply-config
mise run talos:bootstrap
mise run talos:kubeconfig
```

The VM/libvirt bootstrap addresses are controlled by `tofu/terraform.tfvars`
and libvirt DHCP MAC/IP reservations:

```hcl
libvirt_network_cidr = "192.168.130.0/24"
controlplane_count   = 1
controlplane_ip_start = 11
worker_count         = 1
worker_ip_start      = 12
```

OpenTofu exports the node inventory through `tofu output -json nodes`. The
Talos static network config, hostname config, `talos/talosconfig`, and per-node
machine configs are generated from that inventory by
`scripts/talos-gen-config.sh`. `talos/patches/controlplane.yaml` and
`talos/patches/worker.yaml` are role-wide patches only.

Generated Talos node configs also point time sync at the host gateway
`192.168.130.1`; the host's existing chronyd service is responsible for upstream
time sync. Avoid adding a separate NTP component just for this lab.

After apply:

```bash
export TALOSCONFIG=/home/iots/github.com/reonokiy/iots/talos/talosconfig
export KUBECONFIG=/home/iots/github.com/reonokiy/iots/kubeconfig/iots-lab.yaml

mise run talos:health
mise run k8s:nodes
mise run hooks:run
```

## Host Network Notes

- The VM network stays dedicated to libvirt NAT, but VM egress is routed through
  the host sing-box TUN rules.
- Run `mise run host:singbox-libvirt` after sing-box, Docker, firewalld, or
  libvirt restarts.
- Run `mise run talos:install-media:attach` after VM creation so Talos boots
  from the ISO as a SATA CD-ROM. The libvirt provider represents the ISO as a
  normal disk for refresh compatibility, but SeaBIOS does not boot that ISO
  reliably in this lab.
- After Talos installs to `/dev/vda`, run `mise run talos:install-media:detach`
  and reboot the existing domains once so future OpenTofu refreshes stay clean.
- The host script disables `rp_filter` on `sing-box-tun` and enables
  `src_valid_mark`; without that, UDP replies through the TUN can be visible in
  packet captures but not delivered to chronyd or forwarded clients.
- Talos uses host-local NTP because forwarded UDP/123 through a userspace TUN is
  fragile; the host itself remains synchronized upstream using its existing
  time-sync service.
- Keep `/etc/chrony.conf` allowing `192.168.130.0/24` and firewalld's `libvirt`
  zone allowing `123/udp`.

## Why This VM Config

- NAT keeps the VM separate from the host LAN while host rules steer egress into sing-box TUN.
- The VM IPs are declared twice on purpose: libvirt reserves them for first boot, and Talos then configures the same static IPs in machine configs.
- 4 GiB on the control-plane is enough for etcd and Kubernetes control-plane services in a lab.
- 6 GiB on the worker gives workload pods the larger share of memory.
- 80/100 GiB disks leave room for image pulls and experiments without making snapshots huge.

## Scaling Nodes

The OpenTofu layer supports changing the number of control-plane and worker
nodes:

```hcl
controlplane_count = 3
worker_count       = 2
```

Use non-overlapping generated IP and MAC ranges:

```hcl
controlplane_ip_start  = 11
controlplane_mac_start = 17
worker_ip_start        = 21
worker_mac_start       = 33
```

For HA on this host, be conservative:

```text
3 control-plane VMs: 2 vCPU / 3 GiB RAM / 40 GiB each
```

The default `cluster_endpoint` is the first control-plane IP. That is enough for
this lab's no-extra-components route, but it is not a highly available API
endpoint. Set `cluster_endpoint` to a stable VIP or load-balancer endpoint if
one is added later.

## Secrets

Talos secrets are generated into:

```text
talos/secrets.yaml
```

That plaintext file is ignored by git. The encrypted copy is:

```text
talos/secrets.sops.yaml
```

The SOPS recipients are declared in `.sops.yaml`:

```text
local age key: ~/.config/sops/age/keys.txt
backup key: the configured ssh-ed25519 public key
```

OpenTofu state only manages libvirt resources. Talos secrets and generated machine configs live outside Tofu state.
