#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/talos-common.sh"

load_tofu_outputs
cluster_name="$(tofu_raw cluster_name)"
nodes_json="$(tofu_json_value nodes)"
mapfile -t controlplane_ips < <(role_ips_from_json "$nodes_json" controlplane)

if [ "${#controlplane_ips[@]}" -eq 0 ]; then
  printf 'No control-plane nodes found in OpenTofu outputs.\n' >&2
  exit 1
fi

endpoint="$(join_by_comma "${controlplane_ips[@]}")"
mkdir -p "$repo_root/kubeconfig"
talosctl --nodes "${controlplane_ips[0]}" --endpoints "$endpoint" kubeconfig --force --force-context-name "$cluster_name" "$repo_root/kubeconfig/${cluster_name}.yaml"
