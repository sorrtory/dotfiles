#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly PHASE_DIR="$SCRIPT_DIR/bootstrap"

bootstrap_error() {
  printf '[bootstrap] %s\n' "$1" >&2
}

usage() {
  cat <<'EOF'
Checks or installs every numbered bootstrap phase by default.

Usage:
  bootstrap.sh status [phase ...]
  bootstrap.sh install [phase ...]
  bootstrap.sh uninstall phase [phase ...]
EOF
}

phase_path() {
  local name="$1"
  local -a matches=()

  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    bootstrap_error "unknown phase: $name"
    return 1
  fi

  shopt -s nullglob
  matches=("$PHASE_DIR"/[0-9][0-9]-"$name".sh)
  shopt -u nullglob
  if [[ ${#matches[@]} -ne 1 || ! -x "${matches[0]}" ]]; then
    bootstrap_error "unknown phase: $name"
    return 1
  fi

  printf '%s\n' "${matches[0]}"
}

phases() {
  local path

  shopt -s nullglob
  for path in "$PHASE_DIR"/[0-9][0-9]-*.sh; do
    [[ -x "$path" ]] && printf '%s\n' "$path"
  done
  shopt -u nullglob
}

resolve_phases() {
  local name path
  RESOLVED_PHASES=()

  if [[ $# -eq 0 ]]; then
    mapfile -t RESOLVED_PHASES < <(phases)
    return
  fi

  for name in "$@"; do
    path="$(phase_path "$name")" || return
    RESOLVED_PHASES+=("$path")
  done
}

run_status() {
  local path phase_result
  local result=0

  for path in "$@"; do
    if "$path" status; then
      phase_result=0
    else
      phase_result=$?
    fi

    if [[ $phase_result -ge 2 ]]; then
      result=$phase_result
    elif [[ $phase_result -eq 1 && $result -eq 0 ]]; then
      result=1
    fi
  done

  return "$result"
}

run_ordered() {
  local command="$1"
  local path phase_result
  shift

  for path in "$@"; do
    if "$path" "$command"; then
      continue
    else
      phase_result=$?
    fi
    return "$phase_result"
  done
}

main() {
  local command="${1:-}"
  local -a RESOLVED_PHASES=()

  case "$command" in
  status | install)
    shift
    resolve_phases "$@" || return
    if [[ "$command" == status ]]; then
      run_status "${RESOLVED_PHASES[@]}"
    else
      run_ordered install "${RESOLVED_PHASES[@]}"
    fi
    ;;
  uninstall)
    shift
    if [[ $# -eq 0 ]]; then
      bootstrap_error 'uninstall requires at least one phase'
      usage >&2
      return 64
    fi
    resolve_phases "$@" || return
    run_ordered uninstall "${RESOLVED_PHASES[@]}"
    ;;
  help | --help | -h)
    usage
    ;;
  '')
    bootstrap_error 'command is required'
    usage >&2
    return 64
    ;;
  *)
    bootstrap_error "unknown command: $command"
    usage >&2
    return 64
    ;;
  esac
}

main "$@"
