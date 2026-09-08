#!/usr/bin/env bash

phase_name() {
  local name

  name="$(basename -- "$0" .sh)"
  if [[ "$name" =~ ^[0-9]{2}-(.+)$ ]]; then
    name="${BASH_REMATCH[1]}"
  fi
  printf '%s\n' "$name"
}

phase_info() {
  printf '[%s] %s\n' "$(phase_name)" "$1"
}

phase_error() {
  printf '[%s] %s\n' "$(phase_name)" "$1" >&2
}
