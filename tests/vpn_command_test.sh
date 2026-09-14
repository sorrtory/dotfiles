#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir "$test_root/bin"
cat > "$test_root/systemd-run" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$VPN_TEST_ROOT/args"
printf '%s\n' "$VPN_USER_PATH" > "$VPN_TEST_ROOT/user-path"
EOF
chmod +x "$test_root/systemd-run"
# A multicall-style symlink: the invoked path must survive, not its target.
ln -s "$(type -P true)" "$test_root/bin/multicall-name"

user_path="$test_root/bin:$PATH"
vpn() {
  VPN_TEST_ROOT=$test_root VPN_ENTER=/helper/vpn-enter \
    VPN_SYSTEMD_RUN=$test_root/systemd-run PATH=$user_path \
    bash "$repo/scripts/bin/vpn.sh" "$@"
}

vpn multicall-name first 'second argument'
mapfile -t args < "$test_root/args"
[[ ${args[*]: -4:1} == /helper/vpn-enter ]] || fail 'helper is not the scope payload'
[[ ${args[-3]} == "$test_root/bin/multicall-name" ]] || fail 'target was canonicalized or not resolved on PATH'
[[ ${args[-2]} == first && ${args[-1]} == 'second argument' ]] || fail 'arguments not preserved'
printf '%s\n' "${args[@]}" | grep -qx -- '--property=BindsTo=vpn-capture.service' ||
  fail 'scope is not bound to capture'
printf '%s\n' "${args[@]}" | grep -qx -- '--job-mode=replace' ||
  fail 'a relaunch would fail against the queued capture stop'
[[ $(<"$test_root/user-path") == "$user_path" ]] || fail 'caller PATH not handed to the helper'

vpn -- multicall-name || fail 'rejected -- separator'
vpn --help | grep -q '^Usage: vpn' || fail 'help missing'
if vpn 2>/dev/null; then fail 'accepted no program'; fi
if vpn -- 2>/dev/null; then fail 'accepted an empty separator'; fi
if vpn no-such-program-for-vpn-test 2>/dev/null; then fail 'accepted a missing program'; fi
if vpn echo 2>/dev/null; then fail 'accepted a shell builtin'; fi
echo 'PASS: vpn command resolution and scope handoff'
