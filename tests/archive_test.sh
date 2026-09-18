#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
archive="$REPO_ROOT/scripts/bin/archive.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

mkdir -p "$HOME/Downloads/nested/empty"
printf 'data\n' >"$HOME/Downloads/nested/a file"
printf 'hidden\n' >"$HOME/Downloads/.hidden"
ln -s missing "$HOME/Downloads/link"
ln "$HOME/Downloads/nested/a file" "$HOME/Downloads/hardlink"
bash "$archive" --force "$HOME/Downloads"
destinations=("$HOME"/Archive/Downloads/*)
destination=${destinations[0]}
[[ $(cat "$destination/nested/a file") == data ]] || fail 'file contents'
[[ -f $destination/.hidden && -L $destination/link ]] || fail 'hidden file or symlink'
[[ $destination/hardlink -ef "$destination/nested/a file" ]] || fail 'hard links'
[[ -d $destination/nested/empty ]] || fail 'empty directory not preserved'
[[ -d $HOME/Downloads && -z $(ls -A "$HOME/Downloads") ]] || fail 'source not emptied'

# The destination is named after the time and nothing else. A random suffix
# is what made an archive unreadable and looked like something temporary.
[[ $(basename "$destination") =~ ^[0-9]{4}(-[0-9]{2}){2}_[0-9]{2}(-[0-9]{2}){2}$ ]] ||
  fail "destination is not a plain timestamp: $(basename "$destination")"

printf 'second\n' >"$HOME/Downloads/.hidden"
bash "$archive" --force "$HOME/Downloads"
destinations=("$HOME"/Archive/Downloads/*)
[[ ${#destinations[@]} == 2 ]] || fail 'archives merged'
[[ $(cat "$destination/.hidden") == hidden ]] || fail 'previous archive overwritten'

# Two runs inside one second still may not merge: the later one is suffixed.
collision_checked=0
for _ in 1 2 3; do
  rm -rf -- "$HOME/Collide" "$HOME/Archive/Collide"
  mkdir -p "$HOME/Collide"
  printf 'keep\n' >"$HOME/Collide/file"
  stamp=$(date +%Y-%m-%d_%H-%M-%S)
  mkdir -p "$HOME/Archive/Collide/$stamp"
  bash "$archive" --force "$HOME/Collide" >/dev/null
  [[ $stamp == $(date +%Y-%m-%d_%H-%M-%S) ]] || continue
  [[ -f $HOME/Archive/Collide/$stamp-2/file ]] || fail 'collision was not suffixed'
  [[ -z $(ls -A "$HOME/Archive/Collide/$stamp") ]] || fail 'collision merged'
  collision_checked=1
  break
done
((collision_checked == 1)) || fail 'never observed two runs in one second'

# --- the safety gate ---------------------------------------------------------

mkdir -p "$HOME/Ask/sub"
printf 'keep\n' >"$HOME/Ask/file"

# The plan names what moves, how much of it, and where, before anything moves.
plan=$(bash "$archive" "$HOME/Ask" </dev/null 2>/dev/null) || fail 'plan run failed'
[[ $plan == *"$HOME/Ask"* ]] || fail 'plan omits the source'
[[ $plan == *"$HOME/Archive/Ask/"* ]] || fail 'plan omits the destination'
[[ $plan == *file* && $plan == *sub/* ]] || fail 'plan omits the contents'
[[ $plan == *'2 items'* ]] || fail 'plan omits the item count'
plan_total='2 items, [0-9]'
[[ $plan =~ $plan_total ]] || fail 'plan omits the total size'

# End of input is a No, so an unattended run archives nothing.
[[ -f $HOME/Ask/file ]] || fail 'end of input moved data'
[[ ! -e $HOME/Archive/Ask ]] || fail 'end of input left an archive directory'

printf 'n\n' | bash "$archive" "$HOME/Ask" >/dev/null 2>&1
[[ -f $HOME/Ask/file && -d $HOME/Ask/sub ]] || fail 'declining moved data'
[[ ! -e $HOME/Archive/Ask ]] || fail 'declining left an archive directory'

# Accepting archives, and says how much it moved while doing it.
moved=$(printf 'y\n' | bash "$archive" "$HOME/Ask" 2>/dev/null | tail -1)
size_line='^Archiving [0-9.]+[KMGT]? to /'
[[ $moved =~ $size_line ]] || fail "move line omits the size: $moved"
[[ ! -e $HOME/Ask/file ]] || fail 'accepting did not archive'
destinations=("$HOME"/Archive/Ask/*)
[[ $(cat "${destinations[0]}/file") == keep ]] || fail 'accepting lost data'

# --force reports the size too: it is the only output that run produces.
mkdir -p "$HOME/Forced"
head -c 200000 /dev/urandom >"$HOME/Forced/blob.bin"
forced=$(bash "$archive" --force "$HOME/Forced")
[[ $forced == *'196K'* ]] || fail "forced move omits the size: $forced"

# An empty source is not an archive, and must not leave one behind.
mkdir -p "$HOME/Empty"
bash "$archive" --force "$HOME/Empty" >/dev/null
[[ ! -e $HOME/Archive/Empty ]] || fail 'archived an empty directory'

if bash "$archive" --wat "$HOME/Ask" >/dev/null 2>&1; then fail 'accepted unknown option'; fi

# --- the archive root -------------------------------------------------------

# ARCHIVE_ROOT redirects the destination, and --to beats it.
mkdir -p "$HOME/Rooted"; printf 'r\n' >"$HOME/Rooted/file"
ARCHIVE_ROOT="$TEST_ROOT/elsewhere" bash "$archive" --force "$HOME/Rooted" >/dev/null
compgen -G "$TEST_ROOT/elsewhere/Rooted/*/file" >/dev/null || fail 'ARCHIVE_ROOT ignored'

mkdir -p "$HOME/Rooted"; printf 'r\n' >"$HOME/Rooted/file"
ARCHIVE_ROOT="$TEST_ROOT/elsewhere" bash "$archive" --force --to "$TEST_ROOT/chosen" "$HOME/Rooted" >/dev/null
compgen -G "$TEST_ROOT/chosen/Rooted/*/file" >/dev/null || fail '--to did not win over ARCHIVE_ROOT'

# --- move mechanics ----------------------------------------------------------

# Within one filesystem a move is rename(2), so inodes survive. A copy would
# allocate new ones, which is what made the old rsync-always path slow.
mkdir -p "$HOME/Rename"; printf 'keep\n' >"$HOME/Rename/file"
before_inode=$(stat -c %i "$HOME/Rename/file")
bash "$archive" --force "$HOME/Rename" >/dev/null
renamed=("$HOME"/Archive/Rename/*)
[[ $(stat -c %i "${renamed[0]}/file") == "$before_inode" ]] ||
  fail 'same-filesystem move copied instead of renaming'

# Hard links still survive a same-filesystem move.
mkdir -p "$HOME/Linked"; printf 'x\n' >"$HOME/Linked/a"; ln "$HOME/Linked/a" "$HOME/Linked/b"
bash "$archive" --force "$HOME/Linked" >/dev/null
linked=("$HOME"/Archive/Linked/*)
[[ ${linked[0]}/a -ef ${linked[0]}/b ]] || fail 'move lost hard links'

# Across filesystems the source survives until verification passes.
if [[ -w /dev/shm ]]; then
  cross=$(mktemp -d /dev/shm/archive-test.XXXXXX)
  trap 'rm -rf -- "$TEST_ROOT" "$cross"' EXIT
  [[ $(stat -c %d "$cross") != $(stat -c %d "$HOME") ]] || fail 'no second filesystem to test with'
  mkdir -p "$HOME/Crossed/sub"; printf 'c\n' >"$HOME/Crossed/file"
  out=$(bash "$archive" --force --to "$cross" "$HOME/Crossed")
  compgen -G "$cross/Crossed/*/file" >/dev/null || fail 'cross-device archive missing'
  [[ -z $(ls -A "$HOME/Crossed") ]] || fail 'cross-device source not emptied after verify'
  [[ $out == *filesystem* ]] || fail "cross-device run did not mention the filesystem: $out"

  # A file arriving after verification belongs to the next run. It must remain
  # in the live source rather than being deleted with the frozen entries.
  real_rsync=$(command -v rsync)
  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/rsync" <<'STUB'
#!/usr/bin/env bash
dry=0
for arg in "$@"; do [[ $arg == --dry-run ]] && dry=1; done
"$REAL_RSYNC" "$@" || exit
if ((dry == 1)); then printf 'late\n' >"$LATE_SOURCE/late.txt"; fi
STUB
  chmod +x "$TEST_ROOT/bin/rsync"
  mkdir -p "$HOME/Crossed"; printf 'first\n' >"$HOME/Crossed/first.txt"
  REAL_RSYNC=$real_rsync LATE_SOURCE="$HOME/Crossed" PATH="$TEST_ROOT/bin:$PATH" \
    bash "$archive" --force --to "$cross" "$HOME/Crossed" >/dev/null
  [[ -f $HOME/Crossed/late.txt ]] || fail 'cross-device run deleted a late source file'
  crossed=("$cross"/Crossed/*)
  latest_crossed=${crossed[${#crossed[@]} - 1]}
  [[ ! -e $latest_crossed/late.txt && -f $latest_crossed/first.txt ]] ||
    fail 'cross-device archive did not use the frozen source set'
  rm -f "$TEST_ROOT/bin/rsync"
else
  fail 'this test needs a writable /dev/shm to exercise the cross-device path'
fi

# --- compression -------------------------------------------------------------

command -v 7zz >/dev/null ||
  fail 'this test needs 7zz from the _7zz package'

# -z writes one .7z, and extracting it reproduces the tree.
mkdir -p "$HOME/Zipped/sub"
printf 'alpha\n' >"$HOME/Zipped/a.txt"
printf 'beta\n' >"$HOME/Zipped/sub/b.txt"
printf 'hidden\n' >"$HOME/Zipped/.dot"
bash "$archive" --force -z "$HOME/Zipped" >/dev/null
archives=("$HOME"/Archive/Zipped/*.7z)
[[ ${#archives[@]} == 1 ]] || fail "expected one .7z, found ${#archives[@]}"
[[ -z $(ls -A "$HOME/Zipped") ]] || fail 'compression did not empty the source'
mkdir -p "$TEST_ROOT/out" && (cd "$TEST_ROOT/out" && 7zz x -snl -y "${archives[0]}" </dev/null >/dev/null)
[[ $(cat "$TEST_ROOT/out/a.txt") == alpha ]] || fail 'archive lost a file'
[[ $(cat "$TEST_ROOT/out/sub/b.txt") == beta ]] || fail 'archive lost a nested file'
[[ $(cat "$TEST_ROOT/out/.dot") == hidden ]] || fail 'archive lost a hidden file'

# As with a cross-device copy, an entry created after the frozen set is built
# stays in the source for a later run.
real_7zz=$(command -v 7zz)
cat >"$TEST_ROOT/bin/7zz" <<'STUB'
#!/usr/bin/env bash
op=$1
"$REAL_7ZZ" "$@" || exit
if [[ $op == a ]]; then printf 'late\n' >"$LATE_SOURCE/late.txt"; fi
STUB
chmod +x "$TEST_ROOT/bin/7zz"
mkdir -p "$HOME/LiveZip"; printf 'first\n' >"$HOME/LiveZip/first.txt"
REAL_7ZZ=$real_7zz LATE_SOURCE="$HOME/LiveZip" PATH="$TEST_ROOT/bin:$PATH" \
  bash "$archive" --force -z "$HOME/LiveZip" >/dev/null
[[ -f $HOME/LiveZip/late.txt ]] || fail 'compression deleted a late source file'
live_archives=("$HOME"/Archive/LiveZip/*.7z)
live_listing=$($real_7zz l -snl "${live_archives[0]}" </dev/null)
[[ $live_listing == *first.txt* && $live_listing != *late.txt* ]] ||
  fail 'compressed archive did not use the frozen source set'
rm -f "$TEST_ROOT/bin/7zz"

# Measurement and movement stay NUL-delimited, so a newline in a legal Unix
# filename neither crashes arithmetic parsing nor splits the entry.
mkdir -p "$HOME/Newline"
newline_name=$'line\nbreak'
printf 'odd\n' >"$HOME/Newline/$newline_name"
bash "$archive" --force "$HOME/Newline" >/dev/null
newline_archives=("$HOME"/Archive/Newline/*)
[[ -f ${newline_archives[0]}/$newline_name ]] || fail 'newline filename was not archived'

# A second archive in the same second is a separate file, never a merge.
# 7zz a merges into an existing archive silently, so this is the guard.
collision_checked=0
for _ in 1 2 3; do
  rm -rf -- "$HOME/Zipped" "$HOME/Archive/Zipped"
  mkdir -p "$HOME/Zipped"; printf 'first\n' >"$HOME/Zipped/one.txt"
  stamp=$(date +%Y-%m-%d_%H-%M-%S)
  bash "$archive" --force -z "$HOME/Zipped" >/dev/null
  mkdir -p "$HOME/Zipped"; printf 'second\n' >"$HOME/Zipped/two.txt"
  bash "$archive" --force -z "$HOME/Zipped" >/dev/null
  [[ $stamp == $(date +%Y-%m-%d_%H-%M-%S) ]] || continue
  [[ -f $HOME/Archive/Zipped/$stamp.7z && -f $HOME/Archive/Zipped/$stamp-2.7z ]] ||
    fail 'second archive in one second did not get its own name'
  for which in "$stamp" "$stamp-2"; do
    rm -rf "$TEST_ROOT/collide" && mkdir -p "$TEST_ROOT/collide"
    (cd "$TEST_ROOT/collide" && 7zz x -y "$HOME/Archive/Zipped/$which.7z" </dev/null >/dev/null)
    case $which in
      "$stamp")
        [[ -f $TEST_ROOT/collide/one.txt && ! -e $TEST_ROOT/collide/two.txt ]] ||
          fail 'the first archive absorbed the second run' ;;
      *)
        [[ -f $TEST_ROOT/collide/two.txt && ! -e $TEST_ROOT/collide/one.txt ]] ||
          fail 'the second archive absorbed the first run' ;;
    esac
  done
  collision_checked=1
  break
done
((collision_checked == 1)) || fail 'never observed two compressed runs in one second'

# The symlink policy: in-tree links stay links, qualifying out-of-tree links
# become real files, and everything else stays a link.
rm -rf -- "$HOME/Links" "$HOME/Archive/Links"
mkdir -p "$HOME/Links/sub" "$HOME/Outside"
printf 'inside\n' >"$HOME/Links/target.txt"
printf 'outside\n' >"$HOME/Outside/far.txt"
ln -s target.txt "$HOME/Links/in.link"
ln -s "$HOME/Outside/far.txt" "$HOME/Links/out.link"
ln -s "$HOME/Outside" "$HOME/Links/dir.link"
ln -s /etc/hostname "$HOME/Links/system.link"
ln -s /nonexistent/nope "$HOME/Links/dangling.link"
ln -s .. "$HOME/Links/up.link"
plan=$(bash "$archive" -z "$HOME/Links" </dev/null 2>/dev/null) || fail 'symlink plan failed'
for named in out.link dir.link system.link dangling.link; do
  [[ $plan == *"$named"* ]] || fail "plan does not name the out-of-tree link: $named"
done
[[ $plan == *'copied in'* && $plan == *'kept as a link'* ]] ||
  fail 'plan does not say which out-of-tree links are resolved'
bash "$archive" --force -z "$HOME/Links" >/dev/null
links=("$HOME"/Archive/Links/*.7z)
rm -rf "$TEST_ROOT/links" && mkdir -p "$TEST_ROOT/links"
# 7z refuses to extract a link pointing above the extraction root, so up.link
# is asserted on the listing instead: stored as an entry, never walked into.
listing=$(7zz l -snl "${links[0]}" </dev/null)
[[ $listing == *up.link* ]] || fail 'parent symlink missing from the archive'
[[ $listing != *up.link/* ]] || fail 'parent symlink was followed'
[[ $(grep -c 'target\.txt' <<<"$listing") == 1 ]] || fail 'archive duplicated the in-tree target'
(cd "$TEST_ROOT/links" && 7zz x -snl -y "${links[0]}" </dev/null >/dev/null 2>&1) || true
[[ -L $TEST_ROOT/links/in.link ]] || fail 'in-tree symlink was not kept as a symlink'
[[ -f $TEST_ROOT/links/out.link && ! -L $TEST_ROOT/links/out.link ]] ||
  fail 'qualifying out-of-tree symlink was not resolved into a file'
[[ $(cat "$TEST_ROOT/links/out.link") == outside ]] || fail 'resolved link has wrong contents'
[[ -L $TEST_ROOT/links/dir.link ]] || fail 'directory symlink was followed'
[[ -L $TEST_ROOT/links/system.link ]] || fail 'symlink outside the home directory was followed'
[[ -L $TEST_ROOT/links/dangling.link ]] || fail 'dangling symlink was followed'
[[ ! -e $TEST_ROOT/links/nope && ! -e $TEST_ROOT/links/far.txt ]] ||
  fail 'archive escaped the source tree'

# --- encryption --------------------------------------------------------------

mkdir -p "$TEST_ROOT/bin"
printf '#!/bin/sh\nprintf "%%s\\n" correct-horse\n' >"$TEST_ROOT/bin/askpass"
chmod +x "$TEST_ROOT/bin/askpass"

mkdir -p "$HOME/Secret"
printf 'classified\n' >"$HOME/Secret/notes.txt"
ARCHIVE_ASKPASS="$TEST_ROOT/bin/askpass" bash "$archive" --force -e "$HOME/Secret" >/dev/null
secrets=("$HOME"/Archive/Secret/*.7z)
[[ ${#secrets[@]} == 1 ]] || fail '--encrypt did not imply --compress'
[[ -z $(ls -A "$HOME/Secret") ]] || fail 'encrypted archive did not empty the source'

# Header encryption: the file names are unreadable without the password.
if 7zz l "${secrets[0]}" </dev/null >/dev/null 2>&1; then fail 'archive listed without a password'; fi
7zz l -p'correct-horse' "${secrets[0]}" </dev/null | grep -q 'notes\.txt' ||
  fail 'archive does not open with the right password'
if 7zz t -p'wrong' "${secrets[0]}" </dev/null >/dev/null 2>&1; then fail 'wrong password accepted'; fi

rm -rf "$TEST_ROOT/secret" && mkdir -p "$TEST_ROOT/secret"
(cd "$TEST_ROOT/secret" && 7zz x -y -p'correct-horse' "${secrets[0]}" </dev/null >/dev/null)
[[ $(cat "$TEST_ROOT/secret/notes.txt") == classified ]] || fail 'encrypted round-trip lost data'

# An askpass that prints nothing must not produce an unencrypted archive.
printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/bin/emptypass"
chmod +x "$TEST_ROOT/bin/emptypass"
mkdir -p "$HOME/Secret"; printf 'x\n' >"$HOME/Secret/again.txt"
if ARCHIVE_ASKPASS="$TEST_ROOT/bin/emptypass" bash "$archive" --force -e "$HOME/Secret" >/dev/null 2>&1; then
  fail 'empty password accepted'
fi
[[ -f $HOME/Secret/again.txt ]] || fail 'empty password still consumed the source'

# The password is typed twice and compared, because 7z asks once with no
# confirmation and a typo would produce an archive nobody could ever open.
command -v python3 >/dev/null || fail 'this test needs python3 to drive a terminal'
ask_on_tty() {
  python3 - "$archive" "$1" "$2" "$3" <<'PYTTY'
import os, pty, re, select, signal, sys, time

archive, source, first, second = sys.argv[1:5]
pid, fd = pty.fork()
if pid == 0:
    os.execv("/bin/bash", ["bash", archive, "--force", "-e", source])

buf, pending, deadline = b"", [first, second], time.time() + 25
while time.time() < deadline:
    r, _, _ = select.select([fd], [], [], 1)
    if r:
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        buf += chunk
    seen = len(re.findall(rb"Password:|Repeat:", buf))
    while pending and (2 - len(pending)) < seen:
        os.write(fd, pending.pop(0).encode() + b"\n")

try:
    done, status = os.waitpid(pid, os.WNOHANG)
    if done == 0:
        os.kill(pid, signal.SIGKILL)
        _, status = os.waitpid(pid, 0)
except ChildProcessError:
    status = 0
sys.stdout.write(buf.decode(errors="replace"))
sys.exit(os.waitstatus_to_exitcode(status))
PYTTY
}
mkdir -p "$HOME/Typo"; printf 'precious\n' >"$HOME/Typo/file"
if ask_on_tty "$HOME/Typo" 'one-password' 'another-password' >/dev/null 2>&1; then
  fail 'mismatched passwords were accepted'
fi
[[ -f $HOME/Typo/file ]] || fail 'mismatched passwords still consumed the source'
[[ ! -e $HOME/Archive/Typo ]] || fail 'mismatched passwords left an archive'
ask_on_tty "$HOME/Typo" 'same-password' 'same-password' >/dev/null 2>&1 ||
  fail 'matching passwords were rejected'
typos=("$HOME"/Archive/Typo/*.7z)
7zz l -p'same-password' "${typos[0]}" </dev/null | grep -q file || fail 'terminal password did not reach 7z'

# An archiver that fails must leave the tree as it found it. This is the guard
# for a second EXIT trap replacing the first and dropping the reservation.
mkdir -p "$TEST_ROOT/bin"
printf '#!/bin/sh\nexit 2\n' >"$TEST_ROOT/bin/7zz"
chmod +x "$TEST_ROOT/bin/7zz"
mkdir -p "$HOME/Broken"; printf 'x\n' >"$HOME/Broken/file"
if PATH="$TEST_ROOT/bin:$PATH" bash "$archive" --force -z "$HOME/Broken" >/dev/null 2>&1; then
  fail 'hid an archiver failure'
fi
[[ -f $HOME/Broken/file ]] || fail 'archiver failure lost source data'
[[ ! -e $HOME/Archive/Broken ]] || fail 'archiver failure left an empty archive directory'

# A written archive that does not verify keeps both the source and the archive,
# so the operator chooses which to discard.
cat >"$TEST_ROOT/bin/7zz" <<'STUB'
#!/bin/sh
op=$1
shift
for arg in "$@"; do
  case "$arg" in *.7z) target=$arg ;; esac
done
case "$op" in
  a) : >"$target"; exit 0 ;;
  t) exit 2 ;;
esac
exit 0
STUB
chmod +x "$TEST_ROOT/bin/7zz"
if PATH="$TEST_ROOT/bin:$PATH" bash "$archive" --force -z "$HOME/Broken" >/dev/null 2>&1; then
  fail 'accepted an archive that did not verify'
fi
[[ -f $HOME/Broken/file ]] || fail 'failed verification removed source data'
compgen -G "$HOME/Archive/Broken/*.7z" >/dev/null ||
  fail 'failed verification discarded the archive'
rm -f "$TEST_ROOT/bin/7zz"
rm -rf "$HOME/Archive/Broken"

# --- refusals ----------------------------------------------------------------

for source in / "$HOME" "$HOME/Archive" "$destination"; do
  if bash "$archive" --force "$source" >/dev/null 2>&1; then fail "accepted unsafe source: $source"; fi
done
ln -s "$HOME/Archive" "$TEST_ROOT/archive-link"
if bash "$archive" --force "$TEST_ROOT/archive-link" >/dev/null 2>&1; then fail 'accepted archive symlink'; fi

# A failed transfer must not remove anything. rsync is only reached across
# filesystems now, so the stub has to be exercised there.
mkdir -p "$TEST_ROOT/bin" "$HOME/Failed/empty"
printf 'keep\n' >"$HOME/Failed/file"
printf '#!/bin/sh\nexit 23\n' >"$TEST_ROOT/bin/rsync"
chmod +x "$TEST_ROOT/bin/rsync"
if PATH="$TEST_ROOT/bin:$PATH" bash "$archive" --force --to "$cross" "$HOME/Failed"; then
  fail 'hid rsync failure'
fi
[[ -f $HOME/Failed/file && -d $HOME/Failed/empty ]] || fail 'failure lost source data'

# A verification command that fails is not an empty successful comparison.
cat >"$TEST_ROOT/bin/rsync" <<'STUB'
#!/bin/sh
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then exit 23; fi
done
exit 0
STUB
chmod +x "$TEST_ROOT/bin/rsync"
if PATH="$TEST_ROOT/bin:$PATH" bash "$archive" --force --to "$cross" "$HOME/Failed"; then
  fail 'accepted a failed verification command'
fi
[[ -f $HOME/Failed/file ]] || fail 'verification error removed source data'

# A copy that does not match the source must leave the source alone. The stub
# reports success for the transfer and a difference for the verification pass.
cat >"$TEST_ROOT/bin/rsync" <<'STUB'
#!/bin/sh
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then printf '>f..c...... file\n'; exit 0; fi
done
exit 0
STUB
chmod +x "$TEST_ROOT/bin/rsync"
if PATH="$TEST_ROOT/bin:$PATH" bash "$archive" --force --to "$cross" "$HOME/Failed"; then
  fail 'accepted a copy that did not verify'
fi
[[ -f $HOME/Failed/file ]] || fail 'failed verification removed source data'

printf 'archive tests passed\n'
