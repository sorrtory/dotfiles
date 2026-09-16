#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export TEST_ROOT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/rpm" "$TEST_ROOT/override" "$TEST_ROOT/root"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

cat >"$TEST_ROOT/bin/mock" <<'EOF'
#!/usr/bin/env bash
set -eu
command_name=${0##*/}
case "$command_name" in
  uname) echo x86_64 ;;
  lspci)
    if [[ -e "$TEST_ROOT/lspci-amd" ]]; then
      echo '01:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] [1002:15bf]'
    else
      echo '00:02.0 VGA compatible controller [0300]: Intel Corporation [8086:a7a0]'
    fi
    ;;
  curl)
    [[ ! -e "$TEST_ROOT/fail-curl" ]]
    ;;
  rpm)
    case "$1" in
      -E)
        case "$2" in
          %fedora) echo 44 ;;
          %_arch) echo x86_64 ;;
        esac
        ;;
      -q)
        shift
        for pkg in "$@"; do
          [[ -e "$TEST_ROOT/rpm/$pkg" ]] || exit 1
        done
        ;;
      *) exit 64 ;;
    esac
    ;;
  dnf)
    case "$1" in
      clean | makecache) : ;;
      -q)
        [[ $2 == repoquery ]] || exit 64
        [[ ! -e "$TEST_ROOT/no-freeworld" ]] || exit 1
        echo 'mesa-va-drivers-freeworld-24.1-1.fc44.x86_64'
        ;;
      -y)
        shift
        case "$1" in
          distro-sync | upgrade) : ;;
          install)
            shift
            for arg in "$@"; do
              [[ $arg == --refresh ]] && continue
              case "$arg" in
                */rpmfusion-free-release-*.noarch.rpm) touch "$TEST_ROOT/rpm/rpmfusion-free-release" ;;
                */rpmfusion-nonfree-release-*.noarch.rpm) touch "$TEST_ROOT/rpm/rpmfusion-nonfree-release" ;;
                *) touch "$TEST_ROOT/rpm/$arg" ;;
              esac
            done
            ;;
          swap)
            shift
            rm -f "$TEST_ROOT/rpm/$1"
            touch "$TEST_ROOT/rpm/$2"
            ;;
          *) exit 64 ;;
        esac
        ;;
      *) exit 64 ;;
    esac
    ;;
  sudo)
    [[ $1 == -v ]] && exit 0
    exec "$@"
    ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/mock"
for command_name in uname lspci curl rpm dnf sudo; do
  ln -s mock "$TEST_ROOT/bin/$command_name"
done
export PATH="$TEST_ROOT/bin:$PATH"
export BOOTSTRAP_OS_RELEASE_FILE="$TEST_ROOT/os-release"
export BOOTSTRAP_FEDORA_AMD_OVERRIDE_DIR="$TEST_ROOT/override"
export BOOTSTRAP_FEDORA_AMD_BACKUP_DIR="$TEST_ROOT/root"
readonly PHASE="$REPO_ROOT/scripts/bootstrap/11-fedora-amd-gpu.sh"

reset_state() {
  rm -rf "$TEST_ROOT/rpm" "$TEST_ROOT/override" "$TEST_ROOT"/lspci-amd "$TEST_ROOT"/fail-curl "$TEST_ROOT"/no-freeworld
  mkdir -p "$TEST_ROOT/rpm" "$TEST_ROOT/override"
  printf 'ID=%s\n' "$1" >"$BOOTSTRAP_OS_RELEASE_FILE"
}

# Non-Fedora host: check() must no-op without ever invoking lspci.
reset_state ubuntu
rm -f "$TEST_ROOT/bin/lspci"
if ! "$PHASE" status >/dev/null; then
  fail 'a non-Fedora host should report satisfied (nothing to do)'
fi
ln -s mock "$TEST_ROOT/bin/lspci"

# Fedora, non-AMD GPU: check() must no-op.
reset_state fedora
if ! "$PHASE" status >/dev/null; then
  fail 'a Fedora host without an AMD GPU should report satisfied (nothing to do)'
fi

# Fedora + AMD, nothing installed: check() must report unsatisfied.
reset_state fedora
touch "$TEST_ROOT/lspci-amd"
if "$PHASE" status >/dev/null 2>&1; then
  fail 'a matching host with nothing installed should not report satisfied'
fi

# Mirror preflight failure must leave the override directory untouched.
touch "$TEST_ROOT/fail-curl"
if "$PHASE" install >/dev/null 2>&1; then
  fail 'a failed mirror preflight should not report success'
fi
if [[ -n "$(ls -A "$TEST_ROOT/override")" ]]; then
  fail 'a failed mirror preflight must not write any repository override file'
fi
rm -f "$TEST_ROOT/fail-curl"

# Full install against the stubs, then a satisfied re-check.
if ! "$PHASE" install >/dev/null; then
  fail 'install should succeed against a fully stubbed Fedora/AMD host'
fi
if [[ ! -e "$TEST_ROOT/override/80-yandex-fedora.repo" || ! -e "$TEST_ROOT/override/81-yandex-rpmfusion.repo" ]]; then
  fail 'install should write both Yandex repository overrides'
fi
if [[ ! -e "$TEST_ROOT/rpm/mesa-va-drivers-freeworld" ]]; then
  fail 'install should end up with mesa-va-drivers-freeworld installed'
fi
if ! "$PHASE" status >/dev/null; then
  fail 'a repeat status check after install should report satisfied'
fi

printf 'bootstrap Fedora AMD GPU tests passed\n'
