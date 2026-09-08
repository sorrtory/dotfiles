#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SUBJECT="$REPO_ROOT/scripts/repo/check-bootstrap-phases.sh"
CHECK_TEST_ROOT="$(mktemp -d)"
readonly CHECK_TEST_ROOT
trap 'rm -rf -- "$CHECK_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

write_phase() {
  local path="$1"

  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common/phase.sh"
check() { return 1; }
install() { phase_info 'installed'; }
is_uninstalled() { return 1; }
uninstall() { phase_info 'uninstalled'; }
phase_main "$@"
EOF
  chmod +x "$path"
}

assert_rejected() {
  local test_repo="$1"
  local description="$2"

  if "$test_repo/scripts/repo/check-bootstrap-phases.sh" >/dev/null 2>&1; then
    fail "$description should be rejected"
  fi
}

test_repo="$CHECK_TEST_ROOT/repo"
mkdir -p "$test_repo/scripts/bootstrap/common" "$test_repo/scripts/repo"
cp "$SUBJECT" "$test_repo/scripts/repo/check-bootstrap-phases.sh"
cp "$REPO_ROOT/scripts/bootstrap/common/"*.sh "$test_repo/scripts/bootstrap/common/"
git -C "$test_repo" init --quiet

write_phase "$test_repo/scripts/bootstrap/01-valid.sh"
"$test_repo/scripts/repo/check-bootstrap-phases.sh" ||
  fail 'a valid numbered phase should be accepted'

write_phase "$test_repo/scripts/bootstrap/invalid.sh"
assert_rejected "$test_repo" 'an unnumbered phase'
rm "$test_repo/scripts/bootstrap/invalid.sh"

write_phase "$test_repo/scripts/bootstrap/02-valid.sh"
assert_rejected "$test_repo" 'duplicate logical phase names'
rm "$test_repo/scripts/bootstrap/02-valid.sh"

write_phase "$test_repo/scripts/bootstrap/03-gap.sh"
assert_rejected "$test_repo" 'a gap in phase numbering'
rm "$test_repo/scripts/bootstrap/03-gap.sh"

write_phase "$test_repo/scripts/bootstrap/02-broken.sh"
sed -i 's/^check()/probe()/' "$test_repo/scripts/bootstrap/02-broken.sh"
assert_rejected "$test_repo" 'a phase without check()'
rm "$test_repo/scripts/bootstrap/02-broken.sh"

write_phase "$test_repo/scripts/bootstrap/02-broken.sh"
sed -i '/^set -euo pipefail$/d' "$test_repo/scripts/bootstrap/02-broken.sh"
assert_rejected "$test_repo" 'a phase without strict mode'
rm "$test_repo/scripts/bootstrap/02-broken.sh"

write_phase "$test_repo/scripts/bootstrap/02-broken.sh"
printf 'if broken\n' >>"$test_repo/scripts/bootstrap/02-broken.sh"
assert_rejected "$test_repo" 'invalid shell syntax'
rm "$test_repo/scripts/bootstrap/02-broken.sh"

write_phase "$test_repo/scripts/bootstrap/02-broken.sh"
printf 'phase_info "runs too late"\n' >>"$test_repo/scripts/bootstrap/02-broken.sh"
assert_rejected "$test_repo" 'statements after the phase entrypoint'
rm "$test_repo/scripts/bootstrap/02-broken.sh"

write_phase "$test_repo/scripts/bootstrap/02-broken.sh"
sed -i 's#^source .*#\# common/phase.sh#' "$test_repo/scripts/bootstrap/02-broken.sh"
assert_rejected "$test_repo" 'a comment in place of the common phase source'
rm "$test_repo/scripts/bootstrap/02-broken.sh"

git -C "$test_repo" add scripts
printf 'broken working tree\n' >"$test_repo/scripts/bootstrap/01-valid.sh"
"$test_repo/scripts/repo/check-bootstrap-phases.sh" --staged ||
  fail 'staged validation should read the valid index version'

git -C "$test_repo" add scripts/bootstrap/01-valid.sh
write_phase "$test_repo/scripts/bootstrap/01-valid.sh"
if "$test_repo/scripts/repo/check-bootstrap-phases.sh" --staged >/dev/null 2>&1; then
  fail 'staged validation should reject an invalid index version'
fi

printf 'bootstrap phase check tests passed\n'
