#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SUBJECT="$REPO_ROOT/scripts/bootstrap.sh"
BOOTSTRAP_TEST_ROOT="$(mktemp -d)"
readonly BOOTSTRAP_TEST_ROOT
trap 'rm -rf -- "$BOOTSTRAP_TEST_ROOT"' EXIT

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

mkdir -p "$BOOTSTRAP_TEST_ROOT/bootstrap/common"
cp "$SUBJECT" "$BOOTSTRAP_TEST_ROOT/bootstrap.sh"
chmod +x "$BOOTSTRAP_TEST_ROOT/bootstrap.sh"

cat >"$BOOTSTRAP_TEST_ROOT/bootstrap/01-beta.sh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
status) printf '[beta] not installed\n'; exit 1 ;;
install)
  printf 'beta\n' >>"$INSTALL_LOG"
  [[ "${FAIL_BETA:-0}" != 1 ]] || exit 1
  printf '[beta] installed\n'
  ;;
*) exit 64 ;;
esac
EOF

cat >"$BOOTSTRAP_TEST_ROOT/bootstrap/02-alpha.sh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
status) printf '[alpha] installed alpha 1.0\n' ;;
install)
  printf 'alpha\n' >>"$INSTALL_LOG"
  printf '[alpha] already satisfied; skipping\n'
  ;;
*) exit 64 ;;
esac
EOF

cat >"$BOOTSTRAP_TEST_ROOT/bootstrap/ignored.sh" <<'EOF'
#!/usr/bin/env bash
printf 'ignored\n'
EOF
chmod +x "$BOOTSTRAP_TEST_ROOT/bootstrap/01-beta.sh" \
  "$BOOTSTRAP_TEST_ROOT/bootstrap/02-alpha.sh" \
  "$BOOTSTRAP_TEST_ROOT/bootstrap/ignored.sh"

if all_status="$("$BOOTSTRAP_TEST_ROOT/bootstrap.sh" status)"; then
  fail 'aggregate status should fail when one phase is unsatisfied'
fi
assert_equal $'[beta] not installed\n[alpha] installed alpha 1.0' \
  "$all_status" \
  'aggregate status should inspect numbered phases in order'

install_log="$BOOTSTRAP_TEST_ROOT/install.log"
output="$(INSTALL_LOG="$install_log" "$BOOTSTRAP_TEST_ROOT/bootstrap.sh" install)"
assert_equal $'[beta] installed\n[alpha] already satisfied; skipping' \
  "$output" \
  'aggregate install should run numbered phases in order'
assert_equal $'beta\nalpha' "$(<"$install_log")" \
  'aggregate install should use filename order'

: >"$install_log"
output="$(INSTALL_LOG="$install_log" "$BOOTSTRAP_TEST_ROOT/bootstrap.sh" install alpha)"
assert_equal '[alpha] already satisfied; skipping' "$output" \
  'logical names should address numbered phases'
assert_equal 'alpha' "$(<"$install_log")" \
  'selected install should run only the selected phase'

if selected_status="$("$BOOTSTRAP_TEST_ROOT/bootstrap.sh" status alpha beta)"; then
  fail 'selected status should fail when one phase is unsatisfied'
fi
assert_equal $'[alpha] installed alpha 1.0\n[beta] not installed' \
  "$selected_status" \
  'status should preserve explicit selection order'

: >"$install_log"
if INSTALL_LOG="$install_log" FAIL_BETA=1 \
  "$BOOTSTRAP_TEST_ROOT/bootstrap.sh" install >/dev/null 2>&1; then
  fail 'aggregate install should propagate phase failures'
fi
assert_equal 'beta' "$(<"$install_log")" \
  'aggregate install should stop before dependent phases'

if "$BOOTSTRAP_TEST_ROOT/bootstrap.sh" status unknown >/dev/null 2>&1; then
  fail 'unknown logical names should be rejected'
fi

if "$BOOTSTRAP_TEST_ROOT/bootstrap.sh" list >/dev/null 2>&1; then
  fail 'list should not be a public command'
fi

printf 'bootstrap interface tests passed\n'
