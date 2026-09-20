#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

readonly YTDLP_BIN_DIR="$HOME/.local/bin"
readonly YTDLP_PATH="$YTDLP_BIN_DIR/yt-dlp"
readonly YTDLP_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
readonly YTDLP_MARKER="$YTDLP_STATE_DIR/yt-dlp-release"
readonly YTDLP_RELEASES_URL="https://github.com/yt-dlp/yt-dlp/releases"
YTDLP_TEMP_FILES=()

cleanup() {
  if [[ ${#YTDLP_TEMP_FILES[@]} -gt 0 ]]; then
    rm -f -- "${YTDLP_TEMP_FILES[@]}"
  fi
}

trap cleanup EXIT

check() {
  local version

  if [[ ! -x "$YTDLP_PATH" || ! -f "$YTDLP_MARKER" ]]; then
    phase_info 'not installed'
    return 1
  fi

  if version="$("$YTDLP_PATH" --version 2>/dev/null)"; then
    phase_info "installed: yt-dlp $version"
  else
    phase_info 'not installed correctly'
    return 1
  fi
}

install() {
  local actual_hash binary_tmp expected_hash release_dir release_page release_tag sums_tmp

  require_commands curl sha256sum
  mkdir -p -- "$YTDLP_BIN_DIR" "$YTDLP_STATE_DIR"
  binary_tmp="$(mktemp "$YTDLP_BIN_DIR/.yt-dlp.XXXXXX")"
  sums_tmp="$(mktemp "$YTDLP_BIN_DIR/.yt-dlp-sums.XXXXXX")"
  YTDLP_TEMP_FILES=("$binary_tmp" "$sums_tmp")

  phase_info 'resolving the official stable yt-dlp release...'
  release_page="$(curl --fail --location --proto '=https' --tlsv1.2 \
    --silent --show-error --output /dev/null \
    --write-out '%{url_effective}' "$YTDLP_RELEASES_URL/latest")"
  release_tag="${release_page##*/}"
  if [[ "$release_page" != "$YTDLP_RELEASES_URL/tag/"* || -z "$release_tag" ]]; then
    phase_error "unexpected yt-dlp release URL: $release_page"
    return 1
  fi
  release_dir="$YTDLP_RELEASES_URL/download/$release_tag"

  phase_info 'downloading the official stable yt-dlp release...'
  curl --fail --location --proto '=https' --tlsv1.2 \
    --silent --show-error --output "$binary_tmp" "$release_dir/yt-dlp_linux"
  curl --fail --location --proto '=https' --tlsv1.2 \
    --silent --show-error --output "$sums_tmp" "$release_dir/SHA2-256SUMS"

  expected_hash="$(awk '$2 == "yt-dlp_linux" { print $1 }' "$sums_tmp")"
  actual_hash="$(sha256sum "$binary_tmp")"
  actual_hash="${actual_hash%% *}"
  if [[ -z "$expected_hash" || "$actual_hash" != "$expected_hash" ]]; then
    phase_error 'yt-dlp release checksum verification failed'
    return 1
  fi

  chmod 0755 "$binary_tmp"
  mv -- "$binary_tmp" "$YTDLP_PATH"
  echo "release=$release_tag" >"$YTDLP_MARKER"
  phase_info 'installed the verified yt-dlp release binary'
}

is_uninstalled() {
  [[ ! -e "$YTDLP_PATH" && ! -L "$YTDLP_PATH" && \
    ! -e "$YTDLP_MARKER" && ! -L "$YTDLP_MARKER" ]]
}

uninstall() {
  rm -f -- "$YTDLP_PATH" "$YTDLP_MARKER"
  phase_info 'removed the managed yt-dlp release binary'
}

phase_main "$@"
