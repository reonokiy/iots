#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/talos-common.sh"

load_tofu_outputs

apply_mode="${1:-${TALOS_APPLY_MODE:-auto}}"
nodes_json="$(tofu_json_value nodes)"
mapfile -t controlplane_ips < <(role_ips_from_json "$nodes_json" controlplane)

if [ "${#controlplane_ips[@]}" -eq 0 ]; then
  printf 'No control-plane nodes found in OpenTofu outputs.\n' >&2
  exit 1
fi

endpoint="$(join_by_comma "${controlplane_ips[@]}")"

usage() {
  printf 'Usage: %s [auto|secure|insecure]\n' "$0" >&2
}

is_configured_node() {
  local ip="$1"

  talosctl --nodes "$ip" --endpoints "$endpoint" get machinestatus >/dev/null 2>&1
}

apply_secure() {
  local ip="$1"
  local config_file="$2"

  talosctl apply-config --nodes "$ip" --endpoints "$endpoint" --file "$config_file"
}

apply_insecure() {
  local ip="$1"
  local config_file="$2"

  talosctl apply-config --insecure --nodes "$ip" --file "$config_file"
}

case "$apply_mode" in
  auto | secure | insecure)
    ;;
  *)
    usage
    exit 2
    ;;
esac

while IFS=$'\t' read -r name _role ip _iso_name; do
  config_file="$repo_root/talos/generated/${name}.yaml"

  if [ ! -f "$config_file" ]; then
    printf 'Missing generated Talos config: %s\n' "$config_file" >&2
    exit 1
  fi

  case "$apply_mode" in
    secure)
      apply_secure "$ip" "$config_file"
      ;;
    insecure)
      apply_insecure "$ip" "$config_file"
      ;;
    auto)
      if is_configured_node "$ip"; then
        apply_secure "$ip" "$config_file"
      else
        apply_insecure "$ip" "$config_file"
      fi
      ;;
  esac
done < <(node_rows_from_json "$nodes_json")
