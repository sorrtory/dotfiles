#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

readonly DOCKER_INSTALL_URL="https://get.docker.com"
TARGET_USER="$(id -un)"
readonly TARGET_USER
readonly -a DOCKER_PACKAGES=(
  containerd.io
  docker-buildx-plugin
  docker-ce
  docker-ce-cli
  docker-ce-rootless-extras
  docker-compose-plugin
  docker-model-plugin
)
readonly -a DOCKER_REPOSITORY_PATHS=(
  /etc/apt/keyrings/docker.asc
  /etc/apt/keyrings/docker.gpg
  /etc/apt/sources.list.d/docker.list
  /etc/apt/sources.list.d/docker.sources
  /etc/yum.repos.d/docker-ce.repo
)
readonly -a DOCKER_DATA_PATHS=(
  /var/lib/docker
  /var/lib/containerd
)
DOCKER_INSTALLER_TMP=''

cleanup() {
  if [[ -n "$DOCKER_INSTALLER_TMP" ]]; then
    rm -f -- "$DOCKER_INSTALLER_TMP"
  fi
}

trap cleanup EXIT

docker_group_member() {
  local group

  while IFS= read -r group; do
    [[ "$group" == docker ]] && return
  done < <(id -nG "$TARGET_USER" | tr ' ' '\n')

  return 1
}

docker_components_available() {
  command -v docker >/dev/null 2>&1 &&
    docker --version >/dev/null 2>&1 &&
    docker compose version >/dev/null 2>&1 &&
    docker buildx version >/dev/null 2>&1
}

docker_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo apt-get
  elif command -v dnf >/dev/null 2>&1; then
    echo dnf
  else
    return 1
  fi
}

installed_docker_packages() {
  local package package_manager="$1" status

  for package in "${DOCKER_PACKAGES[@]}"; do
    case "$package_manager" in
    apt-get)
      if status="$(dpkg-query --show --showformat='${db:Status-Abbrev}' \
        "$package" 2>/dev/null)" && [[ "$status" == ii* ]]; then
        echo "$package"
      fi
      ;;
    dnf)
      if rpm --quiet --query "$package"; then
        echo "$package"
      fi
      ;;
    esac
  done
}

system_path_exists() {
  stat "$1" >/dev/null 2>&1
}

check() {
  local version

  if ! docker_components_available; then
    phase_info 'Docker Engine, Compose, or Buildx is not installed'
    return 1
  fi

  if ! docker_group_member; then
    phase_info "Docker is installed, but $TARGET_USER is not in the docker group"
    return 1
  fi

  version="$(docker --version)"
  phase_info "installed: $version; $TARGET_USER belongs to the docker group"
}

install() {
  local package_manager

  if [[ $EUID -eq 0 ]]; then
    phase_error 'run this phase as the target user, not as root'
    return 1
  fi

  require_commands id sudo tr
  sudo -v

  if ! docker_components_available; then
    require_commands curl sh
    if ! package_manager="$(docker_package_manager)"; then
      phase_error 'Docker bootstrap supports APT and DNF hosts'
      return 1
    fi
    DOCKER_INSTALLER_TMP="$(mktemp "${TMPDIR:-/tmp}/docker-install.XXXXXX")"
    phase_info 'downloading the official Docker convenience installer...'
    curl --fail --location --proto '=https' --tlsv1.2 \
      --silent --show-error --output "$DOCKER_INSTALLER_TMP" "$DOCKER_INSTALL_URL"
    phase_info 'validating the installer package plan...'
    sh "$DOCKER_INSTALLER_TMP" --dry-run
    phase_info 'installing Docker Engine, Compose, and Buildx...'
    sudo sh "$DOCKER_INSTALLER_TMP"
  fi

  if ! docker_group_member; then
    phase_info "adding $TARGET_USER to the docker group..."
    sudo usermod -aG docker "$TARGET_USER"
    phase_info 'Docker group membership applies fully after the next login'
  fi
}

is_uninstalled() {
  local package_manager path
  local -a installed_packages=()

  if ! command -v stat >/dev/null 2>&1; then
    phase_error 'cannot inspect Docker system paths: stat is missing'
    return 2
  fi
  docker --version >/dev/null 2>&1 && return 1
  docker_group_member && return 1

  if package_manager="$(docker_package_manager)"; then
    case "$package_manager" in
    apt-get) command -v dpkg-query >/dev/null 2>&1 || return 2 ;;
    dnf) command -v rpm >/dev/null 2>&1 || return 2 ;;
    esac
    mapfile -t installed_packages < <(
      installed_docker_packages "$package_manager"
    )
    [[ ${#installed_packages[@]} -gt 0 ]] && return 1
  fi

  for path in "${DOCKER_REPOSITORY_PATHS[@]}" "${DOCKER_DATA_PATHS[@]}"; do
    system_path_exists "$path" && return 1
  done

  return 0
}

uninstall() {
  local package_manager
  local -a installed_packages=()

  if [[ $EUID -eq 0 ]]; then
    phase_error 'run this phase as the target user, not as root'
    return 1
  fi
  require_commands stat sudo
  if ! package_manager="$(docker_package_manager)"; then
    phase_error 'Docker uninstall supports APT and DNF hosts'
    return 1
  fi
  case "$package_manager" in
  apt-get) require_commands dpkg-query ;;
  dnf) require_commands rpm ;;
  esac
  sudo -v

  if docker_group_member; then
    require_commands gpasswd
    phase_info "removing $TARGET_USER from the docker group..."
    sudo gpasswd -d "$TARGET_USER" docker
  fi

  mapfile -t installed_packages < <(
    installed_docker_packages "$package_manager"
  )
  if [[ ${#installed_packages[@]} -gt 0 ]]; then
    phase_info 'removing Docker packages...'
    case "$package_manager" in
    apt-get) sudo apt-get purge -y "${installed_packages[@]}" ;;
    dnf) sudo dnf remove -y "${installed_packages[@]}" ;;
    esac
  fi

  phase_info 'removing Docker repository configuration and all local Docker data...'
  sudo rm -f -- "${DOCKER_REPOSITORY_PATHS[@]}"
  sudo rm -rf -- "${DOCKER_DATA_PATHS[@]}"
  phase_info 'removed Docker packages, repository setup, images, containers, and volumes'
  phase_info 'Docker group removal applies fully after the next login'
}

phase_main "$@"
