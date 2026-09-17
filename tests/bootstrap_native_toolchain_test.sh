#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export TEST_ROOT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/packages"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# One mock stands in for every package manager and query tool. Installing a
# package is a file under packages/, which is what the query side reads back.
cat >"$TEST_ROOT/bin/mock" <<'EOF'
#!/usr/bin/env bash
set -eu
command_name=${0##*/}
record() { touch "$TEST_ROOT/packages/$1"; }
case "$command_name" in
  rpm)
    [[ $1 == --quiet ]] && shift
    [[ $1 == --query ]] || exit 64
    shift
    [[ -e "$TEST_ROOT/packages/$1" ]]
    ;;
  dpkg-query)
    package="${*: -1}"
    [[ -e "$TEST_ROOT/packages/$package" ]] || exit 1
    echo 'ii '
    ;;
  pacman)
    case "$1" in
      -Q) [[ -e "$TEST_ROOT/packages/$2" ]] ;;
      -S)
        shift
        for arg in "$@"; do
          [[ $arg == --* ]] && continue
          record "$arg"
        done
        ;;
      *) exit 64 ;;
    esac
    ;;
  apt-get)
    case "$1" in
      update) : ;;
      install)
        shift
        for arg in "$@"; do
          [[ $arg == -* ]] && continue
          record "$arg"
        done
        ;;
      *) exit 64 ;;
    esac
    ;;
  dnf)
    [[ $1 == install ]] || exit 64
    shift
    for arg in "$@"; do
      [[ $arg == -* ]] && continue
      record "$arg"
    done
    ;;
  sudo)
    [[ $1 == -v ]] && exit 0
    exec "$@"
    ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/mock"
for command_name in rpm dpkg-query pacman apt-get dnf sudo; do
  ln -s mock "$TEST_ROOT/bin/$command_name"
done

# The host toolchain the phase probes with: a pkg-config that describes GTK and
# a clang++ that writes whatever the scenario asks for into its output.
cat >"$TEST_ROOT/bin/host-pkg-config" <<'EOF'
#!/usr/bin/env bash
set -eu
[[ -e "$TEST_ROOT/no-gtk" ]] && exit 1
echo '-I/usr/include/gtk-3.0 -lgtk-3'
EOF
cat >"$TEST_ROOT/bin/host-clang++" <<'EOF'
#!/usr/bin/env bash
set -eu
[[ -e "$TEST_ROOT/compiler-fails" ]] && exit 1
output=''
while [[ $# -gt 0 ]]; do
  [[ $1 == -o ]] && output="$2"
  shift
done
[[ -n $output ]] || exit 64
if [[ -e "$TEST_ROOT/leak-nix" ]]; then
  echo 'ELF /nix/store/aaaa-glibc/lib/ld-linux-x86-64.so.2' >"$output"
else
  echo 'ELF /lib64/ld-linux-x86-64.so.2' >"$output"
fi
EOF
chmod +x "$TEST_ROOT/bin/host-pkg-config" "$TEST_ROOT/bin/host-clang++"

export PATH="$TEST_ROOT/bin:$PATH"
export BOOTSTRAP_OS_RELEASE_FILE="$TEST_ROOT/os-release"
export BOOTSTRAP_HOST_CLANGXX="$TEST_ROOT/bin/host-clang++"
export BOOTSTRAP_HOST_PKG_CONFIG="$TEST_ROOT/bin/host-pkg-config"
readonly PHASE="$REPO_ROOT/scripts/bootstrap/12-native-toolchain.sh"

reset_state() {
  rm -rf "$TEST_ROOT/packages" "$TEST_ROOT/leak-nix" "$TEST_ROOT/no-gtk" "$TEST_ROOT/compiler-fails"
  mkdir -p "$TEST_ROOT/packages"
  printf 'ID=%s\n' "$1" >"$BOOTSTRAP_OS_RELEASE_FILE"
}

status_of() {
  local result=0
  "$PHASE" "$1" >/dev/null 2>&1 || result=$?
  printf '%s\n' "$result"
}

# An unsupported distribution is an error, not unfinished work: nothing this
# phase could install would make it right.
reset_state alpine
if [[ $(status_of status) -ne 2 ]]; then
  fail 'an unsupported distribution should report an error, not a missing install'
fi

# Fedora with nothing installed is unfinished work.
reset_state fedora
if [[ $(status_of status) -ne 1 ]]; then
  fail 'a Fedora host with no toolchain packages should report unsatisfied'
fi

# Installing, then a satisfied re-check driven by the stub toolchain.
if ! "$PHASE" install >/dev/null 2>&1; then
  fail 'install should succeed against a fully stubbed Fedora host'
fi
for package in clang gtk3-devel xz-devel pkgconf-pkg-config; do
  [[ -e "$TEST_ROOT/packages/$package" ]] || fail "Fedora install should install $package"
done
if [[ $(status_of status) -ne 0 ]]; then
  fail 'a stubbed host that builds and links a GTK program should report satisfied'
fi

# A compiler that cannot build the probe is unfinished work.
touch "$TEST_ROOT/compiler-fails"
if [[ $(status_of status) -ne 1 ]]; then
  fail 'a host compiler that fails to build the probe should report unsatisfied'
fi
rm -f "$TEST_ROOT/compiler-fails"

# Missing GTK development data is unfinished work too.
touch "$TEST_ROOT/no-gtk"
if [[ $(status_of status) -ne 1 ]]; then
  fail 'a pkg-config that cannot describe gtk+-3.0 should report unsatisfied'
fi
rm -f "$TEST_ROOT/no-gtk"

# The whole point of the probe: a binary carrying /nix/store means the Nix
# linker answered for the host compiler, and no install can fix that.
touch "$TEST_ROOT/leak-nix"
if [[ $(status_of status) -ne 2 ]]; then
  fail 'a probe binary reaching into /nix/store should report an error, not unsatisfied'
fi
if "$PHASE" install >/dev/null 2>&1; then
  fail 'install should refuse to proceed while the toolchains are mixing'
fi
rm -f "$TEST_ROOT/leak-nix"

# Debian and Arch select their own package names for the same job.
reset_state debian
if ! "$PHASE" install >/dev/null 2>&1; then
  fail 'install should succeed against a stubbed Debian host'
fi
for package in clang libgtk-3-dev liblzma-dev pkg-config; do
  [[ -e "$TEST_ROOT/packages/$package" ]] || fail "Debian install should install $package"
done

reset_state arch
if ! "$PHASE" install >/dev/null 2>&1; then
  fail 'install should succeed against a stubbed Arch host'
fi
for package in clang gcc gtk3 xz pkgconf; do
  [[ -e "$TEST_ROOT/packages/$package" ]] || fail "Arch install should install $package"
done

printf 'bootstrap native toolchain tests passed\n'
