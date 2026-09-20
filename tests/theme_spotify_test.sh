#!/usr/bin/env bash
# Spotify's side of the theme: the Spicetify color scheme comes from the
# palette, autumn-glass still renders the hand-made scheme it was taken from,
# and an override in home.nix reaches the client.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v jq >/dev/null || fail 'jq must be on PATH'

# The scheme Spicetify is handed for a theme, optionally with extra modules.
scheme() {
  nix eval --impure --json --expr "
    ((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
      modules = [ ({ lib, ... }: { dotfiles.theme.name = lib.mkForce \"$1\"; }) ${2-} ];
    }).config.programs.spicetify.customColorScheme" 2>/dev/null ||
    fail "scheme for $1"
}

# Spicetify writes these names into Spotify's CSS; every one has to be set, or
# the client falls back to a stock color for it.
slots=(
  text subtext main main-elevated sidebar player card shadow selected-row
  button button-active button-disabled tab-active notification
  notification-error misc highlight highlight-elevated
)

# The scheme this replaced, as it stood in modules/programs/spotify.nix.
read -r -d '' autumn_glass <<'JSON' || true
{
  "text": "f6e9da", "subtext": "bda18e",
  "main": "261814", "main-elevated": "34231e",
  "sidebar": "1d1210", "player": "1d1210",
  "card": "3a251f", "shadow": "0f0907",
  "selected-row": "f6e9da",
  "button": "e9a15e", "button-active": "c86138", "button-disabled": "957c6e",
  "tab-active": "c86138",
  "notification": "3a251f", "notification-error": "e96b58",
  "misc": "725046", "highlight": "4a3028", "highlight-elevated": "5a392f"
}
JSON

for theme in gruvbox autumn-glass onedark; do
  got=$(scheme "$theme")
  for slot in "${slots[@]}"; do
    value=$(jq -r --arg s "$slot" '.[$s] // ""' <<<"$got")
    [[ $value =~ ^[0-9a-f]{6}$ ]] ||
      fail "$theme: slot $slot is \"$value\", not six bare hex digits"
  done
  [[ $(jq -r 'keys | length' <<<"$got") -eq ${#slots[@]} ]] ||
    fail "$theme: the scheme has slots Spicetify does not know: $(jq -c 'keys' <<<"$got")"
done

# Autumn-glass is the theme this palette was taken from, so it has to render
# what Spotify showed before there was a palette, to the digit.
diff <(jq -S . <<<"$autumn_glass") <(scheme autumn-glass | jq -S .) ||
  fail 'autumn-glass no longer renders the scheme it was taken from'

# Each theme is its own scheme, and the window follows the palette's base.
[[ $(scheme gruvbox | jq -r '.main') == 282828 ]] ||
  fail "gruvbox's main is not the palette's base"
[[ $(scheme onedark | jq -r '.main') == 282c34 ]] ||
  fail "onedark's main is not the palette's base"

# An override in home.nix reaches the client, both as a role and through
# Spicetify's own slot names.
[[ $(scheme gruvbox '{ dotfiles.theme.overrides.spotify = r: { base = r.mantle; }; }' | jq -r '.main') == 1d2021 ]] ||
  fail 'a role override does not reach Spotify'
[[ $(scheme gruvbox '{ dotfiles.theme.overrides.spotify.scheme.card = "#123456"; }' | jq -r '.card') == 123456 ]] ||
  fail 'a slot override does not reach Spotify'

printf 'theme Spotify tests passed\n'
