#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
cp "$REPO_ROOT/scripts/bootstrap/common/common.sh" "$test_dir/common.sh"

# The fixture must preserve expressions for its own runtime.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"' \
  'check() {' \
  '  if [[ "${INSTALLED:-0}" == 1 ]]; then component_info "installed correctly"; else component_info "not installed"; return 1; fi' \
  '}' \
  'install() {' \
  '  if check >/dev/null; then' \
  '    already_installed' \
  '    return 1' \
  '  fi' \
  '  component_info "installation ran"' \
  '}' \
  'is_uninstalled() {' \
  '  [[ "${INSTALLED:-0}" != 1 && "${PARTIAL:-0}" != 1 ]]' \
  '}' \
  'uninstall() {' \
  '  if is_uninstalled; then' \
  '    already_uninstalled' \
  '    return 1' \
  '  fi' \
  '  component_info "uninstallation ran"' \
  '}' \
  'component_main "$@"' >"$test_dir/component.sh"
chmod +x "$test_dir/component.sh"

output="$(INSTALLED=1 "$test_dir/component.sh" status)"
[[ "$output" == '[component] installed correctly' ]] ||
  fail 'status should identify the component'

if output="$(INSTALLED=1 "$test_dir/component.sh" install 2>"$test_dir/error")"; then
  fail 'install should fail when check is satisfied'
fi
[[ -z "$output" ]] || fail 'install should suppress satisfied check output'
[[ "$(<"$test_dir/error")" == '[component] already installed; refusing to install again.' ]] ||
  fail 'install should identify the component when refusing a repeated install'

output="$(INSTALLED=0 "$test_dir/component.sh" install)"
[[ "$output" == '[component] installation ran' ]] || fail 'install should run when check is unsatisfied'

if output="$(INSTALLED=0 "$test_dir/component.sh" uninstall 2>"$test_dir/error")"; then
  fail 'uninstall should fail when check is unsatisfied'
fi
[[ -z "$output" ]] || fail 'uninstall should suppress unsatisfied check output'
[[ "$(<"$test_dir/error")" == '[component] not installed; refusing to uninstall again.' ]] ||
  fail 'uninstall should identify the component when refusing a repeated uninstall'

output="$(INSTALLED=1 "$test_dir/component.sh" uninstall)"
[[ "$output" == '[component] uninstallation ran' ]] ||
  fail 'uninstall should run when check is satisfied'

output="$(INSTALLED=0 PARTIAL=1 "$test_dir/component.sh" uninstall)"
[[ "$output" == '[component] uninstallation ran' ]] ||
  fail 'uninstall should run when partial component state exists'

if "$test_dir/component.sh" install extra >/dev/null 2>&1; then
  fail 'component should reject extra arguments'
fi

printf 'bootstrap common tests passed\n'
