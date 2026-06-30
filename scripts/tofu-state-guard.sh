#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

state="tofu/terraform.tfstate"
encrypted_state="tofu/terraform.tfstate.sops.json"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

is_git_repo=false
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  is_git_repo=true
fi

fail_if_plaintext_state_is_staged() {
  if [ "$is_git_repo" != true ]; then
    return 0
  fi

  local staged_plaintext
  staged_plaintext="$(
    git diff --cached --name-only --diff-filter=ACMR |
      grep -E '^iots/tofu/terraform\.tfstate(\.backup)?$|^tofu/terraform\.tfstate(\.backup)?$' || true
  )"

  if [ -n "$staged_plaintext" ]; then
    printf 'Refusing to commit plaintext OpenTofu state:\n%s\n' "$staged_plaintext" >&2
    printf 'Keep plaintext state local and commit only tofu/terraform.tfstate.sops.json.\n' >&2
    exit 1
  fi
}

verify_encrypted_state_matches_plaintext() {
  local plaintext_json="$tmp_dir/plaintext.json"
  local decrypted_json="$tmp_dir/decrypted.json"

  jq -S . "$state" > "$plaintext_json"
  sops --decrypt \
    --input-type json \
    --output-type json \
    "$encrypted_state" |
    jq -S . > "$decrypted_json"

  if ! cmp -s "$plaintext_json" "$decrypted_json"; then
    printf 'Encrypted OpenTofu state does not decrypt back to the current plaintext state.\n' >&2
    exit 1
  fi
}

if [ -f "$state" ]; then
  jq -e . "$state" >/dev/null

  sops --encrypt \
    --input-type json \
    --output-type json \
    --filename-override "$encrypted_state" \
    --output "$encrypted_state" \
    "$state"

  chmod 600 "$encrypted_state"
  verify_encrypted_state_matches_plaintext

  if [ "$is_git_repo" = true ]; then
    git add "$encrypted_state"
  fi
elif [ -f "$encrypted_state" ]; then
  sops --decrypt \
    --input-type json \
    --output-type json \
    "$encrypted_state" |
    jq -e . >/dev/null
fi

fail_if_plaintext_state_is_staged

