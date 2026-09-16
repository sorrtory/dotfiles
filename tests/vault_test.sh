#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
# No test may put a window on the operator's desktop.
unset DISPLAY WAYLAND_DISPLAY
mkdir -p "$HOME" "$TEST_ROOT/bin"
vault="$REPO_ROOT/scripts/bin/vault.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# A stub gocryptfs records the storage directory it was asked to initialize, so
# the path rule is checked without creating a real filesystem or a password.
cat >"$TEST_ROOT/bin/gocryptfs" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$GOCRYPTFS_CALLS"
printf 'stub master key\n'
STUB
chmod +x "$TEST_ROOT/bin/gocryptfs"
export PATH="$TEST_ROOT/bin:$PATH"
export GOCRYPTFS_CALLS="$TEST_ROOT/calls"
: >"$GOCRYPTFS_CALLS"

# Every case below needs a helper that exists; its absence is its own case.
printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/bin/fusermount3"
chmod +x "$TEST_ROOT/bin/fusermount3"
export VAULT_FUSERMOUNT="$TEST_ROOT/bin/fusermount3"

last_call() { tail -n1 "$GOCRYPTFS_CALLS"; }

# init refuses to create storage without a terminal, because gocryptfs shows
# the master key only on one. The success cases therefore need a pty.
command -v script >/dev/null || fail 'this test needs script(1) from util-linux'
run_init() {
  printf 'password\npassword\n' | script -qec "bash $vault init $*" /dev/null 2>&1
}

# The default vault is ~/Vault, stored in its hidden sibling.
output=$(run_init)
[[ $(last_call) == "-init -- $HOME/.Vault.encrypted" ]] || fail "default storage path: $(last_call)"
[[ -d $HOME/Vault && -d $HOME/.Vault.encrypted ]] || fail 'default directories not created'
case $output in
  *KeePassXC*) : ;;
  *) fail 'recovery instruction not shown' ;;
esac
case $output in
  *'not mounted'*) : ;;
  *) fail 'did not say the vault is unmounted' ;;
esac
[[ $(stat -c %a "$HOME/.Vault.encrypted") == 700 ]] || fail 'storage is not private'

# The rule holds anywhere, not only in the home directory.
run_init "$HOME/Documents/Work" >/dev/null
[[ $(last_call) == "-init -- $HOME/Documents/.Work.encrypted" ]] || fail "nested storage path: $(last_call)"

# Existing storage that does not follow the rule is named explicitly.
run_init --storage "$TEST_ROOT/elsewhere" "$HOME/Other" >/dev/null
[[ $(last_call) == "-init -- $TEST_ROOT/elsewhere" ]] || fail "--storage ignored: $(last_call)"
run_init --storage="$TEST_ROOT/elsewhere2" "$HOME/Other2" >/dev/null
[[ $(last_call) == "-init -- $TEST_ROOT/elsewhere2" ]] || fail '--storage=DIR ignored'

# Initializing twice must never touch storage that already holds data.
printf 'ciphertext\n' >"$HOME/.Vault.encrypted/file"
before=$(last_call)
if bash "$vault" init >/dev/null 2>&1; then fail 'second init accepted'; fi
[[ $(last_call) == "$before" ]] || fail 'second init reached gocryptfs'
[[ -f $HOME/.Vault.encrypted/file ]] || fail 'second init disturbed existing storage'

# A mount directory with anything in it is refused: mounting would hide it.
mkdir -p "$HOME/Occupied"
printf 'plaintext\n' >"$HOME/Occupied/note"
if bash "$vault" init "$HOME/Occupied" >/dev/null 2>&1; then fail 'occupied mount directory accepted'; fi

for bad in / "$HOME"; do
  if bash "$vault" init "$bad" >/dev/null 2>&1; then fail "accepted unsafe mount directory: $bad"; fi
done
if bash "$vault" init --storage "$HOME/Same" "$HOME/Same" >/dev/null 2>&1; then
  fail 'accepted identical storage and mount directory'
fi
if bash "$vault" init --storage >/dev/null 2>&1; then fail '--storage without a value accepted'; fi
if bash "$vault" init a b >/dev/null 2>&1; then fail 'two mount directories accepted'; fi
if bash "$vault" nonsense >/dev/null 2>&1; then fail 'unknown command accepted'; fi
if bash "$vault" open --nonsense >/dev/null 2>&1; then fail 'unknown open option accepted'; fi

# open never initializes: storage that is missing, or present but holding no
# filesystem, sends the operator to init rather than quietly creating one.
for storage_state in absent bare; do
  rm -rf "$HOME/Unlockable" "$HOME/.Unlockable.encrypted"
  [[ $storage_state == absent ]] || mkdir -p "$HOME/.Unlockable.encrypted"
  before=$(last_call)
  refusal=$(bash "$vault" open "$HOME/Unlockable" 2>&1 || true)
  case $refusal in
    *"vault init"*) : ;;
    *) fail "open on $storage_state storage does not point at init: $refusal" ;;
  esac
  [[ $(last_call) == "$before" ]] || fail "open on $storage_state storage reached gocryptfs"
done

# A mount directory holding anything would be hidden by the mount.
mkdir -p "$HOME/.Busy.encrypted" "$HOME/Busy"
printf 'conf\n' >"$HOME/.Busy.encrypted/gocryptfs.conf"
printf 'plaintext\n' >"$HOME/Busy/note"
if bash "$vault" open "$HOME/Busy" >/dev/null 2>&1; then fail 'open accepted an occupied mount directory'; fi
[[ -f $HOME/Busy/note ]] || fail 'open disturbed the occupied mount directory'

# The stub exits cleanly without mounting anything, which is exactly the case
# the command must not report as success.
mkdir -p "$HOME/.Quiet.encrypted"
printf 'conf\n' >"$HOME/.Quiet.encrypted/gocryptfs.conf"
dishonest=$(bash "$vault" open "$HOME/Quiet" 2>&1 || true)
case $dishonest in
  *'not mounted'*) : ;;
  *) fail "a mount that did not happen was reported as success: $dishonest" ;;
esac
[[ $(last_call) == "-- $HOME/.Quiet.encrypted $HOME/Quiet" ]] || fail "open call: $(last_call)"

# --storage names existing storage for open too.
mkdir -p "$TEST_ROOT/loose"
printf 'conf\n' >"$TEST_ROOT/loose/gocryptfs.conf"
bash "$vault" open --storage "$TEST_ROOT/loose" "$HOME/Loose" >/dev/null 2>&1 || true
[[ $(last_call) == "-- $TEST_ROOT/loose $HOME/Loose" ]] || fail "open --storage: $(last_call)"

# Without the host's helper the vault could be created but never opened, so the
# refusal comes first and names what is missing.
missing=$(VAULT_FUSERMOUNT="$TEST_ROOT/absent" bash "$vault" init "$HOME/Fresh" 2>&1 || true)
case $missing in
  *fuse3*) : ;;
  *) fail "FUSE error does not name the package: $missing" ;;
esac
[[ ! -e $HOME/Fresh ]] || fail 'created directories despite the missing helper'

# Without a terminal the master key would be suppressed, so nothing is created.
if bash "$vault" init "$HOME/Headless" >/dev/null 2>&1; then fail 'init accepted without a terminal'; fi
[[ ! -e $HOME/Headless ]] || fail 'created directories without a terminal'

# The recovery material must never reach a file this command writes.
if grep -rq 'stub master key' "$HOME" 2>/dev/null; then fail 'recovery material written to disk'; fi

printf 'PASS: %s\n' "$(basename "$0")"
