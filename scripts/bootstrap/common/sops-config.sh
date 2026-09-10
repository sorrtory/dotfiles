#!/usr/bin/env bash

# The public age recipient is configured once, in .sops.yaml, because that is
# the file sops reads when encrypting. Reading it back from there is what keeps
# recovery verifying against the recipient ciphertext is actually written to,
# rather than against a copy that can drift away from it.
#
# An age recipient is unambiguous enough to match directly, which avoids adding
# a YAML parser to the recovery closure. Anything other than exactly one
# recipient is a repository error rather than something to guess at.
#
# The file is split into whole tokens before matching, rather than searching for
# a recipient inside them. A malformed recipient must not contribute the prefix
# of itself that happens to be the right length: returning a truncated
# recipient would be worse than returning none, because it verifies against a
# key nothing was encrypted to.
sops_config_recipient() {
  local config="$1"
  local -a recipients=()

  if [[ ! -f "$config" ]]; then
    printf 'no SOPS configuration at %s\n' "$config" >&2
    return 1
  fi

  mapfile -t recipients < <(
    grep -oE '[0-9a-z]+' "$config" | grep -xE 'age1[0-9a-z]{58}' | sort -u
  )

  case "${#recipients[@]}" in
  1) printf '%s\n' "${recipients[0]}" ;;
  0)
    printf '%s names no age recipient\n' "$config" >&2
    return 1
    ;;
  *)
    printf '%s names %d age recipients; expected exactly one\n' \
      "$config" "${#recipients[@]}" >&2
    return 1
    ;;
  esac
}
