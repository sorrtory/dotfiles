#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
BOOTSTRAP_COMMON_TEST_ROOT="$(mktemp -d)"
readonly BOOTSTRAP_COMMON_TEST_ROOT
trap 'rm -rf -- "$BOOTSTRAP_COMMON_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$BOOTSTRAP_COMMON_TEST_ROOT/common"
cp "$REPO_ROOT/scripts/bootstrap/common/"*.sh \
  "$BOOTSTRAP_COMMON_TEST_ROOT/common/"

cat >"$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common/phase.sh"

check() {
  if [[ "${CHECK_ERROR:-0}" != 0 ]]; then
    phase_error 'status check failed'
    return "$CHECK_ERROR"
  fi
  if [[ -e "$STATE_FILE" ]]; then
    phase_info 'installed correctly'
  else
    phase_info 'not installed'
    return 1
  fi
}

install() {
  phase_info 'installation ran'
  if [[ "${INSTALL_ERROR:-0}" != 0 ]]; then
    return "$INSTALL_ERROR"
  fi
  [[ "${NO_STATE:-0}" == 1 ]] || touch "$STATE_FILE"
}

is_uninstalled() {
  [[ ! -e "$STATE_FILE" ]]
}

uninstall() {
  phase_info 'uninstallation ran'
  if [[ "${UNINSTALL_ERROR:-0}" != 0 ]]; then
    return "$UNINSTALL_ERROR"
  fi
  rm -f "$STATE_FILE"
}

phase_main "$@"
EOF
chmod +x "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh"

state_file="$BOOTSTRAP_COMMON_TEST_ROOT/state"

if output="$(STATE_FILE="$state_file" "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" status)"; then
  fail 'status should fail when the state is unsatisfied'
fi
[[ "$output" == '[test] not installed' ]] ||
  fail 'status should identify an unsatisfied phase'

output="$(STATE_FILE="$state_file" "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" install)"
[[ "$output" == $'[test] installation ran\n[test] installed correctly' ]] ||
  fail 'install should verify the resulting state'

output="$(STATE_FILE="$state_file" "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" install)"
[[ "$output" == '[test] already satisfied; skipping' ]] ||
  fail 'install should successfully skip satisfied state'

rm "$state_file"
if STATE_FILE="$state_file" CHECK_ERROR=70 \
  "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" install >/dev/null 2>&1; then
  fail 'install should stop when the status check errors'
else
  result=$?
fi
[[ "$result" == 70 ]] || fail 'install should preserve status error codes'
[[ ! -e "$state_file" ]] || fail 'install should not run after a status error'

if STATE_FILE="$state_file" INSTALL_ERROR=71 \
  "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" install >/dev/null 2>&1; then
  fail 'install should propagate mutation failures'
else
  result=$?
fi
[[ "$result" == 71 ]] || fail 'install should preserve mutation error codes'
[[ ! -e "$state_file" ]] || fail 'install should stop after a mutation failure'

if STATE_FILE="$state_file" NO_STATE=1 \
  "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" install >/dev/null 2>&1; then
  fail 'install should fail when its postcondition remains unsatisfied'
fi

if STATE_FILE="$state_file" \
  "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" install extra >/dev/null 2>&1; then
  fail 'a phase should reject extra arguments'
fi

touch "$state_file"
output="$(STATE_FILE="$state_file" "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" uninstall)"
[[ "$output" == '[test] uninstallation ran' ]] ||
  fail 'uninstall should verify that owned state was removed'

if STATE_FILE="$state_file" \
  "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" uninstall >/dev/null 2>&1; then
  fail 'uninstall should refuse when no owned state remains'
fi

touch "$state_file"
if STATE_FILE="$state_file" UNINSTALL_ERROR=72 \
  "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" uninstall >/dev/null 2>&1; then
  fail 'uninstall should propagate mutation failures'
else
  result=$?
fi
[[ "$result" == 72 ]] || fail 'uninstall should preserve mutation error codes'
[[ -e "$state_file" ]] || fail 'uninstall should stop after a mutation failure'

cp "$BOOTSTRAP_COMMON_TEST_ROOT/01-test.sh" "$BOOTSTRAP_COMMON_TEST_ROOT/02-loose.sh"
sed -i '/^set -euo pipefail$/d' "$BOOTSTRAP_COMMON_TEST_ROOT/02-loose.sh"
if STATE_FILE="$state_file" \
  "$BOOTSTRAP_COMMON_TEST_ROOT/02-loose.sh" status >/dev/null 2>&1; then
  fail 'a phase without strict mode should be rejected at runtime'
else
  result=$?
fi
[[ "$result" == 70 ]] || fail 'a strict-mode contract error should exit 70'

printf 'bootstrap common tests passed\n'
