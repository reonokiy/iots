#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/talos-common.sh"

load_tofu_outputs
nodes_json="$(tofu_json_value nodes)"
mapfile -t controlplane_ips < <(role_ips_from_json "$nodes_json" controlplane)

if [ "${#controlplane_ips[@]}" -eq 0 ]; then
  printf 'No control-plane nodes found in OpenTofu outputs.\n' >&2
  exit 1
fi

endpoint="$(join_by_comma "${controlplane_ips[@]}")"
talosctl --nodes "${controlplane_ips[0]}" --endpoints "$endpoint" bootstrap
