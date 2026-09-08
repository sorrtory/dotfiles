#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SUBJECT="$REPO_ROOT/scripts/repo/check-bootstrap-components.sh"
readonly COMMON_SUBJECT="$REPO_ROOT/scripts/bootstrap/common/common.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

write_valid_component() {
  local path="$1"

  # The fixture must preserve expressions for its own runtime.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    '. "$BOOTSTRAP_DIR/common/common.sh"' \
    'check() {' \
    '  return 1' \
    '}' \
    'install() {' \
    '  if check >/dev/null; then' \
    '    already_installed' \
    '    return 1' \
    '  fi' \
    '  component_info "installed"' \
    '}' \
    'is_uninstalled() {' \
    '  return 0' \
    '}' \
    'uninstall() {' \
    '  if is_uninstalled; then' \
    '    already_uninstalled' \
    '    return 1' \
    '  fi' \
    '  component_info "uninstalled"' \
    '}' \
    'component_main "$@"' >"$path"
  chmod +x "$path"
}

assert_rejected() {
  local test_repo="$1"
  local description="$2"

  if "$test_repo/scripts/repo/check-bootstrap-components.sh" >/dev/null 2>&1; then
    fail "$description should be rejected"
  fi
}

test_repo="$(mktemp -d)"
trap 'rm -rf -- "$test_repo"' EXIT
mkdir -p "$test_repo/scripts/bootstrap" "$test_repo/scripts/repo"
cp "$SUBJECT" "$test_repo/scripts/repo/check-bootstrap-components.sh"
git -C "$test_repo" init --quiet

write_valid_component "$test_repo/scripts/bootstrap/valid.sh"
mkdir -p "$test_repo/scripts/bootstrap/common"
cp "$COMMON_SUBJECT" "$test_repo/scripts/bootstrap/common/common.sh"
"$test_repo/scripts/repo/check-bootstrap-components.sh" ||
  fail 'valid components and nested non-executable helpers should be accepted'

cp "$test_repo/scripts/bootstrap/common/common.sh" "$test_repo/common.backup"
sed -i '/^  uninstall)/,/^    ;;/d' \
  "$test_repo/scripts/bootstrap/common/common.sh"
assert_rejected "$test_repo" 'a common interface without uninstall dispatch'
mv "$test_repo/common.backup" "$test_repo/scripts/bootstrap/common/common.sh"

cp "$test_repo/scripts/bootstrap/common/common.sh" "$test_repo/common.backup"
sed -i \
  -e 's/^    check$/    __status_delegate__/' \
  -e 's/^    install$/    check/' \
  -e 's/^    __status_delegate__$/    install/' \
  "$test_repo/scripts/bootstrap/common/common.sh"
assert_rejected "$test_repo" 'a common interface with swapped dispatch targets'
mv "$test_repo/common.backup" "$test_repo/scripts/bootstrap/common/common.sh"

cp "$test_repo/scripts/bootstrap/common/common.sh" "$test_repo/common.backup"
sed -i '/^component_error()/,/^}/ s/ >&2$//' \
  "$test_repo/scripts/bootstrap/common/common.sh"
assert_rejected "$test_repo" 'a common error helper that writes to stdout'
mv "$test_repo/common.backup" "$test_repo/scripts/bootstrap/common/common.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/missing-check.sh"
sed -i 's/^check()/probe()/' "$test_repo/scripts/bootstrap/missing-check.sh"
assert_rejected "$test_repo" 'a component without check()'
rm "$test_repo/scripts/bootstrap/missing-check.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/missing-common.sh"
sed -i '/common\/common.sh/d' "$test_repo/scripts/bootstrap/missing-common.sh"
assert_rejected "$test_repo" 'a component that does not source the common interface'
rm "$test_repo/scripts/bootstrap/missing-common.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/missing-install.sh"
sed -i 's/^install()/setup()/' "$test_repo/scripts/bootstrap/missing-install.sh"
assert_rejected "$test_repo" 'a component without install()'
rm "$test_repo/scripts/bootstrap/missing-install.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/missing-uninstall.sh"
sed -i 's/^uninstall()/remove()/' "$test_repo/scripts/bootstrap/missing-uninstall.sh"
assert_rejected "$test_repo" 'a component without uninstall()'
rm "$test_repo/scripts/bootstrap/missing-uninstall.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/missing-is-uninstalled.sh"
sed -i 's/^is_uninstalled()/installation_absent()/' \
  "$test_repo/scripts/bootstrap/missing-is-uninstalled.sh"
assert_rejected "$test_repo" 'a component without is_uninstalled()'
rm "$test_repo/scripts/bootstrap/missing-is-uninstalled.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/missing-main.sh"
sed -i '/component_main/d' "$test_repo/scripts/bootstrap/missing-main.sh"
assert_rejected "$test_repo" 'a component without the common entrypoint'
rm "$test_repo/scripts/bootstrap/missing-main.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/early-main.sh"
printf 'component_info "too late"\n' >>"$test_repo/scripts/bootstrap/early-main.sh"
assert_rejected "$test_repo" 'a component with code after the common entrypoint'
rm "$test_repo/scripts/bootstrap/early-main.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/unguarded.sh"
sed -i '/if check >\/dev\/null; then/,/fi/d' "$test_repo/scripts/bootstrap/unguarded.sh"
assert_rejected "$test_repo" 'an install() without an immediate check guard'
rm "$test_repo/scripts/bootstrap/unguarded.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/unguarded-uninstall.sh"
sed -i '/if is_uninstalled; then/,/fi/d' "$test_repo/scripts/bootstrap/unguarded-uninstall.sh"
assert_rejected "$test_repo" 'an uninstall() without an immediate check guard'
rm "$test_repo/scripts/bootstrap/unguarded-uninstall.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/direct-output.sh"
sed -i 's/component_info "installed"/printf "installed\\n"/' "$test_repo/scripts/bootstrap/direct-output.sh"
assert_rejected "$test_repo" 'a component using printf directly'
rm "$test_repo/scripts/bootstrap/direct-output.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/hidden-output.sh"
# The replacement must preserve the command substitution in the fixture.
# shellcheck disable=SC2016
sed -i 's/component_info "installed"/message="$(printf installed)"/' \
  "$test_repo/scripts/bootstrap/hidden-output.sh"
if "$test_repo/scripts/repo/check-bootstrap-components.sh" >/dev/null 2>&1; then
  fail 'a component hiding printf in a command substitution should be rejected'
fi
rm "$test_repo/scripts/bootstrap/hidden-output.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/non-executable.sh"
chmod -x "$test_repo/scripts/bootstrap/non-executable.sh"
assert_rejected "$test_repo" 'a non-executable top-level component'
rm "$test_repo/scripts/bootstrap/non-executable.sh"

cp "$test_repo/scripts/bootstrap/valid.sh" "$test_repo/scripts/bootstrap/no-return.sh"
sed -i '/return 1/d' "$test_repo/scripts/bootstrap/no-return.sh"
assert_rejected "$test_repo" 'a check guard that does not stop installation'
rm "$test_repo/scripts/bootstrap/no-return.sh"

git -C "$test_repo" add scripts
printf 'broken working tree\n' >"$test_repo/scripts/bootstrap/valid.sh"
"$test_repo/scripts/repo/check-bootstrap-components.sh" --staged ||
  fail 'staged validation should read the valid index version'

git -C "$test_repo" add scripts/bootstrap/valid.sh
write_valid_component "$test_repo/scripts/bootstrap/valid.sh"
if "$test_repo/scripts/repo/check-bootstrap-components.sh" --staged >/dev/null 2>&1; then
  fail 'staged validation should reject an invalid index version'
fi

printf 'bootstrap component check tests passed\n'
