#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly COMPONENT_DIR="$SCRIPT_DIR/bootstrap"

usage() {
  cat <<'EOF'
Runs all components in bootstrap/ by default, or only the named components.

Usage:
  bootstrap.sh status [component ...]
  bootstrap.sh install [component ...]
EOF
}

component_path() {
  local name="$1"
  local path="$COMPONENT_DIR/$name.sh"

  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ || ! -x "$path" ]]; then
    printf 'Unknown bootstrap component: %s\n' "$name" >&2
    return 1
  fi

  printf '%s\n' "$path"
}

components() {
  local path

  shopt -s nullglob
  for path in "$COMPONENT_DIR"/*.sh; do
    if [[ -x "$path" ]]; then
      printf '%s\n' "$path"
    fi
  done
}

run() {
  local command="$1"
  local name path
  local -a paths=()
  local result=0
  shift

  if [[ $# -eq 0 ]]; then
    mapfile -t paths < <(components)
  else
    for name in "$@"; do
      path="$(component_path "$name")" || return
      paths+=("$path")
    done
  fi

  for path in "${paths[@]}"; do
    if [[ "$command" == status ]]; then
      printf '%s: ' "$(basename -- "$path" .sh)"
    fi
    if ! "$path" "$command"; then
      result=1
    fi
  done

  return "$result"
}

main() {
  local command="${1:-}"

  case "$command" in
  status | install)
    shift
    run "$command" "$@"
    ;;
  help | --help | -h)
    usage
    ;;
  '')
    usage >&2
    return 64
    ;;
  *)
    usage >&2
    return 64
    ;;
  esac
}

main "$@"
