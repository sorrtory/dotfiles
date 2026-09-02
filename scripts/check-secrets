#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
readonly REPO_ROOT

usage() {
  printf 'Usage: %s --staged\n' "$0"
}

if [[ "${1:-}" != --staged || $# -ne 1 ]]; then
  usage >&2
  exit 64
fi

if ! command -v nix >/dev/null 2>&1; then
  printf 'Secret scan requires Nix.\n' >&2
  exit 69
fi

exec nix develop "$REPO_ROOT" --command \
  gitleaks protect \
  --staged \
  --redact \
  --config "$REPO_ROOT/.gitleaks.toml" \
  --source "$REPO_ROOT"
