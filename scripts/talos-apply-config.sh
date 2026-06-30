#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/talos-common.sh"

while IFS=$'\t' read -r name _role ip _iso_name; do
  config_file="$repo_root/talos/generated/${name}.yaml"

  if [ ! -f "$config_file" ]; then
    printf 'Missing generated Talos config: %s\n' "$config_file" >&2
    exit 1
  fi

  talosctl apply-config --insecure --nodes "$ip" --file "$config_file"
done < <(node_rows)
