#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly COMPONENT_DIR="$SCRIPT_DIR/bootstrap"
# shellcheck disable=SC1091
. "$COMPONENT_DIR/common/common.sh"

usage() {
  cat <<'EOF'
Runs all components in bootstrap/ by default, or only the named components.

Usage:
  bootstrap.sh status [component ...]
  bootstrap.sh install [component ...]
  bootstrap.sh uninstall component [component ...]
EOF
}

component_path() {
  local name="$1"
  local path="$COMPONENT_DIR/$name.sh"

  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ || ! -x "$path" ]]; then
    component_error "unknown component: $name"
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
  uninstall)
    shift
    if [[ $# -eq 0 ]]; then
      component_error 'uninstall requires at least one component'
      usage >&2
      return 64
    fi
    run "$command" "$@"
    ;;
  help | --help | -h)
    usage
    ;;
  '')
    component_error 'command is required'
    usage >&2
    return 64
    ;;
  *)
    component_error "unknown command: $command"
    usage >&2
    return 64
    ;;
  esac
}

main "$@"
