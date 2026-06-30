#!/usr/bin/env bash
set -euo pipefail

vm_cidr="${VM_CIDR:-192.168.130.0/24}"
vm_bridge="${VM_BRIDGE:-virbr1}"
singbox_table="${SINGBOX_ROUTE_TABLE:-2022}"
singbox_tun="${SINGBOX_TUN_IFACE:-sing-box-tun}"
singbox_nft_table="${SINGBOX_NFT_TABLE:-sing-box}"
singbox_udp_chain="${SINGBOX_UDP_CHAIN:-prerouting_udp_icmp}"
singbox_mark="${SINGBOX_MARK:-0x00002023}"

if [ "$(id -u)" -ne 0 ]; then
  printf 'Run as root: sudo bash %s\n' "$0" >&2
  exit 1
fi

sysctl -w net.ipv4.conf.all.src_valid_mark=1 >/dev/null
if [ -d "/proc/sys/net/ipv4/conf/$singbox_tun" ]; then
  sysctl -w "net.ipv4.conf.$singbox_tun.rp_filter=0" >/dev/null
fi

if ! nft list chain inet "$singbox_nft_table" "$singbox_udp_chain" >/dev/null 2>&1; then
  printf 'Missing nft chain inet %s %s. Is sing-box TUN running?\n' "$singbox_nft_table" "$singbox_udp_chain" >&2
  exit 1
fi

if ! nft -a list chain inet "$singbox_nft_table" "$singbox_udp_chain" | grep -F "ip saddr $vm_cidr" >/dev/null; then
  nft insert rule inet "$singbox_nft_table" "$singbox_udp_chain" \
    ip saddr "$vm_cidr" \
    ip daddr != @inet4_local_address_set \
    meta l4proto { udp, icmp } \
    meta mark set "$singbox_mark" \
    ct mark set meta mark \
    counter \
    return
fi

ip route replace "$vm_cidr" dev "$vm_bridge" table "$singbox_table"

if iptables -L DOCKER-USER -n >/dev/null 2>&1; then
  iptables -C DOCKER-USER -i "$vm_bridge" -j ACCEPT 2>/dev/null ||
    iptables -I DOCKER-USER 1 -i "$vm_bridge" -j ACCEPT

  iptables -C DOCKER-USER -o "$vm_bridge" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null ||
    iptables -I DOCKER-USER 1 -o "$vm_bridge" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
fi

if command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --zone=libvirt --add-port=123/udp >/dev/null || true
fi

if command -v chronyc >/dev/null 2>&1; then
  chronyc allow "$vm_cidr" >/dev/null || true
fi

printf 'Configured %s via %s for %s route table %s.\n' "$vm_cidr" "$vm_bridge" "$singbox_tun" "$singbox_table"
