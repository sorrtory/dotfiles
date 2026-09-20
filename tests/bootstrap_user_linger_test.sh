#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir "$TEST_ROOT/bin"
cat >"$TEST_ROOT/bin/loginctl" <<'EOF'
#!/usr/bin/env bash
set -eu
case "$1" in
  show-user)
    [[ "$2" == "$(id -un)" && "$3" == --property=Linger && "$4" == --value ]] || exit 64
    [[ ! -e "$TEST_ROOT/fail" ]] || exit 1
    cat "$TEST_ROOT/state"
    ;;
  enable-linger)
    [[ "$2" == "$(id -un)" ]] || exit 64
    printf 'yes\n' >"$TEST_ROOT/state"
    printf 'enabled\n' >>"$TEST_ROOT/actions"
    ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/loginctl"
export TEST_ROOT
export PATH="$TEST_ROOT/bin:$PATH"
phase="$REPO_ROOT/scripts/bootstrap/09-user-linger.sh"
printf 'no\n' >"$TEST_ROOT/state"
if bash "$phase" status >/dev/null; then fail 'disabled linger reported satisfied'; fi
[[ ! -e "$TEST_ROOT/actions" ]] || fail 'status changed linger'
bash "$phase" install >/dev/null
bash "$phase" install >/dev/null
[[ $(wc -l <"$TEST_ROOT/actions") == 1 ]] || fail 'install was not idempotent'
bash "$phase" status >/dev/null
if bash "$phase" uninstall >/dev/null 2>&1; then fail 'must not disable shared linger'; fi
touch "$TEST_ROOT/fail"
if bash "$phase" install >/dev/null 2>&1; then fail 'failed probe must prevent mutation'; fi
[[ $(wc -l <"$TEST_ROOT/actions") == 1 ]] || fail 'failed probe changed linger'
printf 'bootstrap user-linger tests passed\n'
