#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
readonly REPO_ROOT

# Everything committed here must already be public-safe; see docs/DECISIONS.md,
# "Secrets and authentication".
readonly SECRETS_DIR='secrets'

# The only files under secrets/ allowed to be plaintext, because they carry no
# secret material. Explicit rather than a pattern: a pattern is what eventually
# lets an unintended file through.
readonly -a SECRETS_PLAINTEXT_ALLOWLIST=(
  "$SECRETS_DIR/.gitkeep"
  "$SECRETS_DIR/README.md"
)

SOPS_COMMAND=''

usage() {
  printf 'Usage: %s --staged\n' "$0"
}

# Let SOPS itself answer whether a file is encrypted. Matching marker strings
# instead would accept plaintext that merely carries them in a comment, which
# is exactly the material this check exists to reject.
staged_is_sops_ciphertext() {
  local path="$1"
  local candidate status workdir

  workdir="$(mktemp -d)" || return 1
  # Keep the basename so SOPS can use the extension to pick an input type, and
  # write the blob to a file rather than a variable so binary content survives.
  candidate="$workdir/$(basename -- "$path")"

  status=1
  if git -C "$REPO_ROOT" show ":$path" >"$candidate" 2>/dev/null &&
    [[ "$("$SOPS_COMMAND" filestatus "$candidate" 2>/dev/null)" == *'"encrypted":true'* ]]; then
    status=0
  fi

  rm -rf -- "$workdir"
  return "$status"
}

is_allowlisted() {
  local path="$1" allowed

  for allowed in "${SECRETS_PLAINTEXT_ALLOWLIST[@]}"; do
    if [[ "$path" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

# Inverted relative to the rest of the scan: elsewhere a file is rejected when
# it looks like a secret, but under secrets/ it is rejected unless it is
# positively recognized as ciphertext. Plaintext in a format no rule matches is
# the case this exists to catch.
check_secrets_are_ciphertext() {
  local path
  local status=0

  while IFS= read -r -d '' path; do
    case "$path" in
    "$SECRETS_DIR"/*) ;;
    *) continue ;;
    esac
    if is_allowlisted "$path"; then
      continue
    fi
    if staged_is_sops_ciphertext "$path"; then
      continue
    fi

    printf '%s is staged under %s/ but is not SOPS ciphertext.\n' \
      "$path" "$SECRETS_DIR" >&2
    status=1
  done < <(git -C "$REPO_ROOT" diff --cached -z --name-only --diff-filter=d)

  if [[ "$status" -ne 0 ]]; then
    printf '\nEncrypt it before committing:\n\n    sops --encrypt --in-place <file>\n\n' >&2
    printf 'Plaintext under %s/ is permitted only for: %s\n' \
      "$SECRETS_DIR" "${SECRETS_PLAINTEXT_ALLOWLIST[*]}" >&2
  fi

  return "$status"
}

if [[ "${1:-}" != --staged || $# -ne 1 ]]; then
  usage >&2
  exit 64
fi

if ! command -v nix >/dev/null 2>&1; then
  printf 'Secret scan requires Nix.\n' >&2
  exit 69
fi

# Resolve the pinned SOPS once; entering the development shell per file would
# dominate the cost of the scan.
SOPS_COMMAND="$(nix develop "$REPO_ROOT" --command bash -c 'command -v sops')"
readonly SOPS_COMMAND

check_secrets_are_ciphertext

exec nix develop "$REPO_ROOT" --command \
  gitleaks protect \
  --staged \
  --redact \
  --config "$REPO_ROOT/.gitleaks.toml" \
  --source "$REPO_ROOT"
