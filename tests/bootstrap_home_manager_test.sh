#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
HOME_MANAGER_TEST_ROOT="$(mktemp -d)"
readonly HOME_MANAGER_TEST_ROOT
trap 'rm -rf -- "$HOME_MANAGER_TEST_ROOT"' EXIT

# Use an isolated source tree so freshness tests never edit the real checkout.
fixture_repo="$HOME_MANAGER_TEST_ROOT/repo"
mkdir -p "$fixture_repo/scripts/bootstrap/common" "$fixture_repo/scripts/bin" \
  "$fixture_repo/modules" "$fixture_repo/packages"
cp "$REPO_ROOT/scripts/bootstrap/04-home-manager.sh" "$fixture_repo/scripts/bootstrap/"
cp "$REPO_ROOT/scripts/bootstrap/common/"*.sh "$fixture_repo/scripts/bootstrap/common/"
touch "$fixture_repo/flake.nix" "$fixture_repo/flake.lock" "$fixture_repo/home.nix"
printf '# initial generator\n' >"$fixture_repo/scripts/bin/generator.sh"
readonly SUBJECT="$fixture_repo/scripts/bootstrap/04-home-manager.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

test_home="$HOME_MANAGER_TEST_ROOT/home"
mock_bin="$HOME_MANAGER_TEST_ROOT/bin"
mkdir -p "$test_home" "$mock_bin"

cat >"$mock_bin/nix" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == build ]] || exit 42
printf '%s\n' "${@: -1}" >"$HOME/nix-build.log"
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
  --out-link)
    out_link="$2"
    shift 2
    ;;
  *) shift ;;
  esac
done
mkdir -p "$out_link"
cat >"$out_link/activate" <<'ACTIVATE'
#!/usr/bin/env bash
mkdir -p "$HOME/.local/state/nix/profiles"
generation="$HOME/.local/state/nix/profiles/home-manager-test-generation"
mkdir -p "$generation"
touch "$generation/activate"
chmod +x "$generation/activate"
ln -sfn "$generation" "$HOME/.local/state/nix/profiles/home-manager"
printf 'activated\n' >"$HOME/activation.log"
ACTIVATE
chmod +x "$out_link/activate"
EOF
chmod +x "$mock_bin/nix"

if HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" status >/dev/null 2>&1; then
  fail 'a missing Home Manager profile should leave the phase unsatisfied'
fi

HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" install >/dev/null
[[ "$(<"$test_home/activation.log")" == activated ]] ||
  fail 'install should activate the built Home Manager generation'
HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" status >/dev/null ||
  fail 'the activated repository configuration should satisfy the phase'

printf '# changed generator\n' >"$fixture_repo/scripts/bin/generator.sh"
if HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" status >/dev/null 2>&1; then
  fail 'changing packaged script source must invalidate activation'
fi
HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" install >/dev/null
HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" status >/dev/null ||
  fail 're-activation should capture the changed packaged source'

grep -q '#homeConfigurations\.z\.activationPackage$' "$test_home/nix-build.log" ||
  fail 'the default configuration should be z'
if DOTFILES_HOME_CONFIGURATION=staging HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" status >/dev/null 2>&1; then
  fail 'selecting a different configuration must invalidate activation'
fi
DOTFILES_HOME_CONFIGURATION=staging HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" install >/dev/null
grep -q '#homeConfigurations\.staging\.activationPackage$' "$test_home/nix-build.log" ||
  fail 'install should build the selected configuration'
HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" status >/dev/null ||
  fail 'the selected configuration should be remembered without the variable'
printf '# generator after selection\n' >"$fixture_repo/scripts/bin/generator.sh"
HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" install >/dev/null
grep -q '#homeConfigurations\.staging\.activationPackage$' "$test_home/nix-build.log" ||
  fail 're-activation must not revert to the default configuration'
if DOTFILES_HOME_CONFIGURATION='z#bad' HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" status >/dev/null 2>&1; then
  fail 'an invalid configuration name must be rejected'
fi

printf 'stale\n' >"$test_home/.local/state/dotfiles/home-manager-source.sha256"
if HOME="$test_home" PATH="$mock_bin:$PATH" NIX_DAEMON_PROFILE=/dev/null "$SUBJECT" status >/dev/null 2>&1; then
  fail 'a stale repository fingerprint should leave the phase unsatisfied'
fi

printf 'bootstrap Home Manager tests passed\n'
