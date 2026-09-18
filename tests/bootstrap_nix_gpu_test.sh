#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/profile/bin" "$TEST_ROOT/etc" "$TEST_ROOT/gcroots"
cat >"$TEST_ROOT/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_ROOT/sudo.log"
case "$1" in
  */bin/non-nixos-gpu-setup | rm) exec "$@" ;;
  *) exit 64 ;;
esac
MOCK
chmod +x "$TEST_ROOT/bin/sudo"
export TEST_ROOT

# A stand-in for one generation's setup package: a tmpfiles rule naming its
# drivers, and a setup command that installs the rule and creates the link.
make_generation() {
  local package="$TEST_ROOT/store/$1-non-nixos-gpu"
  mkdir -p "$package/bin" "$package/lib/tmpfiles.d"
  printf 'L+ /run/opengl-driver - - - - %s\n' "$TEST_ROOT/store/$1-drivers" \
    >"$package/lib/tmpfiles.d/non-nixos-gpu.conf"
  cat >"$package/bin/non-nixos-gpu-setup" <<SETUP
#!/usr/bin/env bash
ln -sfn "$package/lib/tmpfiles.d/non-nixos-gpu.conf" "$TEST_ROOT/etc/non-nixos-gpu.conf"
ln -sfn "$TEST_ROOT/etc/non-nixos-gpu.conf" "$TEST_ROOT/gcroots/non-nixos-gpu.conf"
ln -sfn "$TEST_ROOT/store/$1-drivers" "$TEST_ROOT/opengl-driver"
SETUP
  chmod +x "$package/bin/non-nixos-gpu-setup"
  ln -sfn "$package/bin/non-nixos-gpu-setup" "$TEST_ROOT/profile/bin/non-nixos-gpu-setup"
}

phase() {
  PATH="$TEST_ROOT/bin:$PATH" \
    BOOTSTRAP_NIX_GPU_SETUP="$TEST_ROOT/profile/bin/non-nixos-gpu-setup" \
    BOOTSTRAP_NIX_GPU_LINK="$TEST_ROOT/opengl-driver" \
    BOOTSTRAP_NIX_GPU_TMPFILES="$TEST_ROOT/etc/non-nixos-gpu.conf" \
    BOOTSTRAP_NIX_GPU_GCROOT="$TEST_ROOT/gcroots/non-nixos-gpu.conf" \
    bash "$REPO_ROOT/scripts/bootstrap/13-nix-gpu.sh" "$@"
}
sudo_calls() { if [[ -e "$TEST_ROOT/sudo.log" ]]; then wc -l <"$TEST_ROOT/sudo.log"; else echo 0; fi; }

if phase status >/dev/null; then fail 'an unactivated configuration reported satisfied'; fi
if phase install >/dev/null 2>&1; then fail 'installed without the setup command'; fi
[[ $(sudo_calls) == 0 ]] || fail 'escalated without the setup command'

make_generation one
if phase status >/dev/null; then fail 'a missing driver link reported satisfied'; fi
phase install >/dev/null
[[ $(readlink "$TEST_ROOT/opengl-driver") == "$TEST_ROOT/store/one-drivers" ]] || fail 'drivers not linked'
grep -qx "$TEST_ROOT/store/one-non-nixos-gpu/bin/non-nixos-gpu-setup" "$TEST_ROOT/sudo.log" ||
  fail 'sudo must run the resolved setup command'
phase status >/dev/null || fail 'linked drivers not recognized'
calls=$(sudo_calls)
phase install >/dev/null
[[ $(sudo_calls) == "$calls" ]] || fail 'install was not idempotent'

rm "$TEST_ROOT/etc/non-nixos-gpu.conf"
if phase status >/dev/null; then fail 'a link without its boot rule reported satisfied'; fi
phase install >/dev/null

make_generation two
if phase status >/dev/null; then fail 'drivers from an older generation reported satisfied'; fi
phase install >/dev/null
[[ $(readlink "$TEST_ROOT/opengl-driver") == "$TEST_ROOT/store/two-drivers" ]] || fail 'stale drivers not relinked'
phase status >/dev/null || fail 'relinked drivers not recognized'

phase uninstall >/dev/null
for path in opengl-driver etc/non-nixos-gpu.conf gcroots/non-nixos-gpu.conf; do
  [[ ! -L "$TEST_ROOT/$path" ]] || fail "uninstall left $path"
done
if phase uninstall >/dev/null 2>&1; then fail 'uninstalled twice'; fi
printf 'bootstrap nix-gpu tests passed\n'
