#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

state="tofu/terraform.tfstate"
encrypted_state="tofu/terraform.tfstate.sops.json"

if [ ! -f "$encrypted_state" ]; then
  exit 0
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

decrypted_state="$tmp_dir/terraform.tfstate"
sops --decrypt \
  --input-type json \
  --output-type json \
  --output "$decrypted_state" \
  "$encrypted_state"

jq -e . "$decrypted_state" >/dev/null

if [ -f "$state" ]; then
  jq -S . "$state" > "$tmp_dir/current.json"
  jq -S . "$decrypted_state" > "$tmp_dir/decrypted.json"

  if ! cmp -s "$tmp_dir/current.json" "$tmp_dir/decrypted.json"; then
    printf 'Refusing to overwrite an existing tofu/terraform.tfstate that differs from the encrypted state.\n' >&2
    printf 'Resolve the mismatch manually, or rerun with TOFU_STATE_OVERWRITE=1.\n' >&2
    if [ "${TOFU_STATE_OVERWRITE:-0}" != "1" ]; then
      exit 1
    fi
  fi
fi

install -m 600 "$decrypted_state" "$state"

