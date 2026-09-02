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
  '  install) printf "installed alpha\\n" ;;' \
  '  *) exit 64 ;;' \
  'esac' >"$test_dir/bootstrap/alpha.sh"

# The quoted fixture must preserve its own positional parameter expression.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "${1:-}" in' \
  '  status) printf "not installed\\n"; exit 1 ;;' \
  '  install) [[ "${FAIL_BETA:-0}" != 1 ]] || exit 1; printf "installed beta\\n" ;;' \
  '  *) exit 64 ;;' \
  'esac' >"$test_dir/bootstrap/beta.sh"

printf '#!/usr/bin/env bash\n' >"$test_dir/bootstrap/ignored.sh"
chmod +x "$test_dir/bootstrap/alpha.sh" "$test_dir/bootstrap/beta.sh"

if all_status="$("$test_dir/bootstrap.sh" status)"; then
  fail 'aggregate status should fail when one component is unsatisfied'
fi
assert_equal $'alpha: installed alpha 1.0\nbeta: not installed' \
  "$all_status" \
  'aggregate status should report every component'

assert_equal $'installed alpha\ninstalled beta' \
  "$("$test_dir/bootstrap.sh" install)" \
  'install should delegate to every component'

assert_equal 'installed beta' \
  "$("$test_dir/bootstrap.sh" install beta)" \
  'install should accept selected components'

if selected_status="$("$test_dir/bootstrap.sh" status beta alpha)"; then
  fail 'selected status should fail when one component is unsatisfied'
fi
assert_equal $'beta: not installed\nalpha: installed alpha 1.0' \
  "$selected_status" \
  'status should preserve component selection order'

if FAIL_BETA=1 "$test_dir/bootstrap.sh" install >/dev/null 2>&1; then
  fail 'install should propagate component failures'
fi

if "$test_dir/bootstrap.sh" list >/dev/null 2>&1; then
  fail 'list should not be a public command'
fi

if "$test_dir/bootstrap.sh" status unknown >/dev/null 2>&1; then
  fail 'unknown components should be rejected'
fi

printf 'bootstrap interface tests passed\n'
