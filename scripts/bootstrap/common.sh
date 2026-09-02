#!/usr/bin/env bash

require_commands() {
  local command_name

  for command_name in "$@"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      printf 'Required command is missing: %s\n' "$command_name" >&2
      return 1
    fi
  done
}

component_main() {
  local component_name="$1"
  local command="${2:-}"

  if [[ $# -ne 2 ]]; then
    printf 'Usage: %s {status|install}\n' "$0" >&2
    return 64
  fi

  case "$command" in
  status)
    status
    ;;
  install)
    if status; then
      printf '%s is already installed correctly.\n' "$component_name" >&2
      return 1
    fi
    install
    ;;
  *)
    printf 'Usage: %s {status|install}\n' "$0" >&2
    return 64
    ;;
  esac
}
