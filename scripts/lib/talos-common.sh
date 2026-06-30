#!/usr/bin/env bash

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  printf 'This file is intended to be sourced.\n' >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

tofu_json_value() {
  local name="$1"

  tofu -chdir="$repo_root/tofu" output -json "$name" | jq 'if type == "object" and has("value") then .value else . end'
}

tofu_raw() {
  tofu -chdir="$repo_root/tofu" output -raw "$1"
}

node_rows() {
  tofu_json_value nodes | jq -r '
    to_entries
    | sort_by(.value.role_order, .value.index)
    | .[]
    | [.value.name, .value.role, .value.ip, .value.iso_name]
    | @tsv
  '
}

role_ips() {
  local role="$1"

  tofu_json_value nodes | jq -r --arg role "$role" '
    to_entries
    | map(select(.value.role == $role))
    | sort_by(.value.index)
    | .[]
    | .value.ip
  '
}

all_ips() {
  tofu_json_value nodes | jq -r '
    to_entries
    | sort_by(.value.role_order, .value.index)
    | .[]
    | .value.ip
  '
}

join_by_comma() {
  local IFS=,
  printf '%s' "$*"
}

has_yaml_content() {
  local path="$1"

  [ -f "$path" ] && grep -q '^[[:space:]]*[^#[:space:]]' "$path"
}
