#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

staged_files="$(
  git diff --cached --name-only --diff-filter=ACMR || true
)"

if [ -z "$staged_files" ]; then
  exit 0
fi

blocked_plaintext="$(
  printf '%s\n' "$staged_files" |
    grep -E \
      '(^|/)talos/secrets\.ya?ml$|(^|/)talos/talosconfig$|(^|/)talos/generated/|(^|/)kubeconfig/.*\.ya?ml$|(^|/)tofu/terraform\.tfstate(\.backup)?$|(^|/)\.env(\..*)?$|(^|/)[^/]*secret[^/]*\.ya?ml$|(^|/)[^/]*credentials?[^/]*\.(json|ya?ml|toml|env)$|(^|/).*\.(pem|key)$|(^|/)id_(rsa|ed25519|ecdsa)$' |
    grep -Ev '(^|/)[^/]*\.sops\.(ya?ml|json)$|^tofu/terraform\.tfstate\.sops\.json$' ||
    true
)"

if [ -n "$blocked_plaintext" ]; then
  printf 'Refusing to commit plaintext secret/state files:\n%s\n' "$blocked_plaintext" >&2
  printf 'Commit SOPS-encrypted files instead, for example talos/secrets.sops.yaml or tofu/terraform.tfstate.sops.json.\n' >&2
  exit 1
fi

verify_sops_file() {
  local path="$1"
  local staged_copy="$tmp_dir/${path//\//__}"

  git show ":$path" > "$staged_copy"

  if ! sops filestatus "$staged_copy" | jq -e '.encrypted == true' >/dev/null; then
    printf 'Expected SOPS-encrypted file, but staged content is not encrypted: %s\n' "$path" >&2
    exit 1
  fi
}

while IFS= read -r path; do
  case "$path" in
    .sops.yaml|.sops.yml)
      ;;
    *.sops.yaml|*.sops.yml|*.sops.json|tofu/terraform.tfstate.sops.json)
      verify_sops_file "$path"
      ;;
  esac
done <<< "$staged_files"
