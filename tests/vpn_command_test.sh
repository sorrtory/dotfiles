#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir "$test_root/bin"
mkdir "$test_root/run"
printf '{"names":["route-a","route-b"]}\n' > "$test_root/run/vpn-control.json"
cat > "$test_root/vpn-egress" <<'EOF'
#!/usr/bin/env bash
[[ $1 == resolve ]] || exit 2
case "$2" in
  vesktop) echo named:route-a ;;
  ayugram) echo default ;;
  *) exit 3 ;;
esac
EOF
chmod +x "$test_root/vpn-egress"
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
    VPN_SYSTEMD_RUN=$test_root/systemd-run \
    VPN_EGRESS_COMMAND=$test_root/vpn-egress VPN_JQ=$(command -v jq) \
    VPN_OD=$(command -v od) VPN_TR=$(command -v tr) \
    XDG_RUNTIME_DIR=$test_root/run PATH=$user_path \
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

mkdir -p "$test_root/relative bin"
cat > "$test_root/relative bin/program" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$test_root/relative bin/program"
ln -s 'program' "$test_root/relative bin/linked"
(
  cd "$test_root"
  vpn './relative bin/program' one
  mapfile -t relative_args < "$test_root/args"
  [[ ${relative_args[-2]} == "$test_root/./relative bin/program" ]] || fail 'relative program path was not anchored'
  vpn 'relative bin/linked' two
  mapfile -t relative_args < "$test_root/args"
  [[ ${relative_args[-2]} == "$test_root/relative bin/linked" ]] || fail 'final symlink path was changed'
)
(
  cd "$test_root"
  user_path='relative bin':$user_path vpn linked three
  mapfile -t relative_args < "$test_root/args"
  [[ ${relative_args[-2]} == "$test_root/relative bin/linked" ]] || fail 'relative PATH entry was not anchored'
)
vpn -- multicall-name || fail 'rejected -- separator'
vpn --help | grep -q '^Usage: vpn' || fail 'help missing'
if vpn 2>/dev/null; then fail 'accepted no program'; fi
if vpn -- 2>/dev/null; then fail 'accepted an empty separator'; fi
if vpn no-such-program-for-vpn-test 2>/dev/null; then fail 'accepted a missing program'; fi
if vpn echo 2>/dev/null; then fail 'accepted a shell builtin'; fi
[[ $(vpn --capture-path --app vesktop) == "$test_root/run/vpn-capture-726f7574652d61" ]] ||
  fail 'app pin did not resolve to named capture'
[[ $(vpn --capture-path --app ayugram) == "$test_root/run/vpn-capture" ]] ||
  fail 'unbound app did not use default capture'
[[ $(vpn --capture-path --app vesktop --egress route-b) == "$test_root/run/vpn-capture-726f7574652d62" ]] ||
  fail 'explicit egress did not override app pin'
vpn --app vesktop -- multicall-name
grep -qx -- '--property=BindsTo=vpn-capture@726f7574652d61.service' "$test_root/args" ||
  fail 'pinned app scope was not bound to named capture'
grep -q -- '--unit=vpn-app-vesktop-' "$test_root/args" ||
  fail 'pinned app scope lacks stable app key'
vpn --app vesktop --egress route-b -- multicall-name
grep -qx -- '--property=BindsTo=vpn-capture@726f7574652d62.service' "$test_root/args" ||
  fail 'explicit egress did not take scope precedence'
rm "$test_root/args"
if vpn --egress absent-route -- multicall-name 2>/dev/null; then fail 'accepted unknown explicit egress'; fi
[[ ! -e $test_root/args ]] || fail 'unknown egress launched payload'
echo 'PASS: vpn command resolution and scope handoff'
