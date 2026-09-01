#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly COMPONENT_DIR="$SCRIPT_DIR/bootstrap"

usage() {
  cat <<'EOF'
Usage:
  bootstrap.sh list
  bootstrap.sh status [component]
  bootstrap.sh <component>
EOF
}

component_path() {
  local name="$1"
  local path

  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    printf 'Invalid bootstrap component: %s\n' "$name" >&2
    return 1
  fi

  path="$COMPONENT_DIR/$name.sh"
  if [[ ! -x "$path" ]]; then
    printf 'Unknown bootstrap component: %s\n' "$name" >&2
    return 1
  fi

  printf '%s\n' "$path"
}

list_components() {
  local path

  shopt -s nullglob
  for path in "$COMPONENT_DIR"/*.sh; do
    if [[ -x "$path" ]]; then
      basename -- "$path" .sh
    fi
  done
}

component_status() {
  local name="$1"
  local path

  path="$(component_path "$name")" || return
  printf '%s: ' "$name"
  "$path" status
}

all_statuses() {
  local name
  local result=0

  while IFS= read -r name; do
    if ! component_status "$name"; then
      result=1
    fi
  done < <(list_components)

  return "$result"
}

main() {
  local command="${1:-}"

  case "$command" in
    list)
      [[ $# -eq 1 ]] || { usage >&2; return 64; }
      list_components
      ;;
    status)
      if [[ $# -eq 1 ]]; then
        all_statuses
      elif [[ $# -eq 2 ]]; then
        component_status "$2"
      else
        usage >&2
        return 64
      fi
      ;;
    help | --help | -h)
      usage
      ;;
    '')
      usage >&2
      return 64
      ;;
    *)
      [[ $# -eq 1 ]] || { usage >&2; return 64; }
      exec "$(component_path "$command")" apply
      ;;
  esac
}

main "$@"
