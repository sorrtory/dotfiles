#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
readonly REPO_ROOT
readonly PHASE_DIR='scripts/bootstrap'
readonly -a COMMON_FILES=(
  scripts/bootstrap/common/phase.sh
  scripts/bootstrap/common/output.sh
  scripts/bootstrap/common/packages.sh
)

usage() {
  printf 'Usage: %s [--staged]\n' "$0"
}

validate_shell() {
  local path="$1"
  local content

  content="$(cat)"
  if ! bash -n <<<"$content"; then
    printf '%s: invalid shell syntax\n' "$path" >&2
    return 1
  fi
}

validate_phase() {
  local path="$1"
  local content

  content="$(cat)"
  validate_shell "$path" <<<"$content" || return

  awk -v path="$path" '
    function fail(message) {
      printf "%s: %s\n", path, message > "/dev/stderr"
      invalid = 1
    }

    /^[[:space:]]*check[[:space:]]*\(\)[[:space:]]*\{/ { check_count++ }
    /^[[:space:]]*install[[:space:]]*\(\)[[:space:]]*\{/ { install_count++ }
    /^[[:space:]]*is_uninstalled[[:space:]]*\(\)[[:space:]]*\{/ { absent_count++ }
    /^[[:space:]]*uninstall[[:space:]]*\(\)[[:space:]]*\{/ { uninstall_count++ }
    /^[[:space:]]*set[[:space:]]+-euo[[:space:]]+pipefail[[:space:]]*$/ { strict_count++ }
    /^[[:space:]]*phase_main[[:space:]]+"\$@"[[:space:]]*$/ {
      entry_count++
      entry_line = NR
    }
    /^[[:space:]]*(source|\.)[[:space:]].*common\/phase\.sh/ { source_count++ }
    /^[[:space:]]*printf([[:space:]]|$)/ {
      fail("must use common phase output helpers instead of printf")
    }
    /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
    { last_code_line = NR }

    END {
      if (check_count != 1) fail("must define exactly one check()")
      if (install_count != 1) fail("must define exactly one install()")
      if (absent_count != 1) fail("must define exactly one is_uninstalled()")
      if (uninstall_count != 1) fail("must define exactly one uninstall()")
      if (strict_count != 1) fail("must enable: set -euo pipefail")
      if (source_count != 1) fail("must source common/phase.sh exactly once")
      if (entry_count != 1) fail("must end through phase_main \"$@\"")
      if (entry_count == 1 && entry_line != last_code_line) {
        fail("phase_main \"$@\" must be the final statement")
      }
      exit invalid
    }
  ' <<<"$content"
}

validate_phase_path() {
  local path="$1"
  local name="${path##*/}"

  if [[ ! "$name" =~ ^[0-9]{2}-[a-z0-9][a-z0-9-]*\.sh$ ]]; then
    printf '%s: phase name must match NN-name.sh\n' "$path" >&2
    return 1
  fi
}

check_worktree() {
  local common_file logical_name name path phase_number
  local expected_number=1
  local result=0
  declare -A names=()

  for common_file in "${COMMON_FILES[@]}"; do
    if [[ ! -f "$REPO_ROOT/$common_file" ]]; then
      printf '%s: required common module is missing\n' "$common_file" >&2
      result=1
      continue
    fi
    validate_shell "$common_file" <"$REPO_ROOT/$common_file" || result=1
  done

  shopt -s nullglob
  for path in "$REPO_ROOT/$PHASE_DIR"/*.sh; do
    path="${path#"$REPO_ROOT/"}"
    validate_phase_path "$path" || {
      result=1
      continue
    }
    if [[ ! -x "$REPO_ROOT/$path" ]]; then
      printf '%s: bootstrap phases must be executable\n' "$path" >&2
      result=1
      continue
    fi
    name="${path##*/}"
    phase_number="${name%%-*}"
    if ((10#$phase_number != expected_number)); then
      printf '%s: expected phase number %02d\n' "$path" "$expected_number" >&2
      result=1
    fi
    ((expected_number += 1))
    logical_name="${name:3:-3}"
    if [[ -n "${names[$logical_name]:-}" ]]; then
      printf '%s: duplicate logical phase name: %s\n' "$path" "$logical_name" >&2
      result=1
    fi
    names[$logical_name]=1
    validate_phase "$path" <"$REPO_ROOT/$path" || result=1
  done
  shopt -u nullglob

  return "$result"
}

check_staged() {
  local common_file content logical_name metadata mode name path phase_number record
  local expected_number=1
  local result=0
  declare -A names=()
  declare -A seen_common=()

  while IFS= read -r -d '' record; do
    metadata="${record%%$'\t'*}"
    path="${record#*$'\t'}"
    mode="${metadata%% *}"
    [[ "$path" == *.sh ]] || continue
    content="$(git -C "$REPO_ROOT" show ":$path")"

    if [[ "$path" == "$PHASE_DIR/common/"* ]]; then
      seen_common[$path]=1
      validate_shell "$path" <<<"$content" || result=1
      continue
    fi

    validate_phase_path "$path" || {
      result=1
      continue
    }
    if [[ "$mode" != 100755 ]]; then
      printf '%s: bootstrap phases must be executable\n' "$path" >&2
      result=1
      continue
    fi
    name="${path##*/}"
    phase_number="${name%%-*}"
    if ((10#$phase_number != expected_number)); then
      printf '%s: expected phase number %02d\n' "$path" "$expected_number" >&2
      result=1
    fi
    ((expected_number += 1))
    logical_name="${name:3:-3}"
    if [[ -n "${names[$logical_name]:-}" ]]; then
      printf '%s: duplicate logical phase name: %s\n' "$path" "$logical_name" >&2
      result=1
    fi
    names[$logical_name]=1
    validate_phase "$path" <<<"$content" || result=1
  done < <(git -C "$REPO_ROOT" ls-files --cached --stage -z -- "$PHASE_DIR")

  for common_file in "${COMMON_FILES[@]}"; do
    if [[ -z "${seen_common[$common_file]:-}" ]]; then
      printf '%s: required common module is missing\n' "$common_file" >&2
      result=1
    fi
  done

  return "$result"
}

case "${1:-}" in
'')
  check_worktree
  ;;
--staged)
  [[ $# -eq 1 ]] || {
    usage >&2
    exit 64
  }
  check_staged
  ;;
*)
  usage >&2
  exit 64
  ;;
esac
