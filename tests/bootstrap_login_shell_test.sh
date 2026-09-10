#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
LOGIN_SHELL_TEST_ROOT="$(mktemp -d)"
readonly LOGIN_SHELL_TEST_ROOT
trap 'rm -rf -- "$LOGIN_SHELL_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$LOGIN_SHELL_TEST_ROOT/bootstrap/common" \
  "$LOGIN_SHELL_TEST_ROOT/bin"
cp "$REPO_ROOT/scripts/bootstrap/07-login-shell.sh" \
  "$LOGIN_SHELL_TEST_ROOT/bootstrap/07-login-shell.sh"
cp "$REPO_ROOT/scripts/bootstrap/common/"*.sh \
  "$LOGIN_SHELL_TEST_ROOT/bootstrap/common/"

cat >"$LOGIN_SHELL_TEST_ROOT/bin/id" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == -un ]] && printf 'test-user\n'
EOF

cat >"$LOGIN_SHELL_TEST_ROOT/bin/getent" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == passwd && "$2" == test-user ]] || exit 1
printf 'test-user:x:1000:1000::/home/test-user:%s\n' "$(<"$LOGIN_SHELL_STATE")"
EOF

cat >"$LOGIN_SHELL_TEST_ROOT/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$LOGIN_SHELL_LOG"
[[ "$1" == usermod && "$2" == --shell && "$4" == test-user ]] || exit 64
printf '%s\n' "$3" >"$LOGIN_SHELL_STATE"
EOF

ln -s /usr/bin/dirname "$LOGIN_SHELL_TEST_ROOT/bin/dirname"
ln -s /usr/bin/readlink "$LOGIN_SHELL_TEST_ROOT/bin/readlink"
printf '#!/bin/sh\nexit 0\n' >"$LOGIN_SHELL_TEST_ROOT/bin/zsh"
chmod +x "$LOGIN_SHELL_TEST_ROOT/bootstrap/07-login-shell.sh" \
  "$LOGIN_SHELL_TEST_ROOT/bin/id" \
  "$LOGIN_SHELL_TEST_ROOT/bin/getent" \
  "$LOGIN_SHELL_TEST_ROOT/bin/sudo" \
  "$LOGIN_SHELL_TEST_ROOT/bin/zsh"

state="$LOGIN_SHELL_TEST_ROOT/login-shell"
log="$LOGIN_SHELL_TEST_ROOT/sudo.log"
printf '/bin/bash\n' >"$state"
: >"$log"

run_phase() {
  PATH="$LOGIN_SHELL_TEST_ROOT/bin:/usr/bin:/bin" \
    LOGIN_SHELL_STATE="$state" \
    LOGIN_SHELL_LOG="$log" \
    BOOTSTRAP_HOST_BASH_PATH=/bin/bash \
    BOOTSTRAP_HOST_ZSH_PATH="$LOGIN_SHELL_TEST_ROOT/bin/zsh" \
    "$LOGIN_SHELL_TEST_ROOT/bootstrap/07-login-shell.sh" "$@"
}

if output="$(run_phase status)"; then
  fail 'status should report a different login shell'
fi
[[ "$output" == "[login-shell] login shell is /bin/bash, not $LOGIN_SHELL_TEST_ROOT/bin/zsh" ]] ||
  fail 'status should describe the current and selected shells'

output="$(run_phase install)"
[[ "$output" == *'[login-shell] the login-shell change applies after the next login'* ]] ||
  fail 'install should explain when the shell change applies'
[[ "$(<"$state")" == "$LOGIN_SHELL_TEST_ROOT/bin/zsh" ]] ||
  fail 'install should set the selected host Zsh path'
[[ "$(<"$log")" == "usermod --shell $LOGIN_SHELL_TEST_ROOT/bin/zsh test-user" ]] ||
  fail 'install should change only the target user login shell'

output="$(run_phase install)"
[[ "$output" == '[login-shell] already satisfied; skipping' ]] ||
  fail 'install should be idempotent'

: >"$log"
output="$(run_phase uninstall)"
[[ "$output" == *'[login-shell] the login-shell change applies after the next login'* ]] ||
  fail 'uninstall should explain when the shell change applies'
[[ "$(<"$state")" == /bin/bash ]] ||
  fail 'uninstall should restore the selected host Bash path'
[[ "$(<"$log")" == 'usermod --shell /bin/bash test-user' ]] ||
  fail 'uninstall should change only the target user login shell'

if output="$(run_phase uninstall 2>&1)"; then
  fail 'uninstall should refuse to repeat after Bash is restored'
fi
[[ "$output" == '[login-shell] not installed; refusing to uninstall again.' ]] ||
  fail 'repeated uninstall should be rejected clearly'

printf 'bootstrap login-shell tests passed\n'
