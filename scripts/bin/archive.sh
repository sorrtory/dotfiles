#!/usr/bin/env bash
set -euo pipefail

# Enough of the listing to recognise what is about to move. The rest is a
# count: a screen of filenames is not more informative than "and 412 more".
readonly MAX_LISTED=6
# A timestamp is unique until two runs share a second. After that, a suffix.
readonly MAX_ATTEMPTS=99

# --- saying things ---------------------------------------------------------------

usage() {
  cat <<'USAGE'
Usage: archive [--force] [--compress] [--encrypt] [--to DIR] [DIRECTORY]

Move a directory's contents, including hidden files, into
<root>/<name>/<date-and-time>/. The directory itself stays where it is.

The root is --to when given, else $ARCHIVE_ROOT, else ~/Archive. Installed
through Home Manager, ARCHIVE_ROOT carries dotfiles.archive.root unless the
caller has set it.

  --force, -f     Archive without asking, for scripts and keybindings, where
                  there is nobody to answer. It never skips the password.
  --compress, -z  Write one <date-and-time>.7z instead of a directory.
  --encrypt, -e   Encrypt the archive and its file names. Implies --compress,
                  and asks for the password on the terminal, twice.
  --to DIR        Archive into DIR instead of the configured root.

It shows what is about to move, how much of it there is, and where it lands,
then waits for an answer. The answer can be piped in; end of input cancels, so
a run with nobody watching archives nothing rather than something unintended.

Within one filesystem a move is rename(2), so it is instant at any size and
hard links survive. Across filesystems it copies, verifies the copy against
the source, and only then removes the source.

Compression cannot preserve hard links, which no archive format stores. A
symlink pointing inside the archived directory stays a symlink, because it
still resolves once extracted; one pointing outside is resolved into a real
file when its target is a regular file under $HOME on the same filesystem, so
that the archive stands alone. Anything else stays a symlink and is named in
the plan.

Each run archives under its own name: a second run in the same second is given
a -2 suffix rather than merging into the first.

ARCHIVE_ROOT sets the root when --to does not. ARCHIVE_ASKPASS replaces the
terminal prompt with a command that prints the password, for an encrypted
archive made by a script rather than by hand.
USAGE
}

die() {
  printf 'archive: %s\n' "$1" >&2
  exit 1
}

usage_error() {
  printf 'archive: %s\n' "$1" >&2
  usage >&2
  exit 2
}

# Progress bars belong on a terminal someone is reading. --force is the
# scripts-and-keybindings path, where they land in a log as thousands of
# carriage-returned lines.
interactive() {
  ((force == 0)) && [[ -t 1 ]]
}

human() {
  numfmt --to=iec -- "$1"
}

require_archiver() {
  command -v 7zz >/dev/null && return 0
  die 'no 7zz found. Compressed archives need 7-Zip, which Nix packages as _7zz. Install it, or archive without --compress.'
}

# --- deciding about symlinks -----------------------------------------------------

# A symlink is resolved into a real file only when all three hold. Each one
# rules out a different way of pulling in more than was asked for: a directory
# target would be walked into, a target outside $HOME is not the operator's
# data, and a target on another device is a mount — an unlocked vault, a
# removable disk, a network share — rather than part of this home.
should_resolve() {
  local source_dir=$1 target=$2
  # Inside the tree it stays a link: the target is in the archive too, so the
  # link still resolves once extracted, and storing the file twice is waste.
  case "$target/" in "$source_dir/"*) return 1 ;; esac
  [[ -f $target ]] || return 1
  case "$target/" in "$HOME/"*) ;; *) return 1 ;; esac
  [[ $(stat -c %d -- "$target") == "$HOME_DEVICE" ]]
}

# --- measuring and showing -------------------------------------------------------

# One walk of the top level answers all three questions the operator has: what
# is in here, how much of it, and what dominates. Sorted by size, because that
# is the entry worth recognising before agreeing to move it.
measure() {
  local source_dir=$1
  local line link target

  mapfile -t ENTRIES < <(
    find "$source_dir" -mindepth 1 -maxdepth 1 -print0 |
      du -sb --files0-from=- | sort -rn
  )
  TOTAL_BYTES=0
  for line in "${ENTRIES[@]}"; do
    TOTAL_BYTES=$((TOTAL_BYTES + ${line%%	*}))
  done
  # -printf '.' rather than a line per entry: a newline in a filename is legal
  # and would otherwise be counted as another file.
  ITEM_COUNT=$(find "$source_dir" -mindepth 1 -printf '.' | wc -c)

  OUTSIDE_LINKS=()
  while IFS= read -r -d '' link; do
    target=$(realpath -m -- "$source_dir/${link#./}")
    case "$target/" in "$source_dir/"*) continue ;; esac
    if should_resolve "$source_dir" "$target"; then
      OUTSIDE_LINKS+=("${link#./} -> $target (copied in)")
    else
      OUTSIDE_LINKS+=("${link#./} -> $target (kept as a link)")
    fi
  done < <(cd -- "$source_dir" && find . -type l -print0)
}

show_plan() {
  local source_dir=$1 destination=$2
  local line size name shown=0 outside

  printf '\n  %s\n  -> %s\n\n' "$source_dir" "$destination"
  for line in "${ENTRIES[@]}"; do
    if ((shown == MAX_LISTED)); then
      printf '  %6s  ... and %d more\n' '' "$((${#ENTRIES[@]} - shown))"
      break
    fi
    size=${line%%	*}
    name=${line#*	}
    name=${name##*/}
    if [[ -L $source_dir/$name ]]; then
      name="$name -> $(readlink -- "$source_dir/$name")"
    elif [[ -d $source_dir/$name ]]; then
      name="$name/"
    fi
    printf '  %6s  %s\n' "$(human "$size")" "$name"
    shown=$((shown + 1))
  done
  printf '\n  %s items, %s\n' "$ITEM_COUNT" "$(human "$TOTAL_BYTES")"

  if ((${#OUTSIDE_LINKS[@]} > 0)); then
    printf '\n  pointing outside %s:\n' "$source_dir"
    for outside in "${OUTSIDE_LINKS[@]}"; do
      printf '    %s\n' "$outside"
    done
  fi
  ((SAME_DEVICE == 1)) ||
    printf '\n  the destination is on another filesystem: this copies, verifies, then removes\n'
}

# --- asking ----------------------------------------------------------------------

# No is the default, and end of input is a No: the answer that moves nothing
# is the one an unattended run gets.
confirm() {
  local source_dir=$1 answer

  printf '\nMove the contents of %s? [y/N] ' "$source_dir" >&2
  read -r answer || answer=
  [[ -t 0 ]] || printf '%s\n' "$answer" >&2
  [[ $answer == [yY] || $answer == [yY][eE][sS] ]]
}

# Read from the terminal rather than stdin: the confirmation above may have
# been piped in, and a password that can arrive through a pipe is a password
# that ends up in shell history or a script. Twice, because 7z asks once with
# no confirmation of its own and nothing downstream can tell a typo from a
# deliberate password — the archive would simply never open again.
read_password() {
  local first second
  local -a askpass

  # A command that prints the password, never the password itself: an
  # environment variable holding it would be readable in /proc for the whole
  # run and inherited by every child. Asked for once, because there is no
  # typing here to mistype.
  if [[ -n ${ARCHIVE_ASKPASS:-} ]]; then
    read -r -a askpass <<<"$ARCHIVE_ASKPASS"
    command -v "${askpass[0]}" >/dev/null ||
      die "ARCHIVE_ASKPASS names no runnable command: ${askpass[0]}"
    PASSWORD=$("${askpass[@]}") || die 'ARCHIVE_ASKPASS failed; nothing was archived'
    [[ -n $PASSWORD ]] || die 'an empty password encrypts nothing'
    return 0
  fi

  # The brace group keeps 2>/dev/null from becoming permanent: `exec` with only
  # redirections applies them to the shell itself, which would silence every
  # prompt and error after this point.
  { exec 3</dev/tty; } 2>/dev/null ||
    die 'no terminal to ask for the password on. Set ARCHIVE_ASKPASS to a command that prints it.'
  printf 'Password: ' >&2
  IFS= read -rs first <&3 || die 'no password given; nothing was archived'
  printf '\nRepeat:   ' >&2
  IFS= read -rs second <&3 || die 'no password given; nothing was archived'
  printf '\n' >&2
  exec 3<&-
  [[ -n $first ]] || die 'an empty password encrypts nothing'
  [[ $first == "$second" ]] || die 'the passwords do not match; nothing was archived'
  PASSWORD=$first
}

# --- naming a run ----------------------------------------------------------------

# The name a run takes on its Nth attempt. One rule, so the directory the move
# path reserves and the file the compress path claims cannot drift apart.
candidate_name() {
  local parent=$1 stamp=$2 attempt=$3 suffix=$4
  if ((attempt == 1)); then
    printf '%s/%s%s\n' "$parent" "$stamp" "$suffix"
  else
    printf '%s/%s-%s%s\n' "$parent" "$stamp" "$attempt" "$suffix"
  fi
}

# mkdir fails when the directory exists, and it fails atomically, so claiming
# the name this way is what stops two runs in one second from merging.
reserve_directory() {
  local parent=$1 stamp=$2 attempt candidate

  for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    candidate=$(candidate_name "$parent" "$stamp" "$attempt" '')
    if mkdir -- "$candidate" 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# The name the archive will take. 7z refuses to write into a file that already
# exists, so unlike a directory it cannot be reserved before it is built; this
# only predicts, and claim_archive does the atomic part afterwards.
predict_archive() {
  local parent=$1 stamp=$2 attempt candidate

  for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    candidate=$(candidate_name "$parent" "$stamp" "$attempt" .7z)
    if [[ ! -e $candidate ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# ln is atomic and refuses an existing target, which is the guard that matters
# here: `7zz a` merges into an archive that is already there without saying so,
# so a lost race would silently blend two unrelated archives into one.
claim_archive() {
  local parent=$1 stamp=$2 built=$3 attempt candidate

  for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    candidate=$(candidate_name "$parent" "$stamp" "$attempt" .7z)
    if ln -- "$built" "$candidate" 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# --- moving ----------------------------------------------------------------------

# rename(2) within one filesystem: instant whatever the size, atomic per entry,
# and inodes are untouched so hard links between archived files survive.
move_within_filesystem() {
  local source_dir=$1 destination=$2
  find "$source_dir" -mindepth 1 -maxdepth 1 -exec mv -t "$destination" -- {} +
}

# Across filesystems there is no rename, so this copies without removing
# anything, proves the copy matches, and only then deletes. rsync's own
# --remove-source-files would delete as it went, leaving a later check with
# nothing left to compare against.
copy_across_filesystems() {
  local source_dir=$1 destination=$2
  local -a progress=()
  local differences

  ! interactive || progress=(--info=progress2)
  rsync -aH "${progress[@]}" -- "$source_dir/" "$destination/"

  # -c re-reads both sides and compares checksums rather than size and time,
  # which is the only way to catch a destination that differs after the fact.
  # Lines beginning with a dot are entries needing no content update.
  differences=$(rsync -aHc --dry-run --itemize-changes -- "$source_dir/" "$destination/" |
    grep -v '^\.' || true)
  if [[ -n $differences ]]; then
    printf 'archive: the copy does not match the source; nothing was removed.\n' >&2
    printf 'archive: source %s\narchive: copy   %s\n' "$source_dir" "$destination" >&2
    printf '%s\n' "$differences" >&2
    exit 1
  fi
  find "$source_dir" -mindepth 1 -delete
}

# --- compressing -----------------------------------------------------------------

# 7z can only follow every symlink or none, so a mirror is what makes a policy
# per link possible: the ones that should become real files are materialised
# here first. cp -al links rather than copies, so the mirror costs almost
# nothing beside the source it shadows.
build_mirror() {
  local source_dir=$1 mirror=$2 link target

  cp -al -- "$source_dir/." "$mirror/"
  while IFS= read -r -d '' link; do
    target=$(realpath -m -- "$source_dir/${link#./}")
    should_resolve "$source_dir" "$target" || continue
    rm -f -- "${mirror:?}/${link#./}"
    ln -- "$target" "$mirror/${link#./}" 2>/dev/null ||
      cp -- "$target" "$mirror/${link#./}"
  done < <(cd -- "$source_dir" && find . -type l -print0)
}

build_archive() {
  local built=$1 mirror=$2
  local -a opts=(a -snl)

  interactive || opts+=(-bso0 -bsp0)
  if ((encrypt == 1)); then
    # Only `a` reads a password from stdin; every reading operation needs it
    # on the command line. This is the one place a pipe works, so it is used.
    printf '%s\n' "$PASSWORD" | 7zz "${opts[@]}" -p -mhe=on "$built" "$mirror/."
  else
    7zz "${opts[@]}" "$built" "$mirror/."
  fi
}

verify_archive() {
  local path=$1
  if ((encrypt == 1)); then
    # No reading operation will take this on stdin or prompt for it, so it goes
    # on the command line, where it is visible in /proc for as long as the test
    # runs. Accepted deliberately: see docs/DECISIONS.md.
    7zz t -p"$PASSWORD" "$path" >/dev/null
  else
    7zz t "$path" >/dev/null
  fi
}

# Every early exit — a cancelled confirmation, a mismatched password, a failed
# archiver — should leave the tree as it found it. rmdir only removes an empty
# directory, so this is safe to attempt unconditionally: once a run has
# actually archived something, both directories have contents and stay.
# --- clearing up -----------------------------------------------------------------

discard_mirror() {
  [[ -n ${MIRROR:-} ]] || return 0
  rm -rf -- "$MIRROR"
  MIRROR=
}

cleanup() {
  discard_mirror
  [[ -z ${RESERVED:-} ]] || rmdir -- "$RESERVED" 2>/dev/null || true
  [[ -z ${PARENT:-} ]] || rmdir -- "$PARENT" 2>/dev/null || true
}

# --- the run itself --------------------------------------------------------------

force=0
compress=0
encrypt=0
source_arg=
to_dir=

while (($# > 0)); do
  case $1 in
    -f | --force)
      force=1
      shift
      ;;
    -z | --compress)
      compress=1
      shift
      ;;
    -e | --encrypt)
      encrypt=1
      compress=1
      shift
      ;;
    --to)
      (($# >= 2)) || usage_error 'option --to needs a directory'
      to_dir=$2
      shift 2
      ;;
    --to=*)
      to_dir=${1#--to=}
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*) usage_error "unknown option: $1" ;;
    *)
      [[ -z $source_arg ]] || usage_error 'archive takes one directory, not several'
      source_arg=$1
      shift
      ;;
  esac
done
if (($# > 0)); then
  [[ -z $source_arg ]] || usage_error 'archive takes one directory, not several'
  source_arg=$1
  shift
  (($# == 0)) || usage_error 'archive takes one directory, not several'
fi

((compress == 0)) || require_archiver

source_dir=$(realpath -e -- "${source_arg:-.}")
if [[ ! -d $source_dir || $source_dir == / ]]; then
  die 'source must be a directory other than /'
fi
# --to wins over the environment, which wins over the built-in default. The
# environment is how Home Manager sets the root while the bare script, run
# straight from the repository, still has somewhere sensible to go.
archive_root=$(realpath -m -- "${to_dir:-${ARCHIVE_ROOT:-$HOME/Archive}}")
case "$archive_root/" in
  "$source_dir/"*) die 'source contains the archive destination' ;;
esac
case "$source_dir/" in
  "$archive_root/"*) die 'source is already inside the archive' ;;
esac

HOME_DEVICE=$(stat -c %d -- "$HOME")
measure "$source_dir"
if ((ITEM_COUNT == 0)); then
  printf 'archive: %s is empty; nothing to archive\n' "$source_dir"
  exit 0
fi

parent="$archive_root/$(basename -- "$source_dir")"
if [[ -L $parent ]]; then
  die 'archive subdirectory must not be a symlink'
fi
mkdir -p -- "$parent"
PARENT=$parent
trap cleanup EXIT

SAME_DEVICE=0
[[ $(stat -c %d -- "$source_dir") != "$(stat -c %d -- "$parent")" ]] || SAME_DEVICE=1

stamp=$(date +%Y-%m-%d_%H-%M-%S)
if ((compress == 1)); then
  destination=$(predict_archive "$parent" "$stamp") ||
    die "cannot find a free archive name in $parent"
else
  # Reserved before asking rather than after, so the path in the question is
  # the path the files actually land in.
  destination=$(reserve_directory "$parent" "$stamp") ||
    die "cannot create an archive directory in $parent"
  RESERVED=$destination
fi

if ((force == 0)); then
  show_plan "$source_dir" "$destination"
  if ! confirm "$source_dir"; then
    printf 'archive: cancelled; nothing was moved\n'
    exit 0
  fi
fi

((encrypt == 0)) || read_password

if ((compress == 0)); then
  printf 'Archiving %s to %s\n' "$(human "$TOTAL_BYTES")" "$destination"
  if ((SAME_DEVICE == 1)); then
    move_within_filesystem "$source_dir" "$destination"
  else
    printf 'Destination is on another filesystem: copying, verifying, then removing the source.\n'
    copy_across_filesystems "$source_dir" "$destination"
  fi
  exit 0
fi

printf 'Archiving %s to %s\n' "$(human "$TOTAL_BYTES")" "$destination"

# The mirror lives beside the source so that cp -al can hard-link into it;
# next to the destination it would be a real copy whenever the two differ.
MIRROR=$(mktemp -d -- "$(dirname -- "$source_dir")/.archive-mirror.XXXXXX") ||
  die "cannot create a staging directory beside $source_dir"
build_mirror "$source_dir" "$MIRROR"

staging=$(mktemp -d -- "$parent/.archive-build.XXXXXX") ||
  die "cannot create a staging directory in $parent"
built="$staging/archive.7z"
if ! build_archive "$built" "$MIRROR"; then
  rm -rf -- "$staging"
  die 'the archive could not be written; nothing was removed'
fi

destination=$(claim_archive "$parent" "$stamp" "$built") || {
  rm -rf -- "$staging"
  die "cannot find a free archive name in $parent"
}
rm -rf -- "$staging"
discard_mirror

if ! verify_archive "$destination"; then
  printf 'archive: the archive did not verify; nothing was removed.\n' >&2
  printf 'archive: source  %s\narchive: archive %s\n' "$source_dir" "$destination" >&2
  printf 'archive: a wrong password and a damaged archive fail the same way here.\n' >&2
  exit 1
fi

find "$source_dir" -mindepth 1 -delete
printf 'Archived %s to %s\n' "$(human "$(stat -c %s -- "$destination")")" "$destination"
