#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  printf 'Usage: archive [DIRECTORY]\nMove directory contents (default: current directory) to ~/Archive/<name>/<timestamp>/.\n'
  exit 0
fi
if (( $# > 1 )); then
  printf 'Usage: archive [DIRECTORY]\n' >&2
  exit 2
fi

source_dir=$(realpath -e -- "${1:-.}")
if [[ ! -d $source_dir || $source_dir == / ]]; then
  printf 'archive: source must be a directory other than /\n' >&2
  exit 1
fi
archive_root=$(realpath -m -- "$HOME/Archive")
case "$archive_root/" in
  "$source_dir/"*)
    printf 'archive: source contains the archive destination\n' >&2
    exit 1
    ;;
esac
case "$source_dir/" in
  "$archive_root/"*)
    printf 'archive: source is already inside Archive\n' >&2
    exit 1
    ;;
esac

parent="$archive_root/$(basename -- "$source_dir")"
if [[ -L $parent ]]; then
  printf 'archive: archive subdirectory must not be a symlink\n' >&2
  exit 1
fi
mkdir -p -- "$parent"
# Separate invocations must never merge or overwrite earlier archives.
destination=$(mktemp -d -- "$parent/$(date +%Y-%m-%d_%H-%M-%S).XXXXXX")
printf 'Archiving to %s\n' "$destination"
rsync -aH --remove-source-files -- "$source_dir/" "$destination/"
# Only remove empty subdirectories after rsync succeeds. Keep the source root.
find "$source_dir" -depth -mindepth 1 -type d -empty -delete
