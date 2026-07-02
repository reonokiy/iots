#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/talos-common.sh"

load_tofu_outputs

action="${1:-}"
virsh_uri="${LIBVIRT_URI:-qemu:///system}"
pool="${LIBVIRT_POOL:-iots-lab}"

usage() {
  printf 'Usage: %s attach|detach\n' "$0" >&2
}

virsh_cmd() {
  virsh -c "$virsh_uri" "$@"
}

is_running() {
  [ "$(virsh_cmd domstate "$1" 2>/dev/null || true)" = "running" ]
}

stop_domain() {
  local domain="$1"

  if ! is_running "$domain"; then
    return 0
  fi

  virsh_cmd shutdown "$domain" >/dev/null || true

  for _ in $(seq 1 30); do
    if ! is_running "$domain"; then
      return 0
    fi
    sleep 1
  done

  virsh_cmd destroy "$domain" >/dev/null
}

start_domain() {
  local domain="$1"

  if is_running "$domain"; then
    return 0
  fi

  virsh_cmd start "$domain" >/dev/null
}

cdrom_xml() {
  local iso="$1"
  local xml="$2"

  cat > "$xml" <<EOF
<disk type='volume' device='cdrom'>
  <driver name='qemu' type='raw'/>
  <source pool='$pool' volume='$iso'/>
  <target dev='sda' bus='sata'/>
  <readonly/>
  <boot order='2'/>
</disk>
EOF
}

detach_virtio_iso_if_present() {
  local domain="$1"

  if virsh_cmd domblklist "$domain" --inactive --details | awk '$2 == "disk" && $3 == "vdb" { found = 1 } END { exit !found }'; then
    virsh_cmd detach-disk "$domain" vdb --config >/dev/null
  fi
}

attach_cdrom() {
  local domain="$1"
  local iso="$2"
  local xml

  if virsh_cmd domblklist "$domain" --inactive --details | awk -v iso="$iso" '$2 == "cdrom" && $4 == iso { found = 1 } END { exit !found }'; then
    return 0
  fi

  xml="$(mktemp)"
  cdrom_xml "$iso" "$xml"
  virsh_cmd attach-device "$domain" "$xml" --config >/dev/null
  rm -f "$xml"
}

detach_cdrom() {
  local domain="$1"
  local iso="$2"
  local xml

  xml="$(mktemp)"
  cdrom_xml "$iso" "$xml"
  virsh_cmd detach-device "$domain" "$xml" --config >/dev/null || true
  rm -f "$xml"
}

case "$action" in
  attach)
    nodes_data="$(node_rows)"

    while IFS=$'\t' read -r name _role _ip _iso_name; do
      stop_domain "$name"
    done <<<"$nodes_data"

    while IFS=$'\t' read -r name _role _ip iso_name; do
      detach_virtio_iso_if_present "$name"
      attach_cdrom "$name" "$iso_name"
    done <<<"$nodes_data"

    while IFS=$'\t' read -r name _role _ip _iso_name; do
      start_domain "$name"
    done <<<"$nodes_data"
    ;;
  detach)
    nodes_data="$(node_rows)"

    while IFS=$'\t' read -r name _role _ip iso_name; do
      detach_cdrom "$name" "$iso_name"
    done <<<"$nodes_data"
    ;;
  *)
    usage
    exit 2
    ;;
esac
