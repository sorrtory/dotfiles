#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SUBJECT="$REPO_ROOT/scripts/bootstrap/03-nix.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Source the phase in a conditional context so its normal entrypoint can return
# on hosts where Nix is absent. The functions remain available for focused tests.
# shellcheck disable=SC1090
if source "$SUBJECT" status >/dev/null 2>&1; then
  :
fi

load_nix_profile() { :; }
multi_user_nix_installed() { return 0; }

# Called indirectly by the phase's check function.
# shellcheck disable=SC2329
nix() {
  if [[ "$1" == --version ]]; then
    return 42
  fi
  return 0
}

if check >/dev/null 2>&1; then
  fail 'a failed Nix version query should not be reported as satisfied'
else
  result=$?
fi
[[ $result -eq 2 ]] ||
  fail 'a failed Nix version query should be an inspection error'

nix() {
  if [[ "$1" == --version ]]; then
    printf 'nix test-version\n'
    return
  fi
  return 42
}

if check >/dev/null 2>&1; then
  fail 'a failed feature query should not be reported as satisfied'
else
  result=$?
fi
[[ $result -eq 2 ]] ||
  fail 'a failed feature query should be an inspection error'

# Nix 2.35 refuses the feature query itself until nix-command is enabled.
nix() {
  if [[ "$1" == --version ]]; then
    printf 'nix test-version\n'
    return
  fi
  printf "error: experimental Nix feature 'nix-command' is disabled; add '--extra-experimental-features nix-command' to enable it\n" >&2
  return 1
}

if check >/dev/null 2>&1; then
  fail 'a disabled nix-command should not be reported as satisfied'
else
  result=$?
fi
[[ $result -eq 1 ]] ||
  fail 'a disabled nix-command should leave flakes to be enabled, not error'

# Called indirectly by nss_entry_absent.
# shellcheck disable=SC2329
getent() { return 2; }
nss_entry_absent passwd missing-user ||
  fail 'getent not-found should mean the NSS entry is absent'

getent() { return 3; }
if nss_entry_absent passwd unavailable-user >/dev/null 2>&1; then
  fail 'an NSS lookup failure should not mean the entry is absent'
else
  result=$?
fi
[[ $result -eq 2 ]] ||
  fail 'an NSS lookup failure should be an inspection error'

# A host with no Nix yet simply has no daemon profile, which is not an error.
# A bare `return` after the existence test used to hand back that test's
# status, so check() gave up before it could report "not installed" -- silent
# on the one machine where the message matters most.
# The stub near the top replaced the real function, so take it back to test it.
eval "$(sed -n '/^load_nix_profile()/,/^}/p' "$SUBJECT")"
# shellcheck disable=SC2329
nix_daemon_profile_path() { printf '/nonexistent/nix-daemon.sh\n'; }
load_nix_profile ||
  fail 'a missing Nix daemon profile should not be reported as a failure'

printf 'bootstrap Nix tests passed\n'
