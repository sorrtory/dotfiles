#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/source" "$TEST_ROOT/target"
cat >"$TEST_ROOT/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_ROOT/sudo.log"
case "$1" in
  apparmor_parser)
    case "$2" in
      --skip-kernel-load)
        ! grep -q INVALID "$4" || exit 1 ;;
      --replace)
        [[ ${FAIL_LOAD:-} != "${3##*/}" ]] || exit 1
        printf '%s (unconfined)\n' "${3##*/}" >> "$TEST_ROOT/kernel-profiles" ;;
      --remove)
        [[ ${FAIL_UNLOAD:-} != "${3##*/}" ]] || exit 1
        sed -i "/^${3##*/} (/d" "$TEST_ROOT/kernel-profiles" ;;
    esac
    ;;
  install)
    shift
    [[ "$1 $2 $3 $4" == '-o root -g root' ]] || exit 64
    shift 4
    exec install "$@"
    ;;
  rm) exec "$@" ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/sudo"
export TEST_ROOT

restriction="$TEST_ROOT/restriction"
: > "$TEST_ROOT/kernel-profiles"
phase() {
  PATH="$TEST_ROOT/bin:$PATH" \
    BOOTSTRAP_APPARMOR_SOURCE="$TEST_ROOT/source" \
    BOOTSTRAP_APPARMOR_TARGET="$TEST_ROOT/target" \
    BOOTSTRAP_USERNS_RESTRICTION="$restriction" \
    BOOTSTRAP_APPARMOR_KERNEL_PROFILES="$TEST_ROOT/kernel-profiles" \
    bash "$REPO_ROOT/scripts/bootstrap/10-apparmor.sh" "$@"
}
sudo_calls() { if [[ -e "$TEST_ROOT/sudo.log" ]]; then wc -l <"$TEST_ROOT/sudo.log"; else echo 0; fi; }

printf '0\n' >"$restriction"
phase status >/dev/null || fail 'an unrestricted host needs no profiles'
phase install >/dev/null
[[ $(sudo_calls) == 0 ]] || fail 'an unrestricted host must not escalate'

printf '1\n' >"$restriction"
rmdir "$TEST_ROOT/source"
if phase status >/dev/null; then fail 'missing generated profiles reported satisfied'; fi
if phase install >/dev/null 2>&1; then fail 'installed without generated profiles'; fi
mkdir "$TEST_ROOT/source"

printf 'profile a {}\n' >"$TEST_ROOT/source/dotfiles-a"
printf 'profile b {}\n' >"$TEST_ROOT/source/dotfiles-b"
printf 'unrelated\n' >"$TEST_ROOT/target/usr.bin.other"
if phase status >/dev/null; then fail 'uninstalled profiles reported satisfied'; fi
phase install >/dev/null
cmp -s "$TEST_ROOT/source/dotfiles-a" "$TEST_ROOT/target/dotfiles-a" || fail 'profile a not installed'
cmp -s "$TEST_ROOT/source/dotfiles-b" "$TEST_ROOT/target/dotfiles-b" || fail 'profile b not installed'
[[ $(head -n 2 "$TEST_ROOT/sudo.log" | grep -c -- --skip-kernel-load) == 2 ]] ||
  fail 'every profile must be validated before any install'
grep -qx "apparmor_parser --replace $TEST_ROOT/target/dotfiles-a" "$TEST_ROOT/sudo.log" ||
  fail 'installed profile not loaded'
phase status >/dev/null || fail 'installed profiles not recognized'
# A copied file is not proof that the kernel accepted the profile.
sed -i '/^dotfiles-b (/d' "$TEST_ROOT/kernel-profiles"
if phase status >/dev/null; then fail 'missing kernel policy reported satisfied'; fi
phase install >/dev/null
phase status >/dev/null || fail 'kernel policy not restored'

# A failed load leaves the installed file and a retryable status.
sed -i '/^dotfiles-a (/d' "$TEST_ROOT/kernel-profiles"
if FAIL_LOAD=dotfiles-a phase install >/dev/null 2>&1; then fail 'failed load reported installed'; fi
if phase status >/dev/null; then fail 'failed load reported satisfied'; fi
phase install >/dev/null
phase status >/dev/null || fail 'failed load could not be retried'
calls=$(sudo_calls)
phase install >/dev/null
[[ $(sudo_calls) == "$calls" ]] || fail 'install was not idempotent'

printf 'profile a { changed }\n' >"$TEST_ROOT/source/dotfiles-a"
printf 'profile old {}\n' >"$TEST_ROOT/target/dotfiles-old"
if phase status >/dev/null; then fail 'stale and leftover profiles reported satisfied'; fi
phase install >/dev/null
cmp -s "$TEST_ROOT/source/dotfiles-a" "$TEST_ROOT/target/dotfiles-a" || fail 'stale profile not replaced'
[[ ! -e "$TEST_ROOT/target/dotfiles-old" ]] || fail 'profile no longer generated was kept'
phase status >/dev/null || fail 'refreshed profiles not recognized'

printf 'INVALID\n' >"$TEST_ROOT/source/dotfiles-a"
if phase install >/dev/null 2>&1; then fail 'installed an invalid profile'; fi
grep -q changed "$TEST_ROOT/target/dotfiles-a" || fail 'failed validation still changed installed policy'
printf 'profile a { changed }\n' >"$TEST_ROOT/source/dotfiles-a"

if FAIL_UNLOAD=dotfiles-a phase uninstall >/dev/null 2>&1; then fail 'failed unload reported removed'; fi
[[ -e "$TEST_ROOT/target/dotfiles-a" ]] || fail 'failed unload removed recovery input'
phase uninstall >/dev/null
[[ -z $(find "$TEST_ROOT/target" -name 'dotfiles-*') ]] || fail 'uninstall left profiles'
[[ -e "$TEST_ROOT/target/usr.bin.other" ]] || fail 'uninstall touched unrelated policy'
if phase uninstall >/dev/null 2>&1; then fail 'uninstalled twice'; fi
printf 'bootstrap apparmor tests passed\n'
