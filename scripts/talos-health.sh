#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/talos-common.sh"

load_tofu_outputs
nodes_json="$(tofu_json_value nodes)"
mapfile -t controlplane_ips < <(role_ips_from_json "$nodes_json" controlplane)
mapfile -t worker_ips < <(role_ips_from_json "$nodes_json" worker)

if [ "${#controlplane_ips[@]}" -eq 0 ]; then
  printf 'No control-plane nodes found in OpenTofu outputs.\n' >&2
  exit 1
fi

if [ "${#worker_ips[@]}" -eq 0 ]; then
  printf 'No worker nodes found in OpenTofu outputs.\n' >&2
  exit 1
fi

talosctl \
  --nodes "${controlplane_ips[0]}" \
  --endpoints "$(join_by_comma "${controlplane_ips[@]}")" \
  health \
  --control-plane-nodes "$(join_by_comma "${controlplane_ips[@]}")" \
  --worker-nodes "$(join_by_comma "${worker_ips[@]}")"
