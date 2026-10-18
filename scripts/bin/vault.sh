#!/usr/bin/env bash
set -euo pipefail

# The vault a command acts on when it is not told otherwise: one in the
# directory the operator is standing in. Never a vault in $HOME by surprise.
readonly DEFAULT_NAME=Vault

usage() {
  cat <<'USAGE'
Usage: vault init   [--storage DIR] [NAME]
       vault unlock [--storage DIR] [--terminal|--dialog] [PATH]
       vault open   [--storage DIR] [--terminal|--dialog] [PATH]
       vault notes  [--storage DIR] [--terminal|--dialog] [PATH]
       vault lock   [--storage DIR] [--force] [PATH]
       vault lock   --all [--force]
       vault toggle [--storage DIR] [PATH]
       vault entry

A private vault is an encrypted directory. There is no registry and no global
vault: a command acts on the path it is given, or on ./Vault when it is given
none. The ciphertext lives in the hidden sibling of that directory, so Vault
is stored in .Vault.encrypted and Documents/Work in Documents/.Work.encrypted.

  init    Create a vault. NAME is a name, not a path: the vault is made in the
          current directory. Needs a terminal, because gocryptfs shows the
          master key once and only on one. It does not unlock the vault, and
          it never writes over storage that already exists.
  unlock  Mount the vault, and nothing else.
  open    Unlock it and show it in the file manager.
  notes   Unlock it and open its Notes/ in Obsidian, creating Notes/ the first
          time. Its separate app profile stays in .obsidian-profile/ inside
          the encrypted filesystem. Offers to create the vault if needed.
  lock    End access. It closes cleanly on its own when nothing is holding the
          vault; when something is, it names what, says what forcing costs,
          and waits for an answer.
  toggle  Lock the vault if it is unlocked, otherwise open it. What a single
          launcher does, decided by what is mounted now.
  entry   Rewrite the desktop entry for VAULT_DESKTOP_ENTRY from the vault's
          current state. Every lock and unlock does this already.

  --storage DIR  Use DIR as the encrypted storage instead of the hidden
                 sibling, for storage that does not follow the rule.
  --terminal     Ask for the password on the terminal, even from a desktop
                 launcher. Fails when there is no terminal to ask on.
  --dialog       Ask through a graphical dialog, even from a terminal.
  --force        Lock without asking, for a session ending with nobody there
                 to answer. It still reports what it had to force.
  --all          Lock every vault this session unlocked, for the same case.
                 Takes no path.

The password is never stored and never passes through this command: gocryptfs
asks for it, on the terminal when there is one and through a dialog when there
is not. Locking ends access through the mount. It cannot unread what a program
has already loaded, and does not pretend to.

VAULT_ASKPASS replaces the dialog with a command that prints the password.
VAULT_FUSERMOUNT names the FUSE helper when the host keeps it somewhere
unusual. VAULT_DESKTOP_ENTRY names the one vault whose state the desktop
entry shows; without it no entry is written.
USAGE
}

# --- saying things -----------------------------------------------------------

# A failure the operator actually sees. From a terminal that is the terminal;
# from a keybinding there is nowhere to write, so it is a dialog. Silence is
# what makes a desktop launcher feel broken.
report_error() {
  local message=$1
  printf 'vault: %s\n' "$message" >&2
  [[ ! -t 2 ]] || return 0
  [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] || return 0
  command -v zenity >/dev/null || return 0
  zenity --error --title='Vault' --text="$message" >/dev/null 2>&1 || true
}

die() {
  report_error "$1"
  exit 1
}

say() {
  printf '%s\n' "$1"
}

# Success from a launcher has nowhere to be printed either. A notification,
# not a dialog, because there is nothing to answer.
notify() {
  [[ ! -t 1 ]] || return 0
  [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] || return 0
  command -v notify-send >/dev/null || return 0
  notify-send --app-name=Vault --icon=changes-prevent-symbolic "$1" "$2" \
    >/dev/null 2>&1 || true
}

# --- the host's FUSE helper --------------------------------------------------

# gocryptfs reaches the host's setuid fusermount through this search order. The
# Nix build carries no store path for it, because a store path is never
# setuid-root: NixOS supplies the wrappers entry and every other distribution
# its own fuse3 package.
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

require_fuse_helper() {
  fuse_helper >/dev/null && return 0
  die 'no FUSE helper found. The helper that mounts a gocryptfs filesystem is setuid root and belongs to the host distribution, so Nix cannot provide it. Install fuse3, or set VAULT_FUSERMOUNT to its path.'
}

# --- naming a vault ----------------------------------------------------------

derive_storage() {
  local mount_dir=$1 parent base
  parent=$(dirname -- "$mount_dir")
  base=$(basename -- "$mount_dir")
  printf '%s/.%s.encrypted\n' "$parent" "$base"
}

# Sets TARGET_MOUNT, TARGET_STORAGE, ASK_MODE and FORCE from a command's
# arguments. Every command names a vault the same way, so every command parses
# it the same way.
resolve_target() {
  local command=$1 mount_dir='' storage=''
  shift
  ASK_MODE=auto
  FORCE=0
  ALL=0

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
      --terminal)
        ASK_MODE=terminal
        shift
        ;;
      --dialog)
        ASK_MODE=dialog
        shift
        ;;
      -f | --force)
        FORCE=1
        shift
        ;;
      --all)
        ALL=1
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
      -*) die "unknown option: $1" ;;
      *)
        [[ -z $mount_dir ]] || die "$command names one vault, not several"
        mount_dir=$1
        shift
        ;;
    esac
  done
  if (($# > 0)); then
    [[ -z $mount_dir ]] || die "$command names one vault, not several"
    mount_dir=$1
    shift
    (($# == 0)) || die "$command names one vault, not several"
  fi

  mount_dir=$(realpath -m -- "${mount_dir:-$DEFAULT_NAME}")
  [[ $mount_dir != / && $mount_dir != "$HOME" ]] ||
    die 'a vault is a directory of its own, not / or the home directory'

  if [[ -n $storage ]]; then
    storage=$(realpath -m -- "$storage")
  else
    storage=$(derive_storage "$mount_dir")
  fi
  [[ $storage != "$mount_dir" ]] ||
    die 'the storage and the vault directory must differ'

  TARGET_MOUNT=$mount_dir
  TARGET_STORAGE=$storage
}

# --- what is true right now --------------------------------------------------

runtime_record() {
  printf '%s/vault/%s\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    "$(printf '%s' "$1" | tr '/' '_')"
}

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

# A mount whose daemon is gone answers every read with ENOTCONN. It is neither
# locked nor usable, and has to be reported as its own state.
mount_is_stale() {
  local mount_dir=$1
  is_mounted "$mount_dir" || return 1
  ls -- "$mount_dir" >/dev/null 2>&1 && return 1
  return 0
}

# gocryptfs daemonizes, so the process owning a mount is found by asking the
# kernel which of ours was started for this pair of directories.
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

daemon_alive() {
  local pid=$1
  [[ -n $pid && -d /proc/$pid ]] || return 1
  tr '\0' ' ' </proc/"$pid"/cmdline 2>/dev/null | grep -q gocryptfs
}

vault_exists() {
  [[ -f $1/gocryptfs.conf ]]
}

# --- asking for the password -------------------------------------------------

dialog_extpass() {
  local mount_dir=$1
  if [[ -n ${VAULT_ASKPASS:-} ]]; then
    command -v "${VAULT_ASKPASS%% *}" >/dev/null || return 1
    printf '%s\n' '-extpass' "$VAULT_ASKPASS"
    return 0
  fi
  # Without a session to draw in, a dialog is a wait that never ends: gocryptfs
  # would sit on an -extpass that can never answer. zenity being installed is
  # not the same as there being somewhere to show it.
  [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] || return 1
  command -v zenity >/dev/null || return 1
  printf '%s\n' '-extpass' 'zenity' '-extpass' '--password' \
    '-extpass' "--title=Unlock $(basename -- "$mount_dir")"
}

# gocryptfs reads the password from stdin when stdin is not a terminal, so
# --terminal means handing it the controlling terminal to read.
attach_terminal() {
  [[ -t 0 ]] && return 0
  [[ -e /dev/tty ]] || return 1
  exec </dev/tty || return 1
  [[ -t 0 ]]
}

# Sets EXTPASS to the arguments gocryptfs needs to ask the right way.
choose_prompt() {
  local mount_dir=$1
  EXTPASS=()
  case $ASK_MODE in
    terminal)
      attach_terminal || die 'no terminal to ask for the password on'
      ;;
    dialog)
      mapfile -t EXTPASS < <(dialog_extpass "$mount_dir")
      ((${#EXTPASS[@]} > 0)) || die 'no dialog available to ask for the password'
      ;;
    *)
      # The terminal always wins when there is one. A dialog is what happens
      # when there is not, never a preference imposed on someone who has one.
      [[ ! -t 0 ]] || return 0
      mapfile -t EXTPASS < <(dialog_extpass "$mount_dir")
      ((${#EXTPASS[@]} > 0)) ||
        die 'no terminal to ask for the password on, and no dialog to ask with'
      ;;
  esac
}

# --- doing the work ----------------------------------------------------------

do_init() {
  local mount_dir=$1 storage=$2

  if [[ -e $storage || -L $storage ]] && [[ -n $(ls -A -- "$storage" 2>/dev/null) ]]; then
    die "$storage already exists; init never writes over existing storage"
  fi
  if [[ -d $mount_dir ]] && [[ -n $(ls -A -- "$mount_dir") ]]; then
    die "$mount_dir is not empty; a vault mounts over an empty directory"
  fi

  # gocryptfs shows the master key once, and only when it is talking to a
  # terminal. Without one it would create the filesystem and silently suppress
  # the only recovery material there will ever be.
  [[ -t 0 && -t 1 ]] ||
    die "there is no vault at $mount_dir. Create one with 'vault init' in a terminal: the master key is shown once, and only on one."

  mkdir -p -- "$storage" "$mount_dir"
  chmod 700 -- "$storage" "$mount_dir"

  say "Creating encrypted storage in $storage for the vault at $mount_dir."
  gocryptfs -init -- "$storage"

  cat <<'INSTRUCTION'

Store the master key printed above in KeePassXC now, before you put anything in
this vault. It is the only way back in if the password is lost, and it belongs
outside every filesystem vault. It has not been written to a file, a log or
this repository, and it will not be shown again.
INSTRUCTION
}

# Mounts the vault if it is not mounted already. The one gocryptfs routine
# every entry point goes through.
do_unlock() {
  local mount_dir=$1 storage=$2 status=0

  if mount_is_stale "$mount_dir"; then
    die "$mount_dir is mounted but its gocryptfs process is gone; run 'vault lock' to clear it"
  fi
  if is_mounted "$mount_dir" && mount_is_gocryptfs "$mount_dir"; then
    UNLOCK_REUSED=1
    return 0
  fi
  UNLOCK_REUSED=0

  vault_exists "$storage" ||
    die "there is no vault at $mount_dir. Create one with 'vault init'."
  [[ -d $mount_dir ]] || mkdir -p -- "$mount_dir"
  if [[ -n $(ls -A -- "$mount_dir") ]]; then
    die "$mount_dir is not empty; mounting there would hide what is in it"
  fi

  choose_prompt "$mount_dir"
  # fd 8 serializes Notes with locking; fd 9 is toggle's lock. The daemon
  # outlives this command and must inherit neither of them.
  gocryptfs "${EXTPASS[@]}" -- "$storage" "$mount_dir" 8>&- 9>&- || status=$?
  case $status in
    0) ;;
    12) die "that password does not open $mount_dir" ;;
    9)
      # The dialog was dismissed. Cancelling is an answer, so it is reported
      # on the terminal and nowhere else: a popup saying the operator cancelled
      # is a popup nobody asked for.
      printf 'vault: cancelled; %s is still locked\n' "$mount_dir" >&2
      exit 1
      ;;
    *) die "could not unlock $mount_dir (gocryptfs exited $status)" ;;
  esac
  mount_is_gocryptfs "$mount_dir" ||
    die "gocryptfs reported success but $mount_dir is not mounted"
}

# Rewritten from a fresh scan every time, so a stale record is never passed on.
# It holds a pid and a path, never a password, and is not a vault registry.
record_daemon() {
  local mount_dir=$1 storage=$2 record pid
  record=$(runtime_record "$mount_dir")
  mkdir -p -- "$(dirname -- "$record")"
  if pid=$(find_daemon "$storage" "$mount_dir"); then
    printf 'pid=%s\nmount=%s\nstorage=%s\n' "$pid" "$mount_dir" "$storage" >"$record"
  else
    rm -f -- "$record"
  fi
}

# Everything the kernel says is still holding the vault: a working directory,
# a root, an executable or an open descriptor. A program that read a file and
# let go is not here, and never can be.
find_blockers() {
  local mount_dir=$1 pid link target self=$$
  for pid in /proc/[0-9]*; do
    pid=${pid#/proc/}
    [[ $pid != "$self" ]] || continue
    for link in cwd root exe; do
      target=$(readlink "/proc/$pid/$link" 2>/dev/null) || continue
      case $target in
        "$mount_dir" | "$mount_dir"/*)
          printf '%s\n' "$pid"
          continue 3
          ;;
      esac
    done
    for link in /proc/"$pid"/fd/*; do
      target=$(readlink "$link" 2>/dev/null) || continue
      case $target in
        "$mount_dir" | "$mount_dir"/*)
          printf '%s\n' "$pid"
          continue 3
          ;;
      esac
    done
  done
}

process_name() {
  local pid=$1 name
  name=$(tr '\0' ' ' </proc/"$pid"/cmdline 2>/dev/null) || name=''
  [[ -n ${name// /} ]] || name=$(cat /proc/"$pid"/comm 2>/dev/null) || name='(gone)'
  printf '%.60s' "$name"
}

unmount_cleanly() {
  local mount_dir=$1 helper
  helper=$(fuse_helper) || return 1
  "$helper" -u -- "$mount_dir" 2>/dev/null
}

# Only after the operator has confirmed this exact attempt. The lazy unmount
# detaches the mount, but a process holding a file keeps the daemon serving it,
# so the daemon is stopped too: that is what actually ends access.
force_unlock_teardown() {
  local mount_dir=$1 daemon=$2 helper waited=0
  helper=$(fuse_helper) || return 1
  "$helper" -uz -- "$mount_dir" 2>/dev/null || true
  if daemon_alive "$daemon"; then
    kill -TERM "$daemon" 2>/dev/null || true
    # Asked to stop, then given a few seconds. Never escalated to SIGKILL on a
    # timer: if it will not go, verification says so.
    while daemon_alive "$daemon" && ((waited < 10)); do
      sleep 0.5
      waited=$((waited + 1))
    done
  fi
}

verify_locked() {
  local mount_dir=$1 daemon=$2
  if is_mounted "$mount_dir"; then
    report_error "$mount_dir is still mounted"
    return 1
  fi
  if daemon_alive "$daemon"; then
    report_error "the gocryptfs process $daemon is still running"
    return 1
  fi
  return 0
}

# --- the desktop entry -------------------------------------------------------

# A desktop entry is a static file: the shell cannot work out a name or an icon
# from the vault's state. So every change of state rewrites it, in the user's
# own applications directory, which is writable and outranks the Nix profile.
# The icon shows the state and the name the action, as a padlock usually does.
#
# Only this command's own locks and unlocks move it. A daemon that dies on its
# own leaves a stale mount, which still reads as unlocked, and clicking locks
# it, which is what clears it anyway.
update_entry() {
  local target=${VAULT_DESKTOP_ENTRY:-} dir tmp self name icon comment
  [[ -n $target ]] || return 0
  target=$(realpath -m -- "$target")
  self=$(realpath -- "$0") || return 0
  dir=${XDG_DATA_HOME:-$HOME/.local/share}/applications

  if is_mounted "$target"; then
    name='Lock Vault'
    icon=changes-allow-symbolic
    comment="Close $target and end access to it"
  else
    name='Unlock Vault'
    icon=changes-prevent-symbolic
    comment="Unlock $target and show it in the file manager"
  fi

  mkdir -p -- "$dir" 2>/dev/null || return 0
  tmp=$(mktemp -- "$dir/.vault.desktop.XXXXXX" 2>/dev/null) || return 0
  # Written aside and renamed over, so the shell never reads half an entry.
  if printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    "Name=$name" \
    "Comment=$comment" \
    "Exec=\"$self\" toggle \"$target\"" \
    "Icon=$icon" \
    'Terminal=false' \
    'Categories=Utility;Security;' \
    'Keywords=vault;lock;unlock;encrypted;private;' >"$tmp" &&
    chmod 644 -- "$tmp" && mv -f -- "$tmp" "$dir/vault.desktop"; then
    return 0
  fi
  rm -f -- "$tmp"
}

# --- opening things ----------------------------------------------------------

# Launched detached, so the vault stays open when the terminal that unlocked it
# goes away.
launch() {
  local what=$1 state='is unlocked'
  shift
  # Whether the vault was just unlocked or was already open is the one thing
  # the operator cannot see for themselves, so every entry point says it.
  ((!UNLOCK_REUSED)) || state='is already unlocked'
  if [[ -z ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
    say "$what $state. No graphical session, so nothing was opened."
    return 0
  fi
  if ! command -v "$1" >/dev/null; then
    say "$what $state. $1 is not installed, so nothing was opened."
    return 0
  fi
  setsid "$@" >/dev/null 2>&1 8>&- 9>&- &
  say "$what $state."
}

# Electron rewrites /proc's argv into a single process-title string. Use its
# own SingletonLock to locate the main PID, then validate the executable and
# profile switch before treating it as this vault's process.
find_notes_processes() {
  local mount_dir=$1 lock pid exe cmdline
  lock=$(readlink -- "$mount_dir/.obsidian-profile/SingletonLock") || return 0
  pid=${lock##*-}
  [[ $pid =~ ^[0-9]+$ ]] || return 0
  exe=$(readlink "/proc/$pid/exe" 2>/dev/null) || return 0
  case ${exe##*/} in
    electron | electron-* | obsidian | Obsidian) ;;
    *) return 0 ;;
  esac
  cmdline=$(tr '\0' ' ' 2>/dev/null <"/proc/$pid/cmdline") || return 0
  case " $cmdline " in
    *" --user-data-dir=$mount_dir/.obsidian-profile "*) printf '%s\n' "$pid" ;;
  esac
}

notes_runtime() {
  local profile="$1/.obsidian-profile"
  printf '%s/vault-obsidian-%s\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    "$(printf '%s' "$profile" | sha256sum | cut -c1-16)"
}

# Normal locking asks the operator to close Notes. Only an explicitly forced
# lock stops it. Stop before unmounting: otherwise a surviving app could write
# its profile into the now-empty mount directory in plaintext.
stop_notes() {
  local mount_dir=$1 pid stat group pending waited=0
  local -a fields=() pids=() groups=()
  mapfile -t pids < <(find_notes_processes "$mount_dir")
  for pid in "${pids[@]}"; do
    # launch uses setsid. Signal its group as well to stop Chromium helpers
    # together with their main process.
    stat=$(cat "/proc/$pid/stat" 2>/dev/null) || continue
    read -r -a fields <<<"${stat##*) }"
    if [[ ${fields[2]:-} == "$pid" ]]; then
      groups+=("$pid")
      kill -TERM -- "-$pid" 2>/dev/null || true
    else
      kill -TERM "$pid" 2>/dev/null || true
    fi
  done
  while :; do
    pending=$(find_notes_processes "$mount_dir")
    for group in "${groups[@]}"; do
      if kill -0 -- "-$group" 2>/dev/null; then pending=1; fi
    done
    [[ -n $pending ]] || return 0
    if ((waited >= 10)); then
      report_error "Obsidian has not stopped; $mount_dir is still unlocked. Close Notes and retry."
      return 1
    fi
    sleep 0.5
    waited=$((waited + 1))
  done
}

open_notes() (
  local mount_dir=$1 storage=$2 notes="$1/Notes" profile="$1/.obsidian-profile"
  local registry="$profile/obsidian.json" tmp waited=0 runtime
  # Each profile has its own registry, so its sole managed vault can keep a
  # stable ID even when the encrypted filesystem is moved to another path.
  local id=0000000000000001
  local session_runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  local wayland=${WAYLAND_DISPLAY:-}
  local session_bus=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$session_runtime/bus}

  umask 077
  runtime=$(notes_runtime "$mount_dir")
  mkdir -p -- "$runtime"
  chmod 700 -- "$runtime"
  # Shared with locking, outside the mount: a lock must not detach the vault
  # while a concurrent notes command is still preparing to launch the app.
  exec 8>"$runtime/.launch.lock"
  flock 8
  do_unlock "$mount_dir" "$storage"
  record_daemon "$mount_dir" "$storage"
  update_entry
  mkdir -p -- "$notes" "$profile"
  chmod 700 -- "$profile"

  # Never rewrite state behind a running app. On a cold start merge only our
  # registration, preserving preferences, vault ID and cached window state.
  if [[ -z $(find_notes_processes "$mount_dir") ]]; then
    rm -f -- "$runtime/.obsidian-cli.sock"
    [[ -e $registry ]] || printf '{}\n' >"$registry"
    tmp=$(mktemp -- "$profile/.obsidian.json.XXXXXX")
    if ! jq --arg id "$id" --arg path "$notes" \
      '.vaults[$id] = ((.vaults[$id] // {}) + {path: $path, ts: (now * 1000 | floor), open: true})' \
      "$registry" >"$tmp" || [[ ! -s $tmp ]]; then
      rm -f -- "$tmp"
      die "could not read $registry; the vault remains unlocked"
    fi
    mv -f -- "$tmp" "$registry"
  fi

  # Obsidian 1.13 also routes repeat launches through a socket directly under
  # XDG_RUNTIME_DIR. A distinct user-data-dir alone does not isolate that socket.
  # Keep its short, per-profile name in the session runtime directory, and
  # resolve Wayland's relative display name before changing the runtime root.
  if [[ -n $wayland && $wayland != /* ]]; then
    wayland="$session_runtime/$wayland"
  fi
  XDG_RUNTIME_DIR=$runtime WAYLAND_DISPLAY=$wayland DBUS_SESSION_BUS_ADDRESS=$session_bus \
    launch "$notes" obsidian "--user-data-dir=$profile" "obsidian://open?vault=$id"
  [[ -n ${DISPLAY:-}$wayland ]] && command -v obsidian >/dev/null || return 0
  # Wait for its routing socket too: a second keypress must not forward to a
  # main process that is still starting. The app never inherits fd 8.
  while [[ ! -S $runtime/.obsidian-cli.sock || -z $(find_notes_processes "$mount_dir") ]]; do
    ((waited < 50)) || die "Obsidian did not start; $mount_dir remains unlocked"
    sleep 0.1
    waited=$((waited + 1))
  done
)

# --- commands ----------------------------------------------------------------

cmd_init() {
  local mount_dir storage name skip=0

  # A vault is created where the operator is standing, under a name they
  # choose. Taking a path here would invite a default somewhere else.
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
      */*) die 'init takes a name, not a path; cd to where the vault should live' ;;
      . | ..) die "'$name' is not a vault name" ;;
    esac
  done

  resolve_target init "$@"
  mount_dir=$TARGET_MOUNT
  storage=$TARGET_STORAGE

  require_fuse_helper
  do_init "$mount_dir" "$storage"
  say ''
  say "The vault is not unlocked. Open it with 'vault open $(basename -- "$mount_dir")'."
}

cmd_unlock() {
  local mount_dir storage
  resolve_target unlock "$@"
  mount_dir=$TARGET_MOUNT
  storage=$TARGET_STORAGE

  require_fuse_helper
  do_unlock "$mount_dir" "$storage"
  record_daemon "$mount_dir" "$storage"
  update_entry
  if ((UNLOCK_REUSED)); then
    say "$mount_dir is already unlocked."
  else
    say "$mount_dir is unlocked."
  fi
  return 0
}

cmd_open() {
  local mount_dir storage
  resolve_target open "$@"
  mount_dir=$TARGET_MOUNT
  storage=$TARGET_STORAGE

  require_fuse_helper
  do_unlock "$mount_dir" "$storage"
  record_daemon "$mount_dir" "$storage"
  update_entry
  launch "$mount_dir" nautilus -w -- "$mount_dir"
}

cmd_notes() {
  local mount_dir storage
  resolve_target notes "$@"
  mount_dir=$TARGET_MOUNT
  storage=$TARGET_STORAGE

  require_fuse_helper

  # Offered rather than assumed: with a terminal this creates the vault and
  # shows the master key. Without one, do_init refuses and says what to run,
  # because a vault made from a keypress would have no recovery material.
  if ! vault_exists "$storage" && ! is_mounted "$mount_dir"; then
    do_init "$mount_dir" "$storage"
    say ''
  fi

  # Serialize unlocking and app setup with locking, so a competing lock cannot
  # detach the mount before Notes has finished launching.
  open_notes "$mount_dir" "$storage"
}

report_blockers() {
  local mount_dir=$1 pid
  shift
  printf '%s cannot be unmounted yet. Still holding it:\n' "$mount_dir" >&2
  for pid in "$@"; do
    printf '  %s  %s\n' "$pid" "$(process_name "$pid")" >&2
  done
  printf '\nForcing detaches the vault anyway and stops the process that decrypts it.\n' >&2
  printf 'Unsaved edits in those programs are lost, and a write in progress is cut off.\n' >&2
}

# Retry, cancel or force, asked where the operator can answer: the terminal
# when there is one, a dialog when the command came from the session. Cancel is
# the default in both, because forcing is the answer that costs something.
ask_blocked() {
  local mount_dir=$1 answer pid text status
  shift

  if [[ -t 0 ]]; then
    printf '\n[r]etry after closing them, [c]ancel, or [f]orce? ' >&2
    read -r answer || answer=c
    printf '%s\n' "$answer"
    return 0
  fi

  # No terminal and no session to draw in: an answer piped in is still an
  # answer, and end of input is a cancel. This is the path a script takes.
  if [[ -z ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] || ! command -v zenity >/dev/null; then
    read -r answer || answer=c
    printf '%s\n' "$answer"
    return 0
  fi

  text="$mount_dir cannot be locked yet.\n\nStill holding it:"
  for pid in "$@"; do
    text="$text\n    $pid  $(process_name "$pid")"
  done
  text="$text\n\nForcing detaches the vault anyway and stops the process that"
  text="$text\ndecrypts it. Unsaved edits in those programs are lost, and a"
  text="$text\nwrite in progress is cut off."

  # --extra-button is the only one that is neither the default nor the escape
  # key, which is where forcing belongs.
  status=0
  answer=$(zenity --question --title='Lock vault' --no-wrap \
    --text="$(printf '%b' "$text")" \
    --ok-label='Retry' --cancel-label='Leave unlocked' \
    --extra-button='Force' 2>/dev/null) || status=$?
  # An extra button prints its label and exits non-zero, so it is checked
  # before the status. Otherwise zenity exits 0 for the default button and
  # non-zero for cancel or the window being closed, printing nothing either way.
  case $answer in
    Force)
      printf 'f\n'
      return 0
      ;;
  esac
  if ((status == 0)); then
    printf 'r\n'
  else
    printf 'c\n'
  fi
}

lock_one() (
  local mount_dir=$1 storage=$2 daemon answer runtime force=$FORCE
  local -a blockers=()

  runtime=$(notes_runtime "$mount_dir")
  mkdir -p -- "$runtime"
  chmod 700 -- "$runtime"
  exec 8>"$runtime/.launch.lock"
  flock 8

  if ! is_mounted "$mount_dir"; then
    say "$mount_dir is not unlocked."
    rm -f -- "$(runtime_record "$mount_dir")"
    update_entry
    return 0
  fi

  daemon=$(find_daemon "$storage" "$mount_dir") || daemon=''

  while :; do
    if [[ -z $(find_notes_processes "$mount_dir") ]] && unmount_cleanly "$mount_dir"; then
      break
    fi

    mapfile -t blockers < <({ find_blockers "$mount_dir"; find_notes_processes "$mount_dir"; } | sort -un)
    if ((${#blockers[@]} == 0)); then
      printf '%s cannot be unmounted, and nothing holding it could be identified.\n' \
        "$mount_dir" >&2
    else
      report_blockers "$mount_dir" "${blockers[@]}"
    fi

    ((!force)) || break

    # No timer and no automatic escalation: this waits for an answer for as
    # long as it takes, and the answer covers this attempt only.
    answer=$(ask_blocked "$mount_dir" "${blockers[@]}") || answer=c
    case $answer in
      r | retry) continue ;;
      f | force)
        force=1
        break
        ;;
      *)
        say "$mount_dir is still unlocked."
        return 1
        ;;
    esac
  done

  if ((force)) && is_mounted "$mount_dir"; then
    stop_notes "$mount_dir" || return 1
    force_unlock_teardown "$mount_dir" "$daemon"
  fi
  verify_locked "$mount_dir" "$daemon" || die "$mount_dir was not locked"

  rm -f -- "$(runtime_record "$mount_dir")"
  update_entry
  say "$mount_dir is locked."
  say 'This ends access through the vault. It cannot unread what a program already loaded.'
  # Not at session end: there is nobody left to see it, and the notification
  # server may already be gone.
  ((ALL)) || notify "$(basename -- "$mount_dir") is locked" \
    'Access through the vault has ended.'
)

# Every vault this session unlocked, for a session ending with nobody there to
# answer. The records are a cache and are checked against the kernel before
# any of them is believed; one that names a vault nobody mounted is dropped.
lock_all() {
  local dir record mount storage status=0
  dir=$(dirname -- "$(runtime_record placeholder)")
  [[ -d $dir ]] || return 0
  for record in "$dir"/*; do
    [[ -f $record ]] || continue
    mount=$(sed -n 's/^mount=//p' "$record")
    storage=$(sed -n 's/^storage=//p' "$record")
    if [[ -z $mount ]] || ! is_mounted "$mount"; then
      rm -f -- "$record"
      continue
    fi
    [[ -n $storage ]] || storage=$(derive_storage "$mount")
    lock_one "$mount" "$storage" || status=1
  done
  return "$status"
}

cmd_lock() {
  resolve_target lock "$@"
  if ((ALL)); then
    lock_all
    return
  fi
  lock_one "$TARGET_MOUNT" "$TARGET_STORAGE"
}

cmd_toggle() {
  local lock
  resolve_target toggle "$@"
  ((!ALL)) || die 'toggle acts on one vault, not --all'

  # A second click while the first is still asking for the password would ask
  # again and then fail on a mount point the first one filled. It is dropped.
  lock="$(dirname -- "$(runtime_record placeholder)")/toggle.lock"
  mkdir -p -- "$(dirname -- "$lock")"
  exec 9>"$lock"
  flock -n 9 || exit 0

  if is_mounted "$TARGET_MOUNT"; then
    lock_one "$TARGET_MOUNT" "$TARGET_STORAGE"
  else
    cmd_open "$@"
  fi
}

main() {
  local command
  if (($# == 0)); then
    usage >&2
    exit 2
  fi
  command=$1
  shift
  case $command in
    init) cmd_init "$@" ;;
    unlock) cmd_unlock "$@" ;;
    open) cmd_open "$@" ;;
    notes) cmd_notes "$@" ;;
    lock) cmd_lock "$@" ;;
    toggle) cmd_toggle "$@" ;;
    entry) update_entry ;;
    -h | --help | help) usage ;;
    *)
      printf 'vault: unknown command: %s\n' "$command" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
