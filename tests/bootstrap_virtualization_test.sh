#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export TEST_ROOT
mkdir "$TEST_ROOT/bin"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

cat >"$TEST_ROOT/bin/mock" <<'EOF'
#!/usr/bin/env bash
set -eu
command_name=${0##*/}
case "$command_name" in
  sudo)
    printf '%s\n' "$*" >>"$TEST_ROOT/actions"
    [[ $1 == -v ]] && exit 0
    exec "$@"
    ;;
  uname) echo x86_64 ;;
  id)
    case "$1" in
      -un) echo tester ;;
      -nG) if [[ -e $TEST_ROOT/member ]]; then echo 'tester libvirt'; else echo tester; fi ;;
    esac
    ;;
  getent) echo 'libvirt:x:123:' ;;
  usermod) touch "$TEST_ROOT/member" ;;
  apt-get|dnf|pacman)
    if [[ $1 == -Q ]]; then test -e "$TEST_ROOT/installed"; exit; fi
    [[ ${FAIL_PACKAGES:-0} == 0 ]] || exit 1
    touch "$TEST_ROOT/installed"
    ;;
  dpkg-query) test -e "$TEST_ROOT/installed"; echo 'ii ' ;;
  rpm) test -e "$TEST_ROOT/installed" ;;
  systemctl)
    unit=${*: -1}
    case "$1" in
      show) echo "${MODULAR_LOAD_STATE:-loaded}" ;;
      is-active) test -e "$TEST_ROOT/active-$unit" ;;
      is-enabled) test -e "$TEST_ROOT/enabled-$unit" ;;
      enable)
        touch "$TEST_ROOT/enabled-$unit"
        if [[ $* == *--now* ]]; then touch "$TEST_ROOT/active-$unit"; fi
        ;;
      *) exit 64 ;;
    esac
    ;;
  virsh)
    case "$*" in
      *'net-info default')
        test -e "$TEST_ROOT/network"
        echo 'Active:         yes'
        echo 'Autostart:      yes'
        ;;
      *'net-list --all --name') echo default ;;
      *'net-list --name') if [[ -e $TEST_ROOT/network ]]; then echo default; fi ;;
      *'net-start default') [[ ${FAIL_NETWORK:-0} == 0 ]]; touch "$TEST_ROOT/network" ;;
      *'net-autostart default'|*'list --all') : ;;
      *) exit 64 ;;
    esac
    ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/mock"
for command_name in sudo uname id getent usermod apt-get dnf pacman dpkg-query rpm systemctl virsh; do
  ln -s mock "$TEST_ROOT/bin/$command_name"
done
export PATH="$TEST_ROOT/bin:$PATH"
export BOOTSTRAP_OS_RELEASE_FILE="$TEST_ROOT/os-release"
phase="$REPO_ROOT/scripts/bootstrap/10-virtualization.sh"

reset_state() {
  rm -f "$TEST_ROOT"/active-* "$TEST_ROOT"/enabled-* "$TEST_ROOT/installed" \
    "$TEST_ROOT/member" "$TEST_ROOT/network"
  : >"$TEST_ROOT/actions"
  printf 'ID=%s\n' "$1" >"$BOOTSTRAP_OS_RELEASE_FILE"
}

for distribution in ubuntu debian fedora arch; do
  reset_state "$distribution"
  if bash "$phase" status >/dev/null; then fail 'missing installation reported ready'; fi
  [[ ! -s $TEST_ROOT/actions ]] || fail 'status used sudo'
  bash "$phase" install >/dev/null
  bash "$phase" status >/dev/null
  grep -q 'enable --now virtqemud.socket' "$TEST_ROOT/actions" || fail 'modular socket not enabled'
  grep -q 'enable --now virtnetworkd.socket' "$TEST_ROOT/actions" || fail 'network daemon not enabled'
  [[ -e $TEST_ROOT/member && -e $TEST_ROOT/network ]] || fail 'membership or network missing'
  count=$(wc -l <"$TEST_ROOT/actions")
  bash "$phase" install >/dev/null
  [[ $(wc -l <"$TEST_ROOT/actions") == "$count" ]] || fail 'reinstall mutated configured host'
done

reset_state ubuntu
touch "$TEST_ROOT/active-libvirtd.socket" "$TEST_ROOT/enabled-virtqemud.socket"
bash "$phase" install >/dev/null
grep -q 'enable --now libvirtd.socket' "$TEST_ROOT/actions" || fail 'existing monolithic layout changed'
if grep -q 'enable.*virtqemud' "$TEST_ROOT/actions"; then fail 'started competing daemon'; fi

reset_state arch
if FAIL_PACKAGES=1 bash "$phase" install >/dev/null 2>&1; then fail 'ignored package failure'; fi
if grep -q systemctl "$TEST_ROOT/actions"; then fail 'changed services after package failure'; fi
reset_state fedora
if FAIL_NETWORK=1 bash "$phase" install >/dev/null 2>&1; then fail 'ignored network failure'; fi

reset_state alpine
if bash "$phase" install >/dev/null 2>&1; then fail 'accepted unsupported distro'; fi
[[ ! -s $TEST_ROOT/actions ]] || fail 'unsupported distro used sudo'
if bash "$phase" uninstall >/dev/null 2>&1; then fail 'allowed destructive uninstall'; fi
printf 'virtualization bootstrap tests passed\n'
