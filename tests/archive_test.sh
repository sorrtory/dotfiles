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
bash "$archive" "$HOME/Downloads"
destinations=("$HOME"/Archive/Downloads/*)
destination=${destinations[0]}
[[ $(cat "$destination/nested/a file") == data ]] || fail 'file contents'
[[ -f $destination/.hidden && -L $destination/link ]] || fail 'hidden file or symlink'
[[ $destination/hardlink -ef "$destination/nested/a file" ]] || fail 'hard links'
[[ -d $destination/nested/empty ]] || fail 'empty directory not preserved'
[[ -d $HOME/Downloads && -z $(ls -A "$HOME/Downloads") ]] || fail 'source not emptied'
printf 'second\n' >"$HOME/Downloads/.hidden"
(cd "$HOME/Downloads" && bash "$archive")
destinations=("$HOME"/Archive/Downloads/*)
[[ ${#destinations[@]} == 2 ]] || fail 'archives merged'
[[ $(cat "$destination/.hidden") == hidden ]] || fail 'previous archive overwritten'

for source in / "$HOME" "$HOME/Archive" "$destination"; do
  if bash "$archive" "$source" >/dev/null 2>&1; then fail "accepted unsafe source: $source"; fi
done
ln -s "$HOME/Archive" "$TEST_ROOT/archive-link"
if bash "$archive" "$TEST_ROOT/archive-link" >/dev/null 2>&1; then fail 'accepted archive symlink'; fi

# A failed transfer must not run directory cleanup or remove untransferred data.
mkdir -p "$TEST_ROOT/bin" "$HOME/Failed/empty"
printf 'keep\n' >"$HOME/Failed/file"
printf '#!/bin/sh\nexit 23\n' >"$TEST_ROOT/bin/rsync"
chmod +x "$TEST_ROOT/bin/rsync"
if PATH="$TEST_ROOT/bin:$PATH" bash "$archive" "$HOME/Failed"; then fail 'hid rsync failure'; fi
[[ -f $HOME/Failed/file && -d $HOME/Failed/empty ]] || fail 'failure lost source data'
printf 'archive tests passed\n'
