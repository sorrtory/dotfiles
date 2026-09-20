#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

readonly NIX_INSTALL_URL="https://nixos.org/nix/install"
readonly NIX_CONFIG_FILE="/etc/nix/nix.conf"
readonly UPSTREAM_NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
readonly FEDORA_NIX_DAEMON_PROFILE="/etc/profile.d/nix-daemon.sh"
readonly NIX_DAEMON_SOCKET="/nix/var/nix/daemon-socket/socket"

# NIX_DAEMON_PROFILE remains an optional test/escape-hatch override.  If it is
# unset, Fedora uses its RPM-owned profile and other hosts use upstream's path.
readonly NIX_DAEMON_PROFILE="${NIX_DAEMON_PROFILE:-}"

readonly -a NIX_SHELL_FILES=(
  /etc/bash.bashrc
  /etc/bashrc
  /etc/profile
  /etc/zsh/zshrc
  /etc/zshrc
)

# These are paths created by the upstream multi-user installer.  Fedora's RPM
# installation is deliberately not removed through this list.
readonly -a UPSTREAM_NIX_OWNED_PATHS=(
  /etc/nix
  /etc/profile.d/nix.sh
  /etc/tmpfiles.d/nix-daemon.conf
  /etc/systemd/system/nix-daemon.service
  /etc/systemd/system/nix-daemon.socket
  /etc/systemd/system/multi-user.target.wants/nix-daemon.service
  /etc/systemd/system/sockets.target.wants/nix-daemon.socket
  /nix
  /root/.nix-channels
  /root/.nix-defexpr
  /root/.nix-profile
)

host_os_value() {
  local key="$1"
  local os_release_file="${BOOTSTRAP_OS_RELEASE_FILE:-/etc/os-release}"
  local ID=''
  local ID_LIKE=''
  local VERSION_ID=''

  [[ -r "$os_release_file" ]] || return 1
  # shellcheck disable=SC1090
  . "$os_release_file"

  case "$key" in
  id) echo "${ID:-}" ;;
  id_like) echo "${ID_LIKE:-}" ;;
  version_id) echo "${VERSION_ID:-}" ;;
  *) return 2 ;;
  esac
}

is_fedora() {
  [[ "$(host_os_value id 2>/dev/null || true)" == fedora ]]
}

nix_daemon_profile_path() {
  if [[ -n "$NIX_DAEMON_PROFILE" ]]; then
    echo "$NIX_DAEMON_PROFILE"
  elif is_fedora; then
    echo "$FEDORA_NIX_DAEMON_PROFILE"
  else
    echo "$UPSTREAM_NIX_DAEMON_PROFILE"
  fi
}

load_nix_profile() {
  local profile

  profile="$(nix_daemon_profile_path)"
  # An explicit success: a bare `return` hands back the status of the failed
  # test, so on a host with no Nix yet this reported failure and check() gave
  # up before it could say "not installed" -- silent on the one machine where
  # the message matters most.
  if [[ ! -e "$profile" ]]; then
    return 0
  fi

  # shellcheck disable=SC1090
  if ! . "$profile"; then
    phase_error "cannot load the Nix daemon profile: $profile"
    return 2
  fi
}

path_present() {
  [[ -e "$1" || -L "$1" ]]
}

fedora_nix_packages_present() {
  command -v rpm >/dev/null 2>&1 || return 1
  rpm -q nix nix-daemon >/dev/null 2>&1
}

fedora_nix_any_package_present() {
  local package

  command -v rpm >/dev/null 2>&1 || return 1
  for package in nix nix-daemon nix-core nix-system nix-filesystem; do
    if rpm -q "$package" >/dev/null 2>&1; then
      return
    fi
  done
  return 1
}

fedora_multi_user_nix_installed() {
  fedora_nix_packages_present || return 1
  [[ -e "$FEDORA_NIX_DAEMON_PROFILE" ]] || return 1

  # Fedora 44's documented setup enables the service itself:
  #   systemctl enable --now nix-daemon
  # Do not require nix-daemon.socket to be enabled.
  systemctl is-enabled --quiet nix-daemon.service >/dev/null 2>&1 || return 1
  systemctl is-active --quiet nix-daemon.service >/dev/null 2>&1 || return 1

  [[ -S "$NIX_DAEMON_SOCKET" ]]
}

multi_user_nix_installed() {
  local profile

  if is_fedora; then
    fedora_multi_user_nix_installed
    return
  fi

  profile="$(nix_daemon_profile_path)"
  [[ -e "$profile" && -S "$NIX_DAEMON_SOCKET" ]]
}

shell_file_has_nix_state() {
  local line
  local path="$1"

  path_present "$path.backup-before-nix" && return
  [[ -f "$path" ]] || return 1
  if [[ ! -r "$path" ]]; then
    phase_error "cannot inspect Nix shell state: $path is not readable"
    return 2
  fi

  while IFS= read -r line; do
    case "$line" in
    '# Nix' | '# End Nix')
      return
      ;;
    esac
  done <"$path"

  return 1
}

nss_entry_absent() {
  local result
  local database="$1"
  local key="$2"

  if getent "$database" "$key" >/dev/null; then
    return 1
  else
    result=$?
  fi

  [[ $result -eq 2 ]] && return

  phase_error "cannot inspect $database entry $key: getent exited $result"
  return 2
}

fedora_is_uninstalled() {
  local package path

  if command -v rpm >/dev/null 2>&1; then
    for package in nix nix-daemon nix-core nix-system nix-filesystem; do
      if rpm -q "$package" >/dev/null 2>&1; then
        return 1
      fi
    done
  fi

  # Fedora creates nixbld-* users through systemd-sysusers.  System accounts
  # may intentionally survive package removal, so they are not used as the
  # uninstall sentinel.  Files/package state is authoritative here.
  for path in \
    /nix \
    /etc/nix \
    "$FEDORA_NIX_DAEMON_PROFILE" \
    /usr/bin/nix-daemon \
    /usr/lib/systemd/system/nix-daemon.service \
    /usr/lib/systemd/system/nix-daemon.socket; do
    path_present "$path" && return 1
  done

  return 0
}

upstream_is_uninstalled() {
  local id path result

  for path in "${UPSTREAM_NIX_OWNED_PATHS[@]}"; do
    path_present "$path" && return 1
  done

  for path in "${NIX_SHELL_FILES[@]}"; do
    if shell_file_has_nix_state "$path"; then
      return 1
    else
      result=$?
    fi
    [[ $result -eq 1 ]] || return "$result"
  done

  if ! command -v getent >/dev/null 2>&1; then
    phase_error 'cannot inspect Nix build accounts: getent is missing'
    return 2
  fi
  nss_entry_absent group nixbld || return $?
  for id in {1..32}; do
    nss_entry_absent passwd "nixbld$id" || return $?
  done

  return 0
}

is_uninstalled() {
  if is_fedora; then
    fedora_is_uninstalled
  else
    upstream_is_uninstalled
  fi
}

flakes_enabled() {
  local features result

  if features="$(nix config show experimental-features 2>/dev/null)"; then
    :
  else
    result=$?
    # Newer Nix refuses this query until nix-command is enabled, which answers
    # the question rather than failing to.
    if [[ "$(nix config show experimental-features 2>&1 >/dev/null)" == *"experimental Nix feature 'nix-command' is disabled"* ]]; then
      return 1
    fi
    phase_error "cannot inspect Nix experimental features: nix exited $result"
    return 2
  fi

  [[ " $features " == *' nix-command '* && " $features " == *' flakes '* ]]
}

check() {
  local result version

  load_nix_profile || return $?

  if ! command -v nix >/dev/null 2>&1; then
    phase_info 'not installed'
    return 1
  fi

  if version="$(nix --version 2>/dev/null)"; then
    :
  else
    result=$?
    phase_error "cannot inspect the Nix version: nix exited $result"
    return 2
  fi

  if ! multi_user_nix_installed; then
    phase_info "not installed correctly: $version"
    return 1
  fi

  if flakes_enabled; then
    phase_info "installed correctly: $version"
    return
  else
    result=$?
  fi

  [[ $result -eq 1 ]] || return "$result"
  phase_info "not installed correctly: $version"
  return 1
}

restart_nix_daemon() {
  if is_fedora; then
    sudo systemctl restart nix-daemon
  else
    sudo systemctl restart nix-daemon.service
  fi
}

enable_flakes() {
  local result

  if flakes_enabled; then
    return
  else
    result=$?
  fi
  [[ $result -eq 1 ]] || return "$result"

  phase_info 'enabling nix-command and flakes...'
  sudo mkdir -p -- "$(dirname -- "$NIX_CONFIG_FILE")"
  sudo tee --append "$NIX_CONFIG_FILE" >/dev/null <<'EOF'

extra-experimental-features = nix-command flakes
EOF
  restart_nix_daemon
}

wait_for_nix_daemon() {
  local attempt

  for attempt in {1..50}; do
    if [[ -S "$NIX_DAEMON_SOCKET" ]] &&
      systemctl is-active --quiet nix-daemon.service >/dev/null 2>&1; then
      return
    fi
    sleep 0.1
  done

  phase_error "Nix daemon did not become ready at $NIX_DAEMON_SOCKET"
  return 1
}

install_nix_fedora() {
  local fedora_version

  require_commands dnf rpm sudo systemctl
  phase_info 'validating sudo access...'
  sudo -v

  fedora_version="$(host_os_value version_id 2>/dev/null || true)"

  # Do not silently combine an upstream /nix installation with Fedora's RPMs.
  # A partially installed Fedora RPM set is fine; dnf below repairs it.
  if ! rpm -q nix >/dev/null 2>&1 &&
    [[ -e "$UPSTREAM_NIX_DAEMON_PROFILE" ]]; then
    phase_error 'an upstream Nix installation already exists; uninstall it before switching to Fedora packages.'
    return 1
  fi

  phase_info "installing Fedora ${fedora_version:-unknown} Nix packages..."
  sudo dnf install -y nix nix-daemon

  # This is the Fedora 44 documented multi-user setup. systemctl resolves the
  # bare name to nix-daemon.service and creates the normal service enablement
  # symlink. The packaged nix-daemon.socket unit need not be enabled.
  phase_info 'enabling the Fedora Nix daemon service...'
  sudo systemctl enable --now nix-daemon

  wait_for_nix_daemon

  if [[ ! -e "$FEDORA_NIX_DAEMON_PROFILE" ]]; then
    phase_error "Fedora nix-daemon package did not install $FEDORA_NIX_DAEMON_PROFILE"
    return 1
  fi
}

install_nix_upstream() (
  local installer installer_dir

  require_commands curl sudo
  phase_info 'validating sudo access...'
  sudo -v

  installer_dir="$(mktemp -d)"
  trap 'rm -rf -- "$installer_dir"' EXIT
  installer="$installer_dir/install-nix"

  phase_info 'downloading the official Nix installer...'
  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "$installer" "$NIX_INSTALL_URL"

  phase_info 'starting the multi-user Nix installation...'
  sh "$installer" --daemon --yes
)

install() {
  local result version

  require_commands git

  if is_fedora; then
    # Fedora installation is intentionally reparative: if nix is installed but
    # the daemon package/service is missing or disabled, rerunning bootstrap
    # brings it back to the supported Fedora multi-user state.
    install_nix_fedora
    hash -r
    load_nix_profile
  else
    load_nix_profile

    if ! command -v nix >/dev/null 2>&1; then
      if upstream_is_uninstalled; then
        :
      else
        result=$?
        if [[ $result -eq 1 ]]; then
          phase_error 'partial Nix state exists; uninstall it explicitly before installing.'
          return 1
        fi
        return "$result"
      fi
    fi

    if command -v nix >/dev/null 2>&1; then
      if ! multi_user_nix_installed; then
        phase_error 'existing Nix installation is not a supported multi-user installation.'
        return 1
      fi
      require_commands sudo
      phase_info 'validating sudo access...'
      sudo -v
    else
      install_nix_upstream
      load_nix_profile
    fi
  fi

  if ! command -v nix >/dev/null 2>&1; then
    phase_error 'Nix installation completed but nix is not available in PATH.'
    return 1
  fi

  enable_flakes

  if version="$(nix --version 2>/dev/null)"; then
    phase_info "installed $version"
  else
    result=$?
    phase_error "cannot inspect the installed Nix version: nix exited $result"
    return 2
  fi

  phase_info 'open a new login shell before using Nix interactively.'
}

remove_shell_references() {
  local backup path

  for path in "${NIX_SHELL_FILES[@]}"; do
    backup="$path.backup-before-nix"
    if [[ -f "$path" ]] && shell_file_has_nix_state "$path"; then
      if ! awk '
        /^# Nix$/ { if (inside) invalid = 1; inside = 1 }
        /^# End Nix$/ { if (!inside) invalid = 1; inside = 0 }
        END { exit invalid || inside }
      ' "$path"; then
        phase_error "cannot safely remove an incomplete Nix block from $path"
        return 1
      fi
      sudo sed --in-place '/^# Nix$/,/^# End Nix$/d' "$path"
    fi

    if path_present "$backup"; then
      sudo rm -f -- "$backup"
    fi
  done
}

remove_build_users() {
  local id user

  for id in {1..32}; do
    user="nixbld$id"
    if getent passwd "$user" >/dev/null; then
      sudo userdel "$user"
    fi
  done

  if getent group nixbld >/dev/null; then
    sudo groupdel nixbld
  fi
}

uninstall_nix_fedora() {
  local package
  local -a installed_packages=()

  require_commands dnf rpm sudo systemctl

  phase_info 'stopping and disabling the Fedora Nix daemon...'
  sudo systemctl disable --now nix-daemon.service >/dev/null 2>&1 || true
  sudo systemctl disable --now nix-daemon.socket >/dev/null 2>&1 || true

  for package in nix nix-daemon nix-core nix-system nix-filesystem; do
    if rpm -q "$package" >/dev/null 2>&1; then
      installed_packages+=("$package")
    fi
  done

  if [[ ${#installed_packages[@]} -gt 0 ]]; then
    phase_info 'removing Fedora Nix packages...'
    sudo dnf remove -y "${installed_packages[@]}"
  fi

  # The bootstrap's uninstall contract is a full removal.  RPMs cannot remove
  # a populated /nix store, and modified config files can survive as state.
  phase_info 'removing remaining Nix store and configuration...'
  sudo rm -rf -- \
    /nix \
    /etc/nix \
    /root/.nix-channels \
    /root/.nix-defexpr \
    /root/.nix-profile

  sudo systemctl daemon-reload
}

uninstall_nix_upstream() {
  local unit
  local -a units=()

  require_commands awk getent groupdel sed sudo systemctl userdel

  phase_info 'stopping and disabling the Nix daemon...'
  if systemctl cat nix-daemon.service >/dev/null 2>&1; then
    sudo systemctl stop nix-daemon.service
  fi
  for unit in nix-daemon.socket nix-daemon.service; do
    if systemctl cat "$unit" >/dev/null 2>&1; then
      units+=("$unit")
    fi
  done
  if [[ ${#units[@]} -gt 0 ]]; then
    sudo systemctl disable "${units[@]}"
  fi
  sudo systemctl daemon-reload

  phase_info 'removing Nix shell startup references...'
  remove_shell_references

  phase_info 'removing Nix-owned files...'
  sudo rm -rf -- "${UPSTREAM_NIX_OWNED_PATHS[@]}"

  phase_info 'removing Nix build users and group...'
  remove_build_users
}

uninstall() {
  local result

  require_commands sudo
  phase_info 'validating sudo access...'
  sudo -v

  if is_fedora && fedora_nix_any_package_present; then
    uninstall_nix_fedora
  else
    uninstall_nix_upstream
  fi

  if is_uninstalled; then
    phase_info 'uninstalled successfully.'
    return
  else
    result=$?
  fi

  if [[ $result -eq 1 ]]; then
    phase_error 'uninstall finished with unrecognized or incomplete Nix state remaining.'
    return 1
  fi
  return "$result"
}

phase_main "$@"
