#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/talos-common.sh"

load_tofu_outputs

generated_dir="$repo_root/talos/generated"
base_dir="$generated_dir/base"
patch_dir="$generated_dir/patches"
talosconfig="$repo_root/talos/talosconfig"
controlplane_patch="$repo_root/talos/patches/controlplane.yaml"
worker_patch="$repo_root/talos/patches/worker.yaml"

cluster_name="$(tofu_raw cluster_name)"
cluster_endpoint="$(tofu_raw cluster_endpoint)"
gateway_ip="$(tofu_raw gateway_ip)"
network_prefix="$(tofu_raw network_prefix)"
talos_version="$(tofu_raw talos_version)"
kubernetes_version="$(tofu_raw kubernetes_version)"
nodes_json="$(tofu_json_value nodes)"

mapfile -t controlplane_ips < <(role_ips_from_json "$nodes_json" controlplane)
mapfile -t all_node_ips < <(all_ips_from_json "$nodes_json")

if [ "${#controlplane_ips[@]}" -eq 0 ]; then
  printf 'No control-plane nodes found in OpenTofu outputs.\n' >&2
  exit 1
fi

rm -rf "$generated_dir"
mkdir -p "$base_dir" "$patch_dir"

gen_args=(
  gen config "$cluster_name" "$cluster_endpoint"
  --with-secrets "$repo_root/talos/secrets.yaml"
  --output "$base_dir"
  --force
  --talos-version "$talos_version"
  --kubernetes-version "$kubernetes_version"
  --install-disk /dev/vda
  --install-image "ghcr.io/siderolabs/installer:${talos_version}"
)

for ip in "${controlplane_ips[@]}"; do
  gen_args+=(--additional-sans "$ip")
done

if has_yaml_content "$controlplane_patch"; then
  gen_args+=(--config-patch-control-plane "@${controlplane_patch}")
fi

if has_yaml_content "$worker_patch"; then
  gen_args+=(--config-patch-worker "@${worker_patch}")
fi

talosctl "${gen_args[@]}"

while IFS=$'\t' read -r name role ip _iso_name; do
  patch_file="$patch_dir/${name}.yaml"
  output_file="$generated_dir/${name}.yaml"

  cat > "$patch_file" <<EOF
machine:
  time:
    servers:
      - ${gateway_ip}
  network:
    interfaces:
      - interface: ens3
        dhcp: false
        addresses:
          - ${ip}/${network_prefix}
        routes:
          - network: 0.0.0.0/0
            gateway: ${gateway_ip}
    nameservers:
      - ${gateway_ip}
      - 1.1.1.1
---
apiVersion: v1alpha1
kind: HostnameConfig
auto:
  \$patch: delete
hostname: ${name}
EOF

  case "$role" in
    controlplane)
      talosctl machineconfig patch "$base_dir/controlplane.yaml" --patch "@${patch_file}" --output "$output_file"
      ;;
    worker)
      talosctl machineconfig patch "$base_dir/worker.yaml" --patch "@${patch_file}" --output "$output_file"
      ;;
    *)
      printf 'Unknown Talos role %s for node %s.\n' "$role" "$name" >&2
      exit 1
      ;;
  esac
done < <(node_rows_from_json "$nodes_json")

cp "$base_dir/talosconfig" "$talosconfig"
chmod 600 "$talosconfig"
talosctl --talosconfig "$talosconfig" config endpoint "${controlplane_ips[@]}"
talosctl --talosconfig "$talosconfig" config node "${all_node_ips[@]}"
