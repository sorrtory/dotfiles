#!/usr/bin/env bash
# Sublime Text's side of the theme: a scheme per theme under one stable name,
# valid for Sublime to load, and overrides that reach it.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v jq >/dev/null || fail 'jq must be on PATH'

scheme_path="$HOME/.config/sublime-text/Packages/User/Dotfiles.sublime-color-scheme"

scheme() {
  nix build --impure --no-link --print-out-paths --expr "((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
    modules = [ ({ lib, ... }: { dotfiles.theme = lib.mapAttrs (_: lib.mkForce) ($1); }) ];
  }).config.dotfiles.theme.liveFiles.\"$scheme_path\"" 2>/dev/null || fail "scheme for $1"
}

# Preferences name the generated scheme, permanently. Sublime's settings are
# JSON with comments and trailing commas, so this is a line match rather than
# a parse.
grep -qF '"color_scheme": "Dotfiles.sublime-color-scheme"' \
  "$REPO_ROOT/configs/sublime-text/Preferences.sublime-settings" ||
  fail 'Preferences do not select the generated scheme'
[[ ! -e "$REPO_ROOT/configs/sublime-text/Gruvbox Rewaita.sublime-color-scheme" ]] ||
  fail 'the hand-made scheme is still in the repository'

for theme in gruvbox autumn-leaves onedark; do
  file=$(scheme "{ name = \"$theme\"; }")
  jq -e . "$file" >/dev/null || fail "$theme: the scheme is not valid JSON"
  jq -e '.name == "Dotfiles"' "$file" >/dev/null || fail "$theme: the scheme is not named Dotfiles"

  # Sublime ignores a scheme with a malformed color and logs to its console,
  # which nothing here can read, so the colors are checked instead: a hex, or
  # one of its own color() expressions.
  bad=$(jq -r '[.globals | to_entries[] | select(.key | test("options$") | not) | .value]
    + [.rules[] | .foreground // empty] + [.rules[] | .background // empty]
    | map(select(test("^(#[0-9a-fA-F]{6}|color[(].*[)])$") | not)) | join(" ")' "$file")
  [[ -z $bad ]] || fail "$theme: not colors: $bad"

  for key in background foreground caret selection line_highlight gutter accent; do
    jq -e --arg k "$key" '.globals | has($k)' "$file" >/dev/null ||
      fail "$theme: the scheme has no $key"
  done
done

# The palette reaches it: each theme paints its own background, and an
# override in home.nix wins.
declare -A backgrounds=([gruvbox]='#32302f' [autumn-leaves]='#291b17' [onedark]='#282c34')
for theme in "${!backgrounds[@]}"; do
  got=$(jq -r '.globals.background' "$(scheme "{ name = \"$theme\"; }")")
  [[ $got == "${backgrounds[$theme]}" ]] || fail "$theme background is $got"
done
got=$(jq -r '.globals.caret' "$(scheme '{ overrides.sublime-text = { accent = "#123456"; }; }')")
[[ $got == '#123456' ]] || fail "an override did not reach the scheme: caret is $got"

printf 'theme Sublime tests passed\n'
