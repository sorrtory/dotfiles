#!/usr/bin/env bash
# Real gocryptfs, real mount, real unmount. Needs the host's FUSE helper and
# the built vault command; tests/vault_test.sh covers everything that can be
# checked without them.
set -euo pipefail
umask 077
: "${VAULT_TEST_COMMAND:?Set VAULT_TEST_COMMAND to the built vault executable}"
command -v script >/dev/null || { echo 'needs script(1) for a pty'; exit 1; }
# This test checks the mount, not the desktop. Left set, open would put a real
# file manager window on the operator's desktop, and a file manager holding the
# test vault open is what stops it being unmounted again.
unset DISPLAY WAYLAND_DISPLAY

root=$(mktemp -d)
mount_dir="$root/Vault"
storage="$root/.Vault.encrypted"
password='manual-test-password'
cleanup() {
  fusermount3 -u -- "$mount_dir" 2>/dev/null || fusermount -u -- "$mount_dir" 2>/dev/null || true
  # Removing the record is 'vault lock''s job; until that exists the test
  # clears its own rather than leaving one behind in the runtime directory.
  rm -f -- "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/vault/$(printf '%s' "$mount_dir" | tr '/' '_')"
  rm -rf -- "$root"
}
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# init needs a terminal, because the master key is shown once and only on one.
(cd "$root" && printf '%s\n' "$password" | "$VAULT_TEST_COMMAND" init) >/dev/null 2>&1 &&
  fail 'init succeeded without a terminal'
[[ ! -e $storage ]] || fail 'init created storage without a terminal'

# notes on a missing vault says what to run rather than doing nothing.
missing=$(cd "$root" && "$VAULT_TEST_COMMAND" notes </dev/null 2>&1) && fail 'notes invented a vault'
case $missing in
  *'vault init'*) : ;;
  *) fail "notes on a missing vault: $missing" ;;
esac

# With no name, the vault is ./Vault in the working directory.
out=$(printf '%s\n%s\n' "$password" "$password" |
  script -qec "cd $root && $VAULT_TEST_COMMAND init" /dev/null 2>&1)
case $out in
  *'master key'*) : ;;
  *) fail 'init did not show the master key on a terminal' ;;
esac
[[ -f $storage/gocryptfs.conf ]] || fail 'init created no filesystem'
grep -q . <<<"$(ls -A "$mount_dir")" && fail 'init mounted the vault'

# With no terminal, the password comes from the dialog gocryptfs is given.
# This stands in for zenity and proves the desktop path without a desktop.
askpass="$root/askpass"
printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$password" >"$askpass"
chmod +x "$askpass"
export VAULT_ASKPASS="$askpass"

# unlock is the gocryptfs routine on its own; open is unlock plus the file
# manager. Both take the same path.
unlocked=$("$VAULT_TEST_COMMAND" unlock "$mount_dir" </dev/null) || fail 'unlock failed'
case $unlocked in
  *'is unlocked'*) : ;;
  *) fail "unlock did not report success: $unlocked" ;;
esac
grep -q "fuse.gocryptfs" <(findmnt -no FSTYPE,TARGET) || fail 'unlock mounted nothing'
"$VAULT_TEST_COMMAND" lock "$mount_dir" </dev/null >/dev/null || fail 'lock after unlock failed'

opened=$("$VAULT_TEST_COMMAND" open "$mount_dir" </dev/null) ||
  fail 'open failed'
case $opened in
  *'No graphical session'*) : ;;
  *) fail "open tried to reach a desktop this test does not have: $opened" ;;
esac
grep -q "fuse.gocryptfs" <(findmnt -no FSTYPE,TARGET) || fail 'nothing is mounted'
printf 'secret\n' >"$mount_dir/note"
[[ $(cat "$mount_dir/note") == secret ]] || fail 'plaintext is not readable through the mount'
if grep -rq secret "$storage" 2>/dev/null; then fail 'plaintext is readable in the storage'; fi
[[ $(find "$storage" -type f ! -name 'gocryptfs.*' | wc -l) -ge 1 ]] || fail 'nothing was encrypted'

# A path is optional: with none, the vault is ./Vault where the command runs.
implied=$(cd "$root" && "$VAULT_TEST_COMMAND" unlock </dev/null 2>&1) || fail "implied path failed: $implied"
case $implied in
  *"$mount_dir"*) : ;;
  *) fail "an omitted path did not mean ./Vault: $implied" ;;
esac

# A second open reuses the mount rather than stacking another one.
before=$(grep -c "$mount_dir" /proc/self/mountinfo)
reuse=$("$VAULT_TEST_COMMAND" open "$mount_dir" </dev/null 2>&1) || fail 'reuse failed'
case $reuse in
  *'already unlocked'*) : ;;
  *) fail "second open did not report reuse: $reuse" ;;
esac
[[ $(grep -c "$mount_dir" /proc/self/mountinfo) == "$before" ]] || fail 'second open stacked a mount'
[[ $(cat "$mount_dir/note") == secret ]] || fail 'reuse broke the mount'

# The runtime record points at the process that actually owns the mount.
record="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/vault/$(printf '%s' "$mount_dir" | tr '/' '_')"
[[ -f $record ]] || fail 'no runtime record'
pid=$(sed -n 's/^pid=//p' "$record")
[[ -n $pid ]] || fail 'runtime record has no pid'
tr '\0' ' ' </proc/"$pid"/cmdline | grep -q gocryptfs || fail 'runtime record names the wrong process'

# open never initializes, so a vault that was never created stays uncreated.
if "$VAULT_TEST_COMMAND" open "$root/Second" </dev/null >/dev/null 2>&1; then
  fail 'open accepted a vault that was never initialized'
fi

# notes creates Notes/ inside the mount on first use.
"$VAULT_TEST_COMMAND" notes "$mount_dir" </dev/null >/dev/null || fail 'notes failed'
[[ -d $mount_dir/Notes ]] || fail 'notes did not create Notes/'
if grep -rq Notes "$storage" 2>/dev/null; then fail 'the notes directory name is readable in the storage'; fi

# A wrong password is refused, and the vault stays as it was.
wrong="$root/wrong-askpass"
printf '#!/bin/sh\nprintf "not-the-password\\n"\n' >"$wrong"
chmod +x "$wrong"
mkdir -p "$root/Other"
cp -a "$storage" "$root/.Other.encrypted"
if VAULT_ASKPASS="$wrong" "$VAULT_TEST_COMMAND" open "$root/Other" </dev/null >/dev/null 2>&1; then
  fail 'a wrong password was accepted'
fi
grep -q "$root/Other " /proc/self/mountinfo && fail 'a refused unlock left a mount'

# --- locking ---------------------------------------------------------------

# Nothing is holding the vault, so it closes on its own.
"$VAULT_TEST_COMMAND" open "$mount_dir" </dev/null >/dev/null || fail 'reopen failed'
locked=$("$VAULT_TEST_COMMAND" lock "$mount_dir" </dev/null 2>&1) || fail "lock failed: $locked"
case $locked in
  *'is locked'*) : ;;
  *) fail "lock did not report success: $locked" ;;
esac
grep -q " $mount_dir " /proc/self/mountinfo && fail 'lock left the mount'
pgrep -f "gocryptfs.*$mount_dir" >/dev/null && fail 'lock left the daemon running'
[[ ! -f $record ]] || fail 'lock left its runtime record'
[[ -z $(ls -A "$mount_dir") ]] || fail 'the plaintext is still visible'

# Locking a vault that is not unlocked is not an error.
again=$("$VAULT_TEST_COMMAND" lock "$mount_dir" </dev/null 2>&1) || fail 'lock on a locked vault failed'
case $again in
  *'not unlocked'*) : ;;
  *) fail "lock on a locked vault: $again" ;;
esac

# Now the case that matters: something holding the vault open.
"$VAULT_TEST_COMMAND" open "$mount_dir" </dev/null >/dev/null || fail 'reopen failed'
sleep 0.2
holder_out="$root/holder.out"
setsid sh -c "cd '$mount_dir' && exec sleep 300" >"$holder_out" 2>&1 &
holder=$!
sleep 0.5
blocked=$(printf 'c\n' | "$VAULT_TEST_COMMAND" lock "$mount_dir" 2>&1) && fail 'lock claimed success while blocked'
case $blocked in
  *'Still holding it'*) : ;;
  *) fail "blockers not named: $blocked" ;;
esac
case $blocked in
  *'Unsaved edits'*) : ;;
  *) fail "the cost of forcing was not explained: $blocked" ;;
esac
case $blocked in
  *'still unlocked'*) : ;;
  *) fail "cancelling did not report the vault as unlocked: $blocked" ;;
esac
grep -q " $mount_dir " /proc/self/mountinfo || fail 'cancelling unmounted the vault anyway'
[[ $(cat "$mount_dir/note") == secret ]] || fail 'cancelling broke the mount'

# Forcing, confirmed for this attempt, ends access despite the holder.
forced=$(printf 'f\n' | "$VAULT_TEST_COMMAND" lock "$mount_dir" 2>&1) || fail "force failed: $forced"
grep -q " $mount_dir " /proc/self/mountinfo && fail 'force left the mount'
pgrep -f "gocryptfs.*$mount_dir" >/dev/null && fail 'force left the daemon serving the holder'
kill "$holder" 2>/dev/null || true

# --force locks without asking, for a session ending with nobody there.
"$VAULT_TEST_COMMAND" open "$mount_dir" </dev/null >/dev/null || fail 'reopen failed'
sleep 0.2
setsid sh -c "cd '$mount_dir' && exec sleep 300" >/dev/null 2>&1 &
holder=$!
sleep 0.5
"$VAULT_TEST_COMMAND" lock --force "$mount_dir" </dev/null >/dev/null || fail '--force failed'
grep -q " $mount_dir " /proc/self/mountinfo && fail '--force left the mount'
kill "$holder" 2>/dev/null || true

# The blocked question can be answered without a terminal. A stub dialog says
# Force, the way the Lock Vault entry's would when the operator clicks it.
"$VAULT_TEST_COMMAND" unlock "$mount_dir" </dev/null >/dev/null || fail 'reopen failed'
sleep 0.2
setsid sh -c "cd '$mount_dir' && exec sleep 300" >/dev/null 2>&1 &
holder=$!
sleep 0.5
dialog="$root/forcing-dialog"
printf '#!/bin/sh\nprintf "Force\\n"\nexit 1\n' >"$dialog"
chmod +x "$dialog"
mkdir -p "$root/fakebin"
cp "$dialog" "$root/fakebin/zenity"
DISPLAY=:99 PATH="$root/fakebin:$PATH" "$VAULT_TEST_COMMAND" lock "$mount_dir" </dev/null >/dev/null 2>&1 ||
  fail 'a dialog answer of Force did not lock'
grep -q " $mount_dir " /proc/self/mountinfo && fail 'the dialog force left the mount'
kill "$holder" 2>/dev/null || true

# A dialog that cancels leaves the vault alone.
"$VAULT_TEST_COMMAND" unlock "$mount_dir" </dev/null >/dev/null || fail 'reopen failed'
sleep 0.2
setsid sh -c "cd '$mount_dir' && exec sleep 300" >/dev/null 2>&1 &
holder=$!
sleep 0.5
printf '#!/bin/sh\nexit 1\n' >"$root/fakebin/zenity"
DISPLAY=:99 PATH="$root/fakebin:$PATH" "$VAULT_TEST_COMMAND" lock "$mount_dir" </dev/null >/dev/null 2>&1 &&
  fail 'a cancelled dialog reported a lock'
grep -q " $mount_dir " /proc/self/mountinfo || fail 'a cancelled dialog unmounted the vault anyway'
[[ $(cat "$mount_dir/note") == secret ]] || fail 'a cancelled dialog broke the mount'
kill "$holder" 2>/dev/null || true
"$VAULT_TEST_COMMAND" lock --force "$mount_dir" </dev/null >/dev/null || fail 'cleanup lock failed'

# --all locks what the session unlocked, from the records it kept.
"$VAULT_TEST_COMMAND" unlock "$mount_dir" </dev/null >/dev/null || fail 'reopen failed'
[[ -f $record ]] || fail 'no runtime record to lock from'
grep -q "^mount=$mount_dir$" "$record" || fail 'the record does not name its mount'
"$VAULT_TEST_COMMAND" lock --all --force </dev/null >/dev/null || fail '--all failed'
grep -q " $mount_dir " /proc/self/mountinfo && fail '--all left the mount'
[[ ! -f $record ]] || fail '--all left its record'

# A record naming a vault nobody mounted is dropped rather than acted on.
printf 'pid=999999\nmount=%s\nstorage=%s\n' "$root/Ghost" "$root/.Ghost.encrypted" >"$(dirname "$record")/ghost-test"
"$VAULT_TEST_COMMAND" lock --all --force </dev/null >/dev/null || fail '--all failed on a stale record'
[[ ! -f $(dirname "$record")/ghost-test ]] || fail '--all kept a stale record'

cleanup
trap - EXIT
printf 'PASS: %s\n' "$(basename "$0")"
