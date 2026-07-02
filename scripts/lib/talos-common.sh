#!/usr/bin/env bash

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  printf 'This file is intended to be sourced.\n' >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

load_tofu_outputs() {
  IOTS_TOFU_OUTPUTS="$(tofu -chdir="$repo_root/tofu" output -json)"
}

tofu_outputs() {
  if [ -z "${IOTS_TOFU_OUTPUTS+x}" ]; then
    load_tofu_outputs
  fi

  printf '%s\n' "$IOTS_TOFU_OUTPUTS"
}

tofu_json_value() {
  local name="$1"

  tofu_outputs | jq --arg name "$name" '.[$name].value'
}

tofu_raw() {
  local name="$1"

  tofu_outputs | jq -r --arg name "$name" '.[$name].value'
}

node_rows_from_json() {
  local nodes_json="$1"

  jq -r '
    to_entries
    | sort_by(.value.role_order, .value.index)
    | .[]
    | [.value.name, .value.role, .value.ip, .value.iso_name]
    | @tsv
  ' <<<"$nodes_json"
}

node_rows() {
  node_rows_from_json "$(tofu_json_value nodes)"
}

role_ips_from_json() {
  local nodes_json="$1"
  local role="$2"

  jq -r --arg role "$role" '
    to_entries
    | map(select(.value.role == $role))
    | sort_by(.value.index)
    | .[]
    | .value.ip
  ' <<<"$nodes_json"
}

role_ips() {
  local role="$1"

  role_ips_from_json "$(tofu_json_value nodes)" "$role"
}

all_ips_from_json() {
  local nodes_json="$1"

  jq -r '
    to_entries
    | sort_by(.value.role_order, .value.index)
    | .[]
    | .value.ip
  ' <<<"$nodes_json"
}

all_ips() {
  all_ips_from_json "$(tofu_json_value nodes)"
}

join_by_comma() {
  local IFS=,
  printf '%s' "$*"
}

has_yaml_content() {
  local path="$1"

  [ -f "$path" ] && grep -q '^[[:space:]]*[^#[:space:]]' "$path"
}
