#!/usr/bin/env bash

set -euo pipefail

# Canonical contract: docs/DECISIONS.md#bootstrap-policy

REPO_ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
readonly REPO_ROOT
readonly COMPONENT_DIR='scripts/bootstrap'
readonly COMMON_PATH="$COMPONENT_DIR/common/common.sh"

usage() {
  printf 'Usage: %s [--staged]\n' "$0"
}

validate_common() {
  local path="$1"

  if ! awk -v path="$path" '
    function fail(message) {
      printf "%s: %s\n", path, message > "/dev/stderr"
      invalid = 1
    }

    BEGIN {
      split("component_name component_info component_error already_installed already_uninstalled require_commands component_main", required)
    }

    /^[[:space:]]*(component_name|component_info|component_error|already_installed|already_uninstalled|require_commands|component_main)[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*$/ {
      name = $0
      sub(/^[[:space:]]*/, "", name)
      sub(/[[:space:]]*\(.*/, "", name)
      definitions[name]++
      current_function = name
    }

    current_function == "component_name" &&
      /^[[:space:]]*basename[[:space:]]+--[[:space:]]+"\$0"[[:space:]]+\.sh[[:space:]]*$/ {
      component_name_body++
    }

    current_function == "component_info" &&
      /printf.*\[%s\][[:space:]]+%s\\n.*component_name.*\$1/ &&
      $0 !~ />&2[[:space:]]*$/ {
      info_output++
    }

    current_function == "component_error" &&
      /printf.*\[%s\][[:space:]]+%s\\n.*component_name.*\$1.*>&2[[:space:]]*$/ {
      error_output++
    }

    current_function == "already_installed" &&
      /^[[:space:]]*component_error[[:space:]]+.*already installed/ {
      already_installed_body++
    }

    current_function == "already_uninstalled" &&
      /^[[:space:]]*component_error[[:space:]]+.*not installed/ {
      already_uninstalled_body++
    }

    current_function == "component_main" &&
      /^[[:space:]]*(status|install|uninstall)\)[[:space:]]*$/ {
      branch = $0
      sub(/^[[:space:]]*/, "", branch)
      sub(/\).*/, "", branch)
      branches[branch]++
      current_branch = branch
    }

    current_function == "component_main" &&
      /^[[:space:]]*(check|install|uninstall)[[:space:]]*$/ {
      delegate = $0
      gsub(/[[:space:]]/, "", delegate)
      dispatch[current_branch ":" delegate]++
    }

    current_function == "component_main" && /^[[:space:]]*;;[[:space:]]*$/ {
      current_branch = ""
    }

    /^[[:space:]]*}[[:space:]]*$/ {
      current_function = ""
      current_branch = ""
    }

    END {
      for (i in required) {
        name = required[i]
        if (definitions[name] != 1) {
          fail("must define exactly one " name "() function")
        }
      }
      if (component_name_body != 1) {
        fail("component_name() must derive the name from $0")
      }
      if (info_output != 1 || error_output != 1) {
        fail("info and error output must use the [component] prefix and correct streams")
      }
      if (already_installed_body != 1 || already_uninstalled_body != 1) {
        fail("repeated-operation helpers must report through component_error")
      }
      if (branches["status"] != 1 || dispatch["status:check"] != 1 ||
          branches["install"] != 1 || dispatch["install:install"] != 1 ||
          branches["uninstall"] != 1 || dispatch["uninstall:uninstall"] != 1) {
        fail("component_main() must dispatch status, install, and uninstall")
      }
      exit invalid
    }
  '; then
    return 1
  fi
}

validate_component() {
  local path="$1"

  if ! awk -v path="$path" '
    function fail(message) {
      printf "%s: %s\n", path, message > "/dev/stderr"
      invalid = 1
    }

    $0 !~ /^[[:space:]]*($|#)/ {
      last_statement = $0
      sub(/^[[:space:]]*/, "", last_statement)
      sub(/[[:space:]]*$/, "", last_statement)
    }

    /^[[:space:]]*check[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*$/ {
      check_count++
    }

    /^[[:space:]]*is_uninstalled[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*$/ {
      is_uninstalled_count++
    }

    /^[[:space:]]*\.[[:space:]]+.*common\/common\.sh/ {
      common_source_count++
    }

    /^[[:space:]]*component_main[[:space:]]+"\$@"[[:space:]]*$/ {
      main_count++
    }

    /^[[:space:]]*(install|uninstall)[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*$/ {
      function_name = $0
      sub(/^[[:space:]]*/, "", function_name)
      sub(/[[:space:]]*\(.*/, "", function_name)
      if (function_name == "install") {
        install_count++
        guard_state = 1
      } else {
        uninstall_count++
        guard_state = 5
      }
      next
    }

    $0 !~ /^[[:space:]]*#/ &&
      $0 ~ /(^|[^[:alnum:]_])printf([^[:alnum:]_]|$)/ {
      fail("must use the common component output helpers instead of printf")
    }

    guard_state && ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) {
      next
    }

    guard_state == 1 {
      if ($0 !~ /^[[:space:]]*if[[:space:]]+check[[:space:]]*>\/dev\/null;[[:space:]]*then[[:space:]]*$/) {
        fail("install() must begin with: if check >/dev/null; then")
        guard_state = 0
      } else {
        guard_state = 2
      }
      next
    }

    guard_state == 2 {
      if ($0 !~ /^[[:space:]]*already_installed[[:space:]]*$/) {
        fail("a satisfied check must call already_installed")
        guard_state = 0
      } else {
        guard_state = 3
      }
      next
    }

    guard_state == 3 {
      if ($0 !~ /^[[:space:]]*return[[:space:]]+1[[:space:]]*$/) {
        fail("the check guard must return 1 after already_installed")
        guard_state = 0
      } else {
        guard_state = 4
      }
      next
    }

    guard_state == 4 {
      if ($0 !~ /^[[:space:]]*fi[[:space:]]*$/) {
        fail("the check guard must end immediately after return 1")
      }
      guard_state = 0
      next
    }

    guard_state == 5 {
      if ($0 !~ /^[[:space:]]*if[[:space:]]+is_uninstalled;[[:space:]]*then[[:space:]]*$/) {
        fail("uninstall() must begin with: if is_uninstalled; then")
        guard_state = 0
      } else {
        guard_state = 6
      }
      next
    }

    guard_state == 6 {
      if ($0 !~ /^[[:space:]]*already_uninstalled[[:space:]]*$/) {
        fail("a satisfied is_uninstalled must call already_uninstalled")
        guard_state = 0
      } else {
        guard_state = 7
      }
      next
    }

    guard_state == 7 {
      if ($0 !~ /^[[:space:]]*return[[:space:]]+1[[:space:]]*$/) {
        fail("the uninstall check guard must return 1 after already_uninstalled")
        guard_state = 0
      } else {
        guard_state = 8
      }
      next
    }

    guard_state == 8 {
      if ($0 !~ /^[[:space:]]*fi[[:space:]]*$/) {
        fail("the uninstall check guard must end immediately after return 1")
      }
      guard_state = 0
      next
    }

    END {
      if (common_source_count != 1) {
        fail("must source bootstrap/common/common.sh exactly once")
      }
      if (check_count != 1) {
        fail("must define exactly one check() function")
      }
      if (install_count != 1) {
        fail("must define exactly one install() function")
      }
      if (uninstall_count != 1) {
        fail("must define exactly one uninstall() function")
      }
      if (is_uninstalled_count != 1) {
        fail("must define exactly one is_uninstalled() function")
      }
      if (main_count != 1 || last_statement != "component_main \"$@\"") {
        fail("must end with exactly one component_main \"$@\" entrypoint")
      }
      if (guard_state) {
        fail("component has an incomplete check guard")
      }
      exit invalid
    }
  '; then
    return 1
  fi
}

check_worktree() {
  local path
  local result=0

  if [[ ! -f "$REPO_ROOT/$COMMON_PATH" || -x "$REPO_ROOT/$COMMON_PATH" ]]; then
    printf '%s: common interface must exist and be non-executable\n' \
      "$COMMON_PATH" >&2
    result=1
  else
    validate_common "$COMMON_PATH" <"$REPO_ROOT/$COMMON_PATH" || result=1
  fi

  shopt -s nullglob
  for path in "$REPO_ROOT/$COMPONENT_DIR"/*.sh; do
    if [[ ! -x "$path" ]]; then
      printf '%s: bootstrap components must be executable\n' \
        "${path#"$REPO_ROOT/"}" >&2
      result=1
      continue
    fi
    validate_component "${path#"$REPO_ROOT/"}" <"$path" || result=1
  done

  return "$result"
}

check_staged() {
  local common_mode metadata path record
  local result=0

  common_mode="$(
    git -C "$REPO_ROOT" ls-files --cached --stage -- "$COMMON_PATH" |
      awk 'NR == 1 { print $1 }'
  )"
  if [[ "$common_mode" != 100644 ]]; then
    printf '%s: staged common interface must exist and be non-executable\n' \
      "$COMMON_PATH" >&2
    result=1
  else
    git -C "$REPO_ROOT" show ":$COMMON_PATH" |
      validate_common "$COMMON_PATH" || result=1
  fi

  while IFS= read -r -d '' record; do
    metadata="${record%%$'\t'*}"
    path="${record#*$'\t'}"
    if [[ "${metadata%% *}" != 100755 ]]; then
      printf '%s: bootstrap components must be executable\n' "$path" >&2
      result=1
      continue
    fi
    git -C "$REPO_ROOT" show ":$path" |
      validate_component "$path" || result=1
  done < <(
    git -C "$REPO_ROOT" ls-files --cached --stage -z -- \
      ":(top,glob)$COMPONENT_DIR/*.sh"
  )

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
