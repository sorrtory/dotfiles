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
cp "$REPO_ROOT/scripts/bootstrap/common.sh" "$test_dir/common.sh"

# The fixture must preserve expressions for its own runtime.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"' \
  'status() {' \
  '  if [[ "${INSTALLED:-0}" == 1 ]]; then printf "installed correctly\\n"; else printf "not installed\\n"; return 1; fi' \
  '}' \
  'install() { printf "installation ran\\n"; }' \
  'component_main Test "$@"' >"$test_dir/component.sh"
chmod +x "$test_dir/component.sh"

if output="$(INSTALLED=1 "$test_dir/component.sh" install 2>/dev/null)"; then
  fail 'install should fail when status is satisfied'
fi
[[ "$output" == 'installed correctly' ]] || fail 'install should run status first'

output="$(INSTALLED=0 "$test_dir/component.sh" install)"
[[ "$output" == $'not installed\ninstallation ran' ]] || fail 'install should run when status is unsatisfied'

if "$test_dir/component.sh" install extra >/dev/null 2>&1; then
  fail 'component should reject extra arguments'
fi

printf 'bootstrap common tests passed\n'
