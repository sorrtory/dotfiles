#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: vault init [--storage DIR] NAME
       vault open [--storage DIR] PATH
       vault notes [--storage DIR] PATH

Create or unlock a private vault.

A vault is a directory, and there is no registry and no default one: every
command names the vault it acts on. Its encrypted storage is the hidden
sibling of that directory, so Vault is stored in .Vault.encrypted and
Documents/Work in Documents/.Work.encrypted.

  init   Create a vault called NAME in the current directory, with NAME
         holding the unlocked files and .NAME.encrypted holding the
         ciphertext. NAME is a name, not a path: cd to where the vault
         should live. Needs a terminal, because gocryptfs shows the master
         key once and only on one. It does not mount the vault, and it never
         writes over storage that already exists.
  open   Unlock the vault at PATH and show it in the file manager.
  notes  Unlock the vault at PATH and open its Notes/ in Obsidian, creating
         Notes/ the first time.

  --storage DIR  Use DIR as the encrypted storage instead of the hidden
                 sibling. This is how existing storage that does not follow
                 the sibling rule is named.

An already-unlocked vault is reused without asking again. The password is
never stored, and never passes through this command: gocryptfs asks for it,
on the terminal when there is one and through a dialog when there is not.
USAGE
}

die() {
  printf 'vault: %s\n' "$1" >&2
  exit 1
}

# gocryptfs reaches the host's setuid fusermount through this search order; the
# Nix build carries no store path for it, because a store path is never
# setuid-root. NixOS supplies the wrappers entry, every other distribution its
# own fuse3 package. VAULT_FUSERMOUNT names a helper kept somewhere unusual.
fuse_helper() {
  local candidate
  if [[ -n ${VAULT_FUSERMOUNT:-} ]]; then
    [[ -x ${VAULT_FUSERMOUNT} ]] || return 1
    printf '%s\n' "${VAULT_FUSERMOUNT}"
    return 0
  fi
  for candidate in \
    /run/wrappers/bin/fusermount3 /run/wrappers/bin/fusermount \
    /usr/bin/fusermount3 /usr/bin/fusermount \
    /bin/fusermount3 /bin/fusermount \
    /usr/sbin/fusermount3 /sbin/fusermount3; do
    if [[ -x $candidate ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# Checked before anything is created: storage that cannot be mounted is worse
# than no storage, because it still holds the only copy of the data.
require_fuse_helper() {
  if ! fuse_helper >/dev/null; then
    printf 'vault: no FUSE helper found.\n' >&2
    printf 'The helper that mounts a gocryptfs filesystem is setuid root and belongs\n' >&2
    printf 'to the host distribution; Nix cannot provide it. Install fuse3 (Ubuntu,\n' >&2
    printf 'Debian and Fedora all call it that), or set VAULT_FUSERMOUNT to its path.\n' >&2
    exit 1
  fi
}

# The hidden sibling of the mount directory. Deriving it means an invocation
# names one path, and the two stay together when the vault is moved.
derive_storage() {
  local mount_dir=$1 parent base
  parent=$(dirname -- "$mount_dir")
  base=$(basename -- "$mount_dir")
  case $base in
    . | .. | /) die "cannot derive storage for $mount_dir; name it with --storage" ;;
  esac
  printf '%s/.%s.encrypted\n' "$parent" "$base"
}

directory_is_occupied() {
  local path=$1
  [[ -e $path || -L $path ]] || return 1
  [[ -d $path && ! -L $path ]] || return 0
  [[ -n $(ls -A -- "$path") ]]
}

# The bookkeeping is a cache, never an authority: every entry is checked
# against the running process and the real mount before it is believed, and
# nothing here is a vault registry. It holds no password.
runtime_record() {
  printf '%s/vault/%s\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    "$(printf '%s' "$1" | tr '/' '_')"
}

# fuse.gocryptfs in mountinfo is the only claim that matters; a directory that
# merely exists proves nothing.
is_mounted() {
  local mount_dir=$1 field
  while read -r _ _ _ _ field _; do
    [[ $field == "$mount_dir" ]] || continue
    return 0
  done </proc/self/mountinfo
  return 1
}

mount_is_gocryptfs() {
  local mount_dir=$1 line
  while read -r line; do
    case " $line " in
      *" $mount_dir "*) ;;
      *) continue ;;
    esac
    case $line in
      *fuse.gocryptfs*) return 0 ;;
    esac
  done </proc/self/mountinfo
  return 1
}

# gocryptfs daemonizes, so the process that owns the mount is found by asking
# the kernel which of our processes was started for this pair of directories.
find_daemon() {
  local storage=$1 mount_dir=$2 pid cmdline
  for pid in /proc/[0-9]*; do
    pid=${pid#/proc/}
    [[ -r /proc/$pid/cmdline ]] || continue
    cmdline=$(tr '\0' ' ' </proc/"$pid"/cmdline 2>/dev/null) || continue
    case $cmdline in
      *gocryptfs*"$storage"*"$mount_dir"*)
        printf '%s\n' "$pid"
        return 0
        ;;
    esac
  done
  return 1
}

# A mount whose daemon is gone answers every read with ENOTCONN. It has to be
# reported as its own state: it is neither locked nor usable.
mount_is_stale() {
  local mount_dir=$1
  is_mounted "$mount_dir" || return 1
  ls -- "$mount_dir" >/dev/null 2>&1 && return 1
  return 0
}

require_initialized() {
  local storage=$1
  [[ -d $storage ]] ||
    die "$storage does not exist; run 'vault init' to create this vault"
  [[ -f $storage/gocryptfs.conf ]] ||
    die "$storage holds no gocryptfs filesystem; run 'vault init' to create this vault"
}

# Both commands name a vault the same way, so they parse it the same way.
# Sets TARGET_MOUNT and TARGET_STORAGE.
parse_target() {
  local command=$1 mount_dir='' storage=''
  shift

  while (($# > 0)); do
    case $1 in
      --storage)
        (($# >= 2)) || die 'option --storage needs a directory'
        storage=$2
        shift 2
        ;;
      --storage=*)
        storage=${1#--storage=}
        shift
        ;;
      -*) die "unknown option: $1" ;;
      *)
        [[ -z $mount_dir ]] || die "vault $command names one vault, not several"
        mount_dir=$1
        shift
        ;;
    esac
  done

  [[ -n $mount_dir ]] ||
    die "vault $command needs the vault's path; there is no default vault"
  mount_dir=$(realpath -m -- "$mount_dir")
  [[ $mount_dir != / && $mount_dir != "$HOME" ]] ||
    die 'the vault must be a directory of its own'
  if [[ -n $storage ]]; then
    storage=$(realpath -m -- "$storage")
  else
    storage=$(derive_storage "$mount_dir")
  fi
  [[ $storage != "$mount_dir" ]] || die 'the storage and the mount directory must differ'

  TARGET_MOUNT=$mount_dir
  TARGET_STORAGE=$storage
}

cmd_init() {
  local mount_dir storage name skip
  case ${1:-} in
    -h | --help)
      usage
      return 0
      ;;
  esac

  # A vault is created where the operator is standing, under a name they
  # choose. Taking a path here would invite a default, and there is no default
  # vault: every other command names the one it acts on.
  skip=0
  for name in "$@"; do
    if ((skip)); then
      skip=0
      continue
    fi
    case $name in
      --storage)
        skip=1
        continue
        ;;
      -*) continue ;;
      */*) die "vault init takes a name, not a path; cd to where the vault should live" ;;
      . | ..) die "'$name' is not a vault name" ;;
    esac
  done

  parse_target init "$@"
  mount_dir=$TARGET_MOUNT
  storage=$TARGET_STORAGE

  require_fuse_helper

  if directory_is_occupied "$storage"; then
    die "$storage already exists; vault init never writes over existing storage"
  fi
  if directory_is_occupied "$mount_dir"; then
    die "$mount_dir is not empty; a vault mounts over an empty directory"
  fi

  # gocryptfs shows the master key once, and only when it is talking to a
  # terminal: without one it creates the filesystem and silently suppresses the
  # only recovery material there will ever be. Refuse rather than leave the
  # operator with storage they cannot recover.
  [[ -t 0 && -t 1 ]] ||
    die 'init needs a terminal; the master key is shown once and only on one'

  mkdir -p -- "$storage" "$mount_dir"
  chmod 700 -- "$storage" "$mount_dir"

  # gocryptfs asks for the new password itself, twice and without echo, and
  # prints the recovery material to the terminal. Neither is captured here:
  # nothing this command writes may carry either of them.
  printf 'Creating encrypted storage in %s for the vault at %s.\n' "$storage" "$mount_dir"
  gocryptfs -init -- "$storage"

  cat <<INSTRUCTION

Store the master key printed above in KeePassXC now, before you put anything in
this vault. It is the only way back in if the password is lost, and it belongs
outside every filesystem vault. It has not been written to a file, a log or
this repository, and it will not be shown again.

The vault is not mounted. Backups are not part of this command.
INSTRUCTION
}

# Unlocking is the same work whichever command asked for it.
ensure_unlocked() {
  local mount_dir=$1 storage=$2
  local -a extpass=()

  if mount_is_stale "$mount_dir"; then
    die "$mount_dir is mounted but its gocryptfs process is gone; run 'vault lock' to clear it before opening"
  fi

  # An already-unlocked vault is reused as it stands: asking for a password
  # that would change nothing is how people learn to type it without looking.
  if is_mounted "$mount_dir" && mount_is_gocryptfs "$mount_dir"; then
    printf '%s is already unlocked.\n' "$mount_dir"
    return 0
  fi

  require_initialized "$storage"
  [[ -d $mount_dir ]] || mkdir -p -- "$mount_dir"
  if [[ -n $(ls -A -- "$mount_dir") ]]; then
    die "$mount_dir is not empty; mounting there would hide what is in it"
  fi

  # gocryptfs asks for the password itself and daemonizes once the mount is up,
  # so the password never passes through this command at all. Without a
  # terminal it cannot prompt, so it is given a dialog to ask with; -extpass
  # repeats to build the command, and zenity writes the password to stdout.
  # VAULT_ASKPASS replaces the dialog on a session that has something else.
  if [[ ! -t 0 ]]; then
    if [[ -n ${VAULT_ASKPASS:-} ]]; then
      # A whole command of its own, which must write the password to stdout.
      command -v "${VAULT_ASKPASS%% *}" >/dev/null ||
        die "VAULT_ASKPASS names ${VAULT_ASKPASS%% *}, which is not installed"
      extpass=(-extpass "$VAULT_ASKPASS")
    elif [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
      command -v zenity >/dev/null ||
        die "no terminal to ask for the password on, and zenity is not installed"
      extpass=(
        -extpass zenity
        -extpass --password
        -extpass "--title=Unlock $(basename -- "$mount_dir")"
      )
    else
      # Without this, a vault command run over ssh hands gocryptfs a dialog
      # that can never appear and waits for it forever.
      die 'no terminal to ask for the password on, and no graphical session to ask in'
    fi
  fi
  if ! gocryptfs "${extpass[@]}" -- "$storage" "$mount_dir"; then
    die "could not unlock $mount_dir"
  fi
  if ! mount_is_gocryptfs "$mount_dir"; then
    die "gocryptfs reported success but $mount_dir is not mounted"
  fi
}

# The record is rewritten from a fresh scan every time, so a stale one is
# never handed on.
record_daemon() {
  local mount_dir=$1 storage=$2 record pid
  record=$(runtime_record "$mount_dir")
  mkdir -p -- "$(dirname -- "$record")"
  if pid=$(find_daemon "$storage" "$mount_dir"); then
    printf 'pid=%s\nstorage=%s\n' "$pid" "$storage" >"$record"
  else
    # Not fatal: the mount is real either way, and ticket 05 rechecks before
    # it believes anything written here.
    rm -f -- "$record"
  fi
}

cmd_open() {
  local mount_dir storage
  case ${1:-} in
    -h | --help)
      usage
      return 0
      ;;
  esac
  parse_target open "$@"
  mount_dir=$TARGET_MOUNT
  storage=$TARGET_STORAGE

  require_fuse_helper
  ensure_unlocked "$mount_dir" "$storage"
  record_daemon "$mount_dir" "$storage"

  open_in_file_manager "$mount_dir"
}

# Launched detached, so the vault stays open when the terminal that unlocked it
# goes away.
open_in_file_manager() {
  local mount_dir=$1
  if [[ -z ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
    printf '%s is unlocked. No graphical session, so nothing was opened.\n' "$mount_dir"
    return 0
  fi
  if ! command -v nautilus >/dev/null; then
    printf '%s is unlocked. Nautilus is not installed, so nothing was opened.\n' "$mount_dir"
    return 0
  fi
  setsid nautilus -w -- "$mount_dir" >/dev/null 2>&1 &
  printf '%s is unlocked.\n' "$mount_dir"
}

cmd_notes() {
  local mount_dir storage notes
  case ${1:-} in
    -h | --help)
      usage
      return 0
      ;;
  esac
  parse_target notes "$@"
  mount_dir=$TARGET_MOUNT
  storage=$TARGET_STORAGE

  require_fuse_helper
  ensure_unlocked "$mount_dir" "$storage"
  record_daemon "$mount_dir" "$storage"

  # Created on first use rather than by init, which makes a general-purpose
  # encrypted filesystem and not a notes layout.
  notes="$mount_dir/Notes"
  [[ -d $notes ]] || mkdir -p -- "$notes"

  # Obsidian takes a vault as a URI and reads the query value whole, so the
  # separators are encoded. This is a second vault beside the knowledge
  # database, never a replacement for it.
  if ! command -v obsidian >/dev/null; then
    printf '%s is unlocked. Obsidian is not installed, so nothing was opened.\n' "$notes"
    return 0
  fi
  setsid obsidian "obsidian://open?path=$(url_encode_path "$notes")" >/dev/null 2>&1 &
  printf '%s is unlocked.\n' "$notes"
}

url_encode_path() {
  printf '%s' "$1" | sed -e 's|/|%2F|g' -e 's| |%20|g'
}

main() {
  if (($# == 0)); then
    usage >&2
    exit 2
  fi
  case $1 in
    init)
      shift
      cmd_init "$@"
      ;;
    open)
      shift
      cmd_open "$@"
      ;;
    notes)
      shift
      cmd_notes "$@"
      ;;
    -h | --help)
      usage
      ;;
    *)
      printf 'vault: unknown command: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
