#!/usr/bin/env bash
# Pack each theme directory into <name>.tdesktop-theme next to it.
# Usage: ./build.sh [theme-dir...]   (default: every theme here)

set -euo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")"

(($#)) || set -- */

for dir in "$@"; do
  dir="${dir%/}"
  out="$PWD/$dir.tdesktop-theme"
  rm -f "$out"
  (cd "$dir" && zip -qX "$out" colors.tdesktop-theme background.*)
  echo "$out"
done
