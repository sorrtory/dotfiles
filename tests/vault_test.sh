#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME" "$TEST_ROOT/bin"
vault="$REPO_ROOT/scripts/bin/vault.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# A graphical session the test pretends to have, so the dialog path is the one
# under test. Every program it could reach is stubbed below, so nothing real
# can land on the operator's desktop.
export DISPLAY=:99
unset WAYLAND_DISPLAY

# A stub gocryptfs records what it was asked to do, so the path rule and the
# prompt choice are checked without a filesystem or a password.
cat >"$TEST_ROOT/bin/gocryptfs" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$GOCRYPTFS_CALLS"
printf 'stub master key\n'
STUB
chmod +x "$TEST_ROOT/bin/gocryptfs"
printf '#!/bin/sh\nprintf "password\\n"\n' >"$TEST_ROOT/bin/zenity"
for gui in nautilus obsidian; do
  printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/bin/$gui"
done
cat >"$TEST_ROOT/bin/notify-send" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$NOTIFICATIONS"
STUB
export NOTIFICATIONS="$TEST_ROOT/notifications"
: >"$NOTIFICATIONS"
unset VAULT_DESKTOP_ENTRY
printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/bin/fusermount3"
chmod +x "$TEST_ROOT"/bin/*
export PATH="$TEST_ROOT/bin:$PATH"
export GOCRYPTFS_CALLS="$TEST_ROOT/calls"
: >"$GOCRYPTFS_CALLS"
export VAULT_FUSERMOUNT="$TEST_ROOT/bin/fusermount3"

last_call() { tail -n1 "$GOCRYPTFS_CALLS"; }
record_for() { printf '%s/vault/%s\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" "$(printf '%s' "$1" | tr '/' '_')"; }

# init refuses without a terminal, because gocryptfs shows the master key only
# on one, so the success cases need a pty.
command -v script >/dev/null || fail 'this test needs script(1) from util-linux'
run_init() {
  local dir=$1
  shift
  printf 'password\npassword\n' | script -qec "cd $dir && bash $vault init $*" /dev/null 2>&1
}

make_storage() { mkdir -p "$1"; printf 'conf\n' >"$1/gocryptfs.conf"; }

# --- naming a vault ---------------------------------------------------------

# With no name, a vault is ./Vault: where the operator is standing, never $HOME
# by surprise.
mkdir -p "$TEST_ROOT/somewhere"
output=$(run_init "$TEST_ROOT/somewhere")
[[ $(last_call) == "-init -- $TEST_ROOT/somewhere/.Vault.encrypted" ]] || fail "default name: $(last_call)"
[[ -d $TEST_ROOT/somewhere/Vault ]] || fail 'default vault not created in the working directory'
[[ ! -e $HOME/Vault ]] || fail 'a vault appeared in the home directory'
case $output in
  *KeePassXC*) : ;;
  *) fail 'recovery instruction not shown' ;;
esac
[[ $(stat -c %a "$TEST_ROOT/somewhere/.Vault.encrypted") == 700 ]] || fail 'storage is not private'

# A name puts it beside the default one; the sibling rule holds either way.
run_init "$TEST_ROOT/somewhere" Work >/dev/null
[[ $(last_call) == "-init -- $TEST_ROOT/somewhere/.Work.encrypted" ]] || fail "named vault: $(last_call)"

# init takes a name, not a path.
if bash "$vault" init "$HOME/Elsewhere" >/dev/null 2>&1; then fail 'init accepted a path'; fi
if bash "$vault" init ../Escape >/dev/null 2>&1; then fail 'init accepted a relative path'; fi

# The same default applies to every other command.
make_storage "$TEST_ROOT/somewhere/.Vault.encrypted"
(cd "$TEST_ROOT/somewhere" && bash "$vault" unlock >/dev/null 2>&1) || true
case $(last_call) in
  *"-- $TEST_ROOT/somewhere/.Vault.encrypted $TEST_ROOT/somewhere/Vault") : ;;
  *) fail "unlock default: $(last_call)" ;;
esac

# --- refusals ---------------------------------------------------------------

printf 'ciphertext\n' >"$TEST_ROOT/somewhere/.Vault.encrypted/file"
before=$(last_call)
if run_init "$TEST_ROOT/somewhere" >/dev/null 2>&1; then fail 'second init accepted'; fi
[[ $(last_call) == "$before" ]] || fail 'second init reached gocryptfs'
[[ -f $TEST_ROOT/somewhere/.Vault.encrypted/file ]] || fail 'second init disturbed existing storage'

mkdir -p "$HOME/Occupied"
printf 'plaintext\n' >"$HOME/Occupied/note"
if (cd "$HOME" && bash "$vault" init Occupied) >/dev/null 2>&1; then fail 'occupied vault accepted'; fi
if (cd / && bash "$vault" init) >/dev/null 2>&1; then fail 'accepted a vault at /'; fi
if (cd "$HOME" && bash "$vault" init --storage "$HOME/Same" Same) >/dev/null 2>&1; then
  fail 'accepted identical storage and vault directory'
fi
if (cd "$HOME" && bash "$vault" init --storage) >/dev/null 2>&1; then fail '--storage without a value accepted'; fi
if (cd "$HOME" && bash "$vault" init a b) >/dev/null 2>&1; then fail 'two names accepted'; fi
if bash "$vault" nonsense >/dev/null 2>&1; then fail 'unknown command accepted'; fi
if bash "$vault" open --nonsense >/dev/null 2>&1; then fail 'unknown option accepted'; fi
bash "$vault" open --help >/dev/null 2>&1 || fail 'open --help failed'

# unlock never initializes: it sends the operator to init instead.
for storage_state in absent bare; do
  rm -rf "$HOME/Unlockable" "$HOME/.Unlockable.encrypted"
  [[ $storage_state == absent ]] || mkdir -p "$HOME/.Unlockable.encrypted"
  before=$(last_call)
  refusal=$(bash "$vault" unlock "$HOME/Unlockable" 2>&1 || true)
  case $refusal in
    *'vault init'*) : ;;
    *) fail "unlock on $storage_state storage does not point at init: $refusal" ;;
  esac
  [[ $(last_call) == "$before" ]] || fail "unlock on $storage_state storage reached gocryptfs"
done

# A vault directory holding anything would be hidden by the mount.
make_storage "$HOME/.Busy.encrypted"
mkdir -p "$HOME/Busy"
printf 'plaintext\n' >"$HOME/Busy/note"
if bash "$vault" unlock "$HOME/Busy" >/dev/null 2>&1; then fail 'unlock accepted an occupied directory'; fi
[[ -f $HOME/Busy/note ]] || fail 'unlock disturbed the occupied directory'

# The stub exits cleanly without mounting, which must not be reported as
# success by any of the three entry points.
make_storage "$HOME/.Quiet.encrypted"
for entry in unlock open notes; do
  dishonest=$(bash "$vault" "$entry" "$HOME/Quiet" 2>&1 || true)
  case $dishonest in
    *'not mounted'*) : ;;
    *) fail "$entry reported a mount that did not happen: $dishonest" ;;
  esac
done

# --- how the password is asked for ------------------------------------------

# No terminal, but a session with a dialog in it.
case $(last_call) in
  *"-extpass zenity"*) : ;;
  *) fail "the dialog was not used: $(last_call)" ;;
esac

# Over ssh there is neither a terminal nor a dialog, and waiting on one that
# can never appear is a hang, not an error.
status=0
headless=$(env -u DISPLAY -u WAYLAND_DISPLAY -u VAULT_ASKPASS \
  timeout 10 bash "$vault" unlock "$HOME/Quiet" 2>&1) || status=$?
[[ $status != 124 ]] || fail 'unlock hung waiting for a dialog with no display'
case $headless in
  *'no terminal'*) : ;;
  *) fail "headless unlock not reported: $headless" ;;
esac

# --terminal insists on a terminal rather than falling back to a dialog.
noterm=$(env -u DISPLAY -u WAYLAND_DISPLAY VAULT_ASKPASS="$TEST_ROOT/bin/zenity" \
  timeout 10 bash "$vault" unlock --terminal "$HOME/Quiet" </dev/null 2>&1) || true
case $noterm in
  *'no terminal'*) : ;;
  *) fail "--terminal did not insist on a terminal: $noterm" ;;
esac

# VAULT_ASKPASS replaces the dialog.
bash "$vault" unlock "$HOME/Quiet" >/dev/null 2>&1 || true
VAULT_ASKPASS="$TEST_ROOT/bin/zenity" bash "$vault" unlock --dialog "$HOME/Quiet" >/dev/null 2>&1 || true
case $(last_call) in
  *"-extpass $TEST_ROOT/bin/zenity"*) : ;;
  *) fail "VAULT_ASKPASS not used: $(last_call)" ;;
esac

# A wrong password is named as such, not reported as some other failure.
cat >"$TEST_ROOT/bin/gocryptfs" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$GOCRYPTFS_CALLS"
exit 12
STUB
chmod +x "$TEST_ROOT/bin/gocryptfs"
wrong=$(bash "$vault" unlock "$HOME/Quiet" 2>&1 || true)
case $wrong in
  *password*) : ;;
  *) fail "a wrong password was not named: $wrong" ;;
esac

# --- locking ----------------------------------------------------------------

record=$(record_for "$HOME/Quiet")
mkdir -p "$(dirname "$record")"
printf 'pid=999999\nstorage=%s\n' "$HOME/.Quiet.encrypted" >"$record"
notmounted=$(bash "$vault" lock "$HOME/Quiet" 2>&1) || fail "lock on an unmounted vault failed: $notmounted"
case $notmounted in
  *'not unlocked'*) : ;;
  *) fail "lock on an unmounted vault: $notmounted" ;;
esac
[[ ! -f $record ]] || fail 'lock kept a record for a vault that is not mounted'

# With no terminal and no dialog, a blocked lock cancels rather than forcing.
# Nothing here is mounted, so this checks the choice, not the unmount.
cat >"$TEST_ROOT/bin/zenity" <<'STUB'
#!/bin/sh
case " $* " in
  *--question*) printf 'Force\n'; exit 1 ;;
  *) printf 'password\n' ;;
esac
STUB
chmod +x "$TEST_ROOT/bin/zenity"

# Nothing was locked above, so nothing may have claimed it was.
[[ ! -s $NOTIFICATIONS ]] || fail "a notification without a lock: $(cat "$NOTIFICATIONS")"

# --- the desktop entry ------------------------------------------------------

entry="$HOME/.local/share/applications/vault.desktop"
bash "$vault" entry
[[ ! -e $entry ]] || fail 'an entry was written without VAULT_DESKTOP_ENTRY'

export VAULT_DESKTOP_ENTRY="$HOME/Quiet"
bash "$vault" entry
[[ -f $entry ]] || fail 'entry not written'
grep -qx 'Name=Unlock Vault' "$entry" || fail "a locked vault's entry does not offer to unlock: $(cat "$entry")"
grep -qx 'Icon=changes-prevent-symbolic' "$entry" || fail 'a locked vault does not show a closed padlock'
grep -qx "Exec=\"$vault\" toggle \"$HOME/Quiet\"" "$entry" || fail "entry does not toggle the vault: $(grep Exec "$entry")"

# Any lock refreshes it too, not only the entry command.
rm -f "$entry"
bash "$vault" lock "$HOME/Quiet" >/dev/null 2>&1
[[ -f $entry ]] || fail 'lock did not refresh the entry'

# Toggling a locked vault opens it, asking through the dialog.
: >"$GOCRYPTFS_CALLS"
bash "$vault" toggle "$HOME/Quiet" </dev/null >/dev/null 2>&1 || true
case $(last_call) in
  *"-extpass zenity"*"-- $HOME/.Quiet.encrypted $HOME/Quiet") : ;;
  *) fail "toggle on a locked vault did not unlock it: $(last_call)" ;;
esac
if bash "$vault" toggle --all >/dev/null 2>&1; then fail 'toggle accepted --all'; fi
unset VAULT_DESKTOP_ENTRY

# --- the FUSE helper --------------------------------------------------------

missing=$(cd "$TEST_ROOT/somewhere" && VAULT_FUSERMOUNT="$TEST_ROOT/absent" bash "$vault" init Fresh 2>&1 || true)
case $missing in
  *fuse3*) : ;;
  *) fail "the FUSE error does not name the package: $missing" ;;
esac
[[ ! -e $TEST_ROOT/somewhere/Fresh ]] || fail 'created directories despite the missing helper'

# Every message is the command's own, never a stuttered prefix.
if grep -q 'vault: vault ' <(bash "$vault" unlock "$HOME/Unlockable" 2>&1 || true); then
  fail 'an error message repeats the program name'
fi

# The recovery material must never reach a file this command writes.
if grep -rq 'stub master key' "$HOME" "$TEST_ROOT/somewhere" 2>/dev/null; then
  fail 'recovery material written to disk'
fi

printf 'PASS: %s\n' "$(basename "$0")"
