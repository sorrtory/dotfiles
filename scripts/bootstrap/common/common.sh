#!/usr/bin/env bash

component_name() {
  basename -- "$0" .sh
}

component_info() {
  printf '[%s] %s\n' "$(component_name)" "$1"
}

component_error() {
  printf '[%s] %s\n' "$(component_name)" "$1" >&2
}

already_installed() {
  component_error 'already installed; refusing to install again.'
}

already_uninstalled() {
  component_error 'not installed; refusing to uninstall again.'
}

require_commands() {
  local command_name

  for command_name in "$@"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      component_error "required command is missing: $command_name"
      return 1
    fi
  done
}

component_main() {
  local command="${1:-}"

  if [[ $# -ne 1 ]]; then
    component_error 'usage: {status|install|uninstall}'
    return 64
  fi

  case "$command" in
  status)
    check
    ;;
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  *)
    component_error 'usage: {status|install|uninstall}'
    return 64
    ;;
  esac
}
