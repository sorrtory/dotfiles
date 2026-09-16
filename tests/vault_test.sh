#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
# A graphical session the test pretends to have, so the dialog path is the one
# under test. Every program it could reach is stubbed below, so nothing real
# can land on the operator's desktop.
export DISPLAY=:99
unset WAYLAND_DISPLAY
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
printf '#!/bin/sh\nprintf "password\\n"\n' >"$TEST_ROOT/bin/zenity"
chmod +x "$TEST_ROOT/bin/zenity"
for gui in nautilus obsidian; do
  printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/bin/$gui"
  chmod +x "$TEST_ROOT/bin/$gui"
done
printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/bin/fusermount3"
chmod +x "$TEST_ROOT/bin/fusermount3"
export VAULT_FUSERMOUNT="$TEST_ROOT/bin/fusermount3"

last_call() { tail -n1 "$GOCRYPTFS_CALLS"; }

# init refuses to create storage without a terminal, because gocryptfs shows
# the master key only on one. The success cases therefore need a pty.
command -v script >/dev/null || fail 'this test needs script(1) from util-linux'
# init creates the vault in the working directory, so the test cds there.
run_init() {
  local dir=$1
  shift
  printf 'password\npassword\n' | script -qec "cd $dir && bash $vault init $*" /dev/null 2>&1
}

# A vault is created where the operator is standing, under the name given.
output=$(run_init "$HOME" Vault)
[[ $(last_call) == "-init -- $HOME/.Vault.encrypted" ]] || fail "storage path: $(last_call)"
[[ -d $HOME/Vault && -d $HOME/.Vault.encrypted ]] || fail 'directories not created'

# There is no default vault: every command names the one it acts on.
for bare in init open notes; do
  if bash "$vault" "$bare" >/dev/null 2>&1; then fail "vault $bare accepted no argument"; fi
done
# init takes a name, not a path, so it cannot quietly create a vault elsewhere.
if bash "$vault" init "$HOME/Elsewhere" >/dev/null 2>&1; then fail 'init accepted a path'; fi
if bash "$vault" init ../Escape >/dev/null 2>&1; then fail 'init accepted a relative path'; fi
case $output in
  *KeePassXC*) : ;;
  *) fail 'recovery instruction not shown' ;;
esac
case $output in
  *'not mounted'*) : ;;
  *) fail 'did not say the vault is unmounted' ;;
esac
[[ $(stat -c %a "$HOME/.Vault.encrypted") == 700 ]] || fail 'storage is not private'

# The rule holds wherever the operator is standing.
mkdir -p "$HOME/Documents"
run_init "$HOME/Documents" Work >/dev/null
[[ $(last_call) == "-init -- $HOME/Documents/.Work.encrypted" ]] || fail "nested storage path: $(last_call)"

# Existing storage that does not follow the rule is named explicitly.
run_init "$HOME" --storage "$TEST_ROOT/elsewhere" Other >/dev/null
[[ $(last_call) == "-init -- $TEST_ROOT/elsewhere" ]] || fail "--storage ignored: $(last_call)"
run_init "$HOME" --storage="$TEST_ROOT/elsewhere2" Other2 >/dev/null
[[ $(last_call) == "-init -- $TEST_ROOT/elsewhere2" ]] || fail '--storage=DIR ignored'

# Initializing twice must never touch storage that already holds data.
printf 'ciphertext\n' >"$HOME/.Vault.encrypted/file"
before=$(last_call)
if (cd "$HOME" && bash "$vault" init Vault) >/dev/null 2>&1; then fail 'second init accepted'; fi
[[ $(last_call) == "$before" ]] || fail 'second init reached gocryptfs'
[[ -f $HOME/.Vault.encrypted/file ]] || fail 'second init disturbed existing storage'

# A mount directory with anything in it is refused: mounting would hide it.
mkdir -p "$HOME/Occupied"
printf 'plaintext\n' >"$HOME/Occupied/note"
if (cd "$HOME" && bash "$vault" init Occupied) >/dev/null 2>&1; then fail 'occupied vault accepted'; fi

if (cd / && bash "$vault" init Vault) >/dev/null 2>&1; then fail 'accepted a vault at /'; fi
if (cd "$HOME" && bash "$vault" init --storage "$HOME/Same" Same) >/dev/null 2>&1; then
  fail 'accepted identical storage and vault directory'
fi
if (cd "$HOME" && bash "$vault" init --storage) >/dev/null 2>&1; then fail '--storage without a value accepted'; fi
if (cd "$HOME" && bash "$vault" init a b) >/dev/null 2>&1; then fail 'two names accepted'; fi
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
case $(last_call) in
  *"-extpass zenity"*"-- $HOME/.Quiet.encrypted $HOME/Quiet") : ;;
  *) fail "open call: $(last_call)" ;;
esac

# --storage names existing storage for open too.
mkdir -p "$TEST_ROOT/loose"
printf 'conf\n' >"$TEST_ROOT/loose/gocryptfs.conf"
bash "$vault" open --storage "$TEST_ROOT/loose" "$HOME/Loose" >/dev/null 2>&1 || true
case $(last_call) in
  *"-- $TEST_ROOT/loose $HOME/Loose") : ;;
  *) fail "open --storage: $(last_call)" ;;
esac

# notes unlocks the same way and creates Notes/ on first use.
mkdir -p "$HOME/.Noted.encrypted"
printf 'conf\n' >"$HOME/.Noted.encrypted/gocryptfs.conf"
bash "$vault" notes "$HOME/Noted" >/dev/null 2>&1 || true
case $(last_call) in
  *"-- $HOME/.Noted.encrypted $HOME/Noted") : ;;
  *) fail "notes call: $(last_call)" ;;
esac

# With no terminal and no way to ask, it says so instead of failing obscurely.
nodialog=$(VAULT_ASKPASS="$TEST_ROOT/no-such-dialog" bash "$vault" open "$HOME/Quiet" 2>&1 || true)
case $nodialog in
  *no-such-dialog*) : ;;
  *) fail "missing dialog not reported: $nodialog" ;;
esac

# Over ssh there is neither a terminal nor a dialog, and waiting on one that
# can never appear is a hang, not an error.
status=0
headless=$(env -u DISPLAY -u WAYLAND_DISPLAY -u VAULT_ASKPASS \
  timeout 10 bash "$vault" open "$HOME/Quiet" 2>&1) || status=$?
[[ $status != 124 ]] || fail 'open hung waiting for a dialog with no display'
case $headless in
  *'no graphical session'*) : ;;
  *) fail "headless open not reported: $headless" ;;
esac

# A dialog that is present is handed to gocryptfs as the password source.
withdialog=$(VAULT_ASKPASS="$TEST_ROOT/bin/zenity" bash "$vault" open "$HOME/Quiet" 2>&1 || true)
case $(last_call) in
  *"-extpass $TEST_ROOT/bin/zenity"*) : ;;
  *) fail "VAULT_ASKPASS not used: $(last_call)" ;;
esac

# Without the host's helper the vault could be created but never opened, so the
# refusal comes first and names what is missing.
missing=$(cd "$HOME" && VAULT_FUSERMOUNT="$TEST_ROOT/absent" bash "$vault" init Fresh 2>&1 || true)
case $missing in
  *fuse3*) : ;;
  *) fail "FUSE error does not name the package: $missing" ;;
esac
[[ ! -e $HOME/Fresh ]] || fail 'created directories despite the missing helper'

# Without a terminal the master key would be suppressed, so nothing is created.
if (cd "$HOME" && bash "$vault" init Headless) >/dev/null 2>&1; then fail 'init accepted without a terminal'; fi
[[ ! -e $HOME/Headless ]] || fail 'created directories without a terminal'

# lock on a vault that is not mounted says so and clears any stale record.
record="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/vault/$(printf '%s' "$HOME/Quiet" | tr '/' '_')"
mkdir -p "$(dirname "$record")"
printf 'pid=999999\nstorage=%s\n' "$HOME/.Quiet.encrypted" >"$record"
notmounted=$(bash "$vault" lock "$HOME/Quiet" 2>&1) || fail "lock on an unmounted vault failed: $notmounted"
case $notmounted in
  *'not unlocked'*) : ;;
  *) fail "lock on an unmounted vault: $notmounted" ;;
esac
[[ ! -f $record ]] || fail 'lock kept a record for a vault that is not mounted'

if bash "$vault" lock >/dev/null 2>&1; then fail 'lock accepted no argument'; fi
if bash "$vault" lock --nonsense "$HOME/Quiet" >/dev/null 2>&1; then fail 'lock accepted an unknown option'; fi

# --terminal refuses rather than silently falling back to a dialog.
noterm=$(env -u DISPLAY -u WAYLAND_DISPLAY VAULT_ASKPASS="$TEST_ROOT/bin/zenity" \
  timeout 10 bash "$vault" open --terminal "$HOME/Quiet" </dev/null 2>&1) || true
case $noterm in
  *'no terminal'*) : ;;
  *) fail "--terminal did not insist on a terminal: $noterm" ;;
esac

# --dialog takes the dialog even though DISPLAY is set and a stub is present.
bash "$vault" open --dialog "$HOME/Quiet" </dev/null >/dev/null 2>&1 || true
case $(last_call) in
  *"-extpass zenity"*) : ;;
  *) fail "--dialog did not use the dialog: $(last_call)" ;;
esac

# The recovery material must never reach a file this command writes.
if grep -rq 'stub master key' "$HOME" 2>/dev/null; then fail 'recovery material written to disk'; fi

printf 'PASS: %s\n' "$(basename "$0")"
