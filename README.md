# iots Kubernetes Lab

This directory defines an immutable, declarative Kubernetes lab:

```text
mise      -> project tool versions and tasks
OpenTofu  -> libvirt network, storage, disk, and VM
Talos     -> immutable Kubernetes node OS and cluster bootstrap
Flux      -> GitOps for cluster add-ons and workloads
SOPS/age  -> encrypted secrets, added before committing real secrets
```

The current target is a two-node Talos cluster running in libvirt/KVM VMs:

```text
iots-lab-cp-1      192.168.130.11  control-plane only
iots-lab-worker-1  192.168.130.12  workloads
```

IP addresses and node names are declared in OpenTofu. The libvirt network keeps
MAC/IP reservations for first-boot bootstrap, and `mise run talos:gen-config`
generates matching per-node Talos static network configs from
`tofu output -json nodes`.

## Host Setup

The lab uses the host's system libvirt daemon (`qemu:///system`). Configure the
host before running OpenTofu:

```bash
sudo dnf install -y qemu-kvm libvirt libvirt-daemon-kvm virt-install
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$USER"
```

After changing group membership, start a new login session so `id` includes
`libvirt`. You can verify access with:

```bash
id
virsh -c qemu:///system list --all
```

OpenTofu must be able to manage `qemu:///system` without an interactive polkit
prompt. If the current shell has not picked up the new group yet, log out and
back in before running `mise run tofu:plan` or `mise run tofu:apply`.

The VMs are expected to egress through the host sing-box TUN setup. After
sing-box, Docker, firewalld, or libvirt restarts, re-apply the runtime host
rules:

```bash
mise run host:singbox-libvirt
```

That task marks `192.168.130.0/24` UDP/ICMP traffic for sing-box route table
`2022`, adds the VM subnet route to that table, and keeps Docker's `FORWARD`
chain from dropping libvirt traffic. It also sets `src_valid_mark=1` and disables
`rp_filter` on `sing-box-tun`, which are required for fwmark/TUN UDP replies to
be accepted. TCP traffic is handled by sing-box's transparent proxy rules.

Talos nodes use the host gateway as their NTP server:

```text
NTP server: 192.168.130.1
```

This reuses the host's existing chronyd service; do not add another NTP
component for the lab. If chronyd is not already part of the host baseline,
decide that host policy explicitly instead of letting this repo install it.
The host should serve NTP only on the libvirt network. Runtime setup is handled
by `mise run host:singbox-libvirt`; persistent host setup for an existing
chronyd/firewalld host is:

```bash
sudo firewall-cmd --permanent --zone=libvirt --add-port=123/udp
sudo firewall-cmd --reload
sudo chronyc allow 192.168.130.0/24
```

Also keep this line in `/etc/chrony.conf` so chronyd continues to allow the
VM subnet after restart:

```text
allow 192.168.130.0/24
```

If `sing-box-tun` is recreated, rerun `mise run host:singbox-libvirt` so the
per-interface `rp_filter=0` setting is applied again.

## Quick Start

Trust and install project tools:

```bash
cd /home/iots/github.com/reonokiy/iots
mise trust
mise install
```

Create local variables:

```bash
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
```

Generate and encrypt Talos secrets:

```bash
mise run talos:gen-secrets
mise run talos:encrypt-secrets
```

Create the VMs:

```bash
mise run tofu:init
mise run tofu:apply
mise run host:singbox-libvirt
mise run talos:install-media:attach
```

Generate and apply Talos config:

```bash
mise run talos:gen-config
mise run talos:apply-config
mise run talos:bootstrap
mise run talos:kubeconfig
```

After Talos has installed to `/dev/vda`, remove the temporary install media from
libvirt's persistent domain config:

```bash
mise run talos:install-media:detach
```

Check the cluster:

```bash
mise run talos:health
mise run k8s:nodes
```

Install and run commit hooks:

```bash
mise run hooks:install
mise run hooks:run
```

## VM Defaults

```text
name: iots-lab-cp-1
vCPU: 4
memory: 4096 MiB
disk: 80 GiB
network: iots-lab, 192.168.130.0/24
static IP: 192.168.130.11

name: iots-lab-worker-1
vCPU: 6
memory: 6144 MiB
disk: 100 GiB
network: iots-lab, 192.168.130.0/24
static IP: 192.168.130.12
```

Each VM uses its own Talos ISO volume. This avoids SELinux label conflicts when
both VMs boot at the same time.

## Scaling Nodes

Control-plane and worker counts are declared in `tofu/terraform.tfvars`:

```hcl
controlplane_count = 1
worker_count       = 1
```

OpenTofu derives names, libvirt DHCP reservations, disks, ISO volumes, MACs, and
static IPs for every node. Talos machine configs are then generated from the
same OpenTofu outputs, so do not hand-edit generated files under
`talos/generated/`.

When adding control-plane nodes, keep the worker IP/MAC ranges out of the
control-plane range:

```hcl
controlplane_count = 3
controlplane_ip_start = 11
controlplane_mac_start = 17

worker_count = 2
worker_ip_start = 21
worker_mac_start = 33
```

The default Kubernetes endpoint is the first control-plane IP. For a real HA
control-plane, set `cluster_endpoint` to a stable load-balancer or VIP endpoint
before generating Talos configs.

More details are in `TALOS.md`.
