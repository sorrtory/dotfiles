#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SUBJECT="$REPO_ROOT/scripts/bootstrap.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_equal() {
  local expected="$1"
  local actual="$2"

  if [[ "$actual" != "$expected" ]]; then
    printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    fail "$3"
  fi
}

test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bootstrap"
cp "$SUBJECT" "$test_dir/bootstrap.sh"
chmod +x "$test_dir/bootstrap.sh"

# The quoted fixture must preserve its own positional parameter expression.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "${1:-}" in' \
  '  status) printf "installed alpha 1.0\\n" ;;' \
  '  apply) printf "applied alpha\\n" ;;' \
  '  *) exit 64 ;;' \
  'esac' >"$test_dir/bootstrap/alpha.sh"

# The quoted fixture must preserve its own positional parameter expression.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "${1:-}" in' \
  '  status) printf "not installed\\n"; exit 1 ;;' \
  '  apply) printf "applied beta\\n" ;;' \
  '  *) exit 64 ;;' \
  'esac' >"$test_dir/bootstrap/beta.sh"

printf '#!/usr/bin/env bash\n' >"$test_dir/bootstrap/ignored.sh"
chmod +x "$test_dir/bootstrap/alpha.sh" "$test_dir/bootstrap/beta.sh"

assert_equal $'alpha\nbeta' \
  "$("$test_dir/bootstrap.sh" list)" \
  'list should discover executable components'

assert_equal 'alpha: installed alpha 1.0' \
  "$("$test_dir/bootstrap.sh" status alpha)" \
  'status should delegate to one component'

if all_status="$("$test_dir/bootstrap.sh" status)"; then
  fail 'aggregate status should fail when one component is unsatisfied'
fi
assert_equal $'alpha: installed alpha 1.0\nbeta: not installed' \
  "$all_status" \
  'aggregate status should report every component'

assert_equal 'applied alpha' \
  "$("$test_dir/bootstrap.sh" alpha)" \
  'component command should invoke apply'

if "$test_dir/bootstrap.sh" unknown >/dev/null 2>&1; then
  fail 'unknown components should be rejected'
fi

printf 'bootstrap interface tests passed\n'
