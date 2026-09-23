#!/usr/bin/env bash
# Sublime Text and Terminus: generated colors under stable names, valid for
# each application to load, with overrides that reach both.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v jq >/dev/null || fail 'jq must be on PATH'

scheme_path="$HOME/.config/sublime-text/Packages/User/Dotfiles.sublime-color-scheme"
terminus_path="$HOME/.config/sublime-text/Packages/User/Terminus.sublime-settings"

scheme() {
  nix build --impure --no-link --print-out-paths --expr "((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
    modules = [ ({ lib, ... }: { dotfiles.theme = lib.mapAttrs (_: lib.mkForce) ($1); }) ];
  }).config.dotfiles.theme.liveFiles.\"$scheme_path\"" 2>/dev/null || fail "scheme for $1"
}

terminus() {
  nix build --impure --no-link --print-out-paths --expr "((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
    modules = [ ({ lib, ... }: { dotfiles.theme = lib.mapAttrs (_: lib.mkForce) ($1); }) ];
  }).config.dotfiles.theme.liveFiles.\"$terminus_path\"" 2>/dev/null || fail "Terminus settings for $1"
}

# Preferences name the generated scheme, permanently. Sublime's settings are
# JSON with comments and trailing commas, so this is a line match rather than
# a parse.
grep -qF '"color_scheme": "Dotfiles.sublime-color-scheme"' \
  "$REPO_ROOT/configs/sublime-text/Preferences.sublime-settings" ||
  fail 'Preferences do not select the generated scheme'
[[ ! -e "$REPO_ROOT/configs/sublime-text/Gruvbox Rewaita.sublime-color-scheme" ]] ||
  fail 'the hand-made scheme is still in the repository'
[[ ! -e "$REPO_ROOT/configs/sublime-text/Terminus.sublime-settings" ]] ||
  fail 'the hand-made Terminus settings are still in the repository'

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

# Terminus has its own color names. The generated file supplies the normal
# and bright ANSI sets separately, rather than repeating the bright set.
for theme in gruvbox autumn-leaves onedark; do
  file=$(terminus "{ name = \"$theme\"; }")
  jq -e '.theme == "user" and (.user_theme_colors | length == 22)' "$file" >/dev/null ||
    fail "$theme: Terminus does not have its six UI colors and sixteen ANSI colors"
  jq -e '[.user_theme_colors[] | select(test("^#[0-9a-fA-F]{6}$"))] | length == 22' "$file" >/dev/null ||
    fail "$theme: Terminus has a malformed color"
done
file=$(terminus '{ name = "gruvbox"; }')
jq -e '.user_theme_colors | .background == "#32302f" and .foreground == "#fffaeb"
  and .red == "#cc241d" and .light_red == "#fb4934"
  and .brown == "#d79921" and .light_brown == "#fabd2f"' "$file" >/dev/null ||
  fail 'Gruvbox Terminus did not preserve its soft base and bright text with true ANSI pairs'
file=$(terminus '{ overrides.terminus = { base = "#123456"; brightRed = "#abcdef"; }; }')
jq -e '.user_theme_colors.background == "#123456" and .user_theme_colors.light_red == "#abcdef"' "$file" >/dev/null ||
  fail 'a Terminus override did not reach its settings'

# The palette reaches it: each theme paints its own background, and an
# override in home.nix wins.
declare -A backgrounds=([gruvbox]='#32302f' [autumn-leaves]='#261814' [onedark]='#282c34')
for theme in "${!backgrounds[@]}"; do
  got=$(jq -r '.globals.background' "$(scheme "{ name = \"$theme\"; }")")
  [[ $got == "${backgrounds[$theme]}" ]] || fail "$theme background is $got"
done
got=$(jq -r '.globals.caret' "$(scheme '{ overrides.sublime-text = { accent = "#123456"; }; }')")
[[ $got == '#123456' ]] || fail "an override did not reach the scheme: caret is $got"

printf 'theme Sublime tests passed\n'
