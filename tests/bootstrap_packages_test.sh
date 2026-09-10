#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
PACKAGES_TEST_ROOT="$(mktemp -d)"
readonly PACKAGES_TEST_ROOT
trap 'rm -rf -- "$PACKAGES_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$PACKAGES_TEST_ROOT/bin"

cat >"$PACKAGES_TEST_ROOT/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PACKAGE_LOG"
for argument in "$@"; do
  case "$argument" in
  git | curl | zsh)
    printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/$argument"
    /bin/chmod +x "$FAKE_BIN/$argument"
    ;;
  esac
done
EOF
chmod +x "$PACKAGES_TEST_ROOT/bin/sudo"

ln -s /bin/bash "$PACKAGES_TEST_ROOT/bin/bash"
ln -s /usr/bin/basename "$PACKAGES_TEST_ROOT/bin/basename"
ln -s /usr/bin/dirname "$PACKAGES_TEST_ROOT/bin/dirname"

for command_name in apt-get dnf pacman; do
  cat >"$PACKAGES_TEST_ROOT/bin/$command_name" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$PACKAGES_TEST_ROOT/bin/$command_name"
done

run_adapter() {
  local id="$1"
  local id_like="$2"
  local expected="$3"
  local os_release="$PACKAGES_TEST_ROOT/os-release"
  local package_log="$PACKAGES_TEST_ROOT/packages.log"

  printf 'ID=%s\nID_LIKE="%s"\n' "$id" "$id_like" >"$os_release"
  : >"$package_log"
  rm -f "$PACKAGES_TEST_ROOT/bin/git" "$PACKAGES_TEST_ROOT/bin/curl" \
    "$PACKAGES_TEST_ROOT/bin/zsh"

  PATH="$PACKAGES_TEST_ROOT/bin" \
    PACKAGE_LOG="$package_log" \
    FAKE_BIN="$PACKAGES_TEST_ROOT/bin" \
    BOOTSTRAP_OS_RELEASE_FILE="$os_release" \
    /bin/bash -c '
      phase_error() { printf "%s\n" "$1" >&2; }
      phase_info() { :; }
      source "$1"
      ensure_commands git curl
    ' _ "$REPO_ROOT/scripts/bootstrap/common/packages.sh"

  [[ "$(<"$package_log")" == "$expected" ]] || {
    printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$(<"$package_log")" >&2
    fail "$id package adapter"
  }
}

run_adapter ubuntu debian $'apt-get update\napt-get install -y git curl'
run_adapter fedora 'rhel centos' 'dnf install -y git curl'
run_adapter arch '' 'pacman -S --needed --noconfirm git curl'

: >"$PACKAGES_TEST_ROOT/packages.log"
printf 'ID=alpine\nID_LIKE=""\n' >"$PACKAGES_TEST_ROOT/os-release"
rm -f "$PACKAGES_TEST_ROOT/bin/git" "$PACKAGES_TEST_ROOT/bin/curl" \
  "$PACKAGES_TEST_ROOT/bin/zsh"
if PATH="$PACKAGES_TEST_ROOT/bin" \
  PACKAGE_LOG="$PACKAGES_TEST_ROOT/packages.log" \
  FAKE_BIN="$PACKAGES_TEST_ROOT/bin" \
  BOOTSTRAP_OS_RELEASE_FILE="$PACKAGES_TEST_ROOT/os-release" \
  /bin/bash -c '
    phase_error() { :; }
    phase_info() { :; }
    source "$1"
    ensure_commands git curl
  ' _ "$REPO_ROOT/scripts/bootstrap/common/packages.sh"; then
  fail 'an unsupported distribution should be rejected'
fi
[[ ! -s "$PACKAGES_TEST_ROOT/packages.log" ]] ||
  fail 'an unsupported distribution should not invoke a package manager'

mkdir -p "$PACKAGES_TEST_ROOT/bootstrap/common"
cp "$REPO_ROOT/scripts/bootstrap/01-host-deps.sh" \
  "$PACKAGES_TEST_ROOT/bootstrap/01-host-deps.sh"
cp "$REPO_ROOT/scripts/bootstrap/common/"*.sh \
  "$PACKAGES_TEST_ROOT/bootstrap/common/"

printf 'ID=ubuntu\nID_LIKE="debian"\n' >"$PACKAGES_TEST_ROOT/os-release"
: >"$PACKAGES_TEST_ROOT/packages.log"
rm -f "$PACKAGES_TEST_ROOT/bin/git" "$PACKAGES_TEST_ROOT/bin/curl"

output="$(
  PATH="$PACKAGES_TEST_ROOT/bin" \
    PACKAGE_LOG="$PACKAGES_TEST_ROOT/packages.log" \
    FAKE_BIN="$PACKAGES_TEST_ROOT/bin" \
    BOOTSTRAP_OS_RELEASE_FILE="$PACKAGES_TEST_ROOT/os-release" \
    "$PACKAGES_TEST_ROOT/bootstrap/01-host-deps.sh" install
)"
[[ "$output" == $'[host-deps] installing required host commands: curl git zsh\n[host-deps] required commands available: curl git zsh' ]] ||
  fail 'the host-deps phase should install and verify its authoritative command list'
[[ "$(<"$PACKAGES_TEST_ROOT/packages.log")" == $'apt-get update\napt-get install -y curl git zsh' ]] ||
  fail 'the host-deps phase should use the detected host package manager'

if output="$(
  PATH="$PACKAGES_TEST_ROOT/bin" \
    "$PACKAGES_TEST_ROOT/bootstrap/01-host-deps.sh" uninstall 2>&1
)"; then
  fail 'the host-deps phase should not support uninstall'
fi
[[ "$output" == '[host-deps] phase does not support uninstall' ]] ||
  fail 'the host-deps phase should explain that uninstall is unsupported'

printf 'bootstrap package adapter tests passed\n'
