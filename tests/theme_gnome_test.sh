#!/usr/bin/env bash
# GNOME's side of the theme: the generated Rewaita palettes, the preferences
# merge that keeps the operator's Fine Tune edits, and what activation does
# with no GNOME session to talk to. New files must be tracked (git add -N is
# enough) for the flake to see them.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v jq >/dev/null || fail 'jq must be on PATH'

home() {
  printf '((builtins.getFlake "%s").homeConfigurations.z.extendModules { modules = [ (%s) ]; })' \
    "$REPO_ROOT" "$1"
}
themed() {
  printf '{ lib, ... }: { dotfiles.theme = lib.mapAttrs (_: lib.mkForce) (%s); }' "$1"
}

# A generation built against a scratch home, so its activation steps can run
# here without touching the real one.
build() {
  nix build --impure --no-link --print-out-paths --expr "$(home "{ lib, ... }: {
    imports = [ ($(themed "$1")) ];
    home.homeDirectory = lib.mkForce \"$TEST_ROOT/home\";
  }").activationPackage" 2>/dev/null || fail "activation package for $1"
}

# Run the named activation steps against the scratch home. HOME is what the
# steps themselves read, so it has to point there too, not at the real one.
run_steps() {
  local package=$1; shift
  (
    export HOME="$TEST_ROOT/home"
    run() { "$@"; }
    eval "$(steps "$package" "$@")"
  )
}

# The named activation steps, in order, with Home Manager's bookkeeping left
# out; `run` is what the real script uses to honour a dry run.
steps() {
  local package=$1; shift
  local names="|$*|"
  awk -v names="${names// /|}" '
    /^_iNote "Activating %s" "/ {
      match($0, /"[^"]*"\)?$/)
      name = substr($0, RSTART + 1, RLENGTH - 2)
      on = index(names, "|" name "|") > 0
      next
    }
    /^# Create the "current generation"/ { on = 0 }
    on
  ' "$package/activate"
}

# Rewaita's own Gruvbox Medium, the palette the desktop used before this
# repository generated one.
rewaita_src=$(nix build --impure --no-link --print-out-paths \
  --expr "((import (builtins.getFlake \"$REPO_ROOT\").inputs.nixpkgs { system = builtins.currentSystem; }).callPackage $REPO_ROOT/packages/rewaita.nix { }).src" \
  2>/dev/null) || fail 'could not fetch the Rewaita source'
stock=$(find "$rewaita_src" -path '*themes/dark*' -name 'Gruvbox Medium*.css' | head -1)
[[ -n $stock ]] || fail "Rewaita's own Gruvbox palette not found in $rewaita_src"

package=$(build '{ name = "gruvbox"; transparency = true; }')
generated="$TEST_ROOT/home/.local/share/rewaita/dark/Dotfiles gruvbox.css"
[[ -f "$package/home-files/.local/share/rewaita/dark/Dotfiles gruvbox.css" ]] ||
  fail 'no generated palette for gruvbox'
mkdir -p "$(dirname "$generated")"
cp "$package/home-files/.local/share/rewaita/dark/Dotfiles gruvbox.css" "$generated"

# Every theme has a palette, named so that Rewaita's CLI finds it: it strips
# the extension, replaces spaces with dashes and lowercases.
for theme in gruvbox autumn-glass onedark; do
  [[ -f "$(build "{ name = \"$theme\"; }")/home-files/.local/share/rewaita/dark/Dotfiles $theme.css" ]] ||
    fail "no generated palette for $theme"
done
grep -q -- "--theme=dotfiles-gruvbox" \
  "$package/home-files/.config/autostart/rewaita-theme.desktop" ||
  fail 'the login autostart does not select the generated palette'

# The colors Rewaita actually reads off a palette: surfaces, and the first
# shade of each family, which is where its accent map looks.
# Rewaita's own palettes point some variables at others with var(); its
# parser follows those, so the comparison does too.
value() {
  local raw; raw=$(grep -oP "(?<=--$2: )[^;]+" "$1" | head -1)
  while [[ $raw == var\(--* ]]; do
    raw=$(grep -oP "(?<=--${raw:6:-1}: )[^;]+" "$1" | head -1)
  done
  printf '%s' "$raw"
}
for key in window-bg-color window-fg-color view-bg-color view-fg-color \
  headerbar-bg-color headerbar-backdrop-color headerbar-fg-color \
  popover-bg-color popover-fg-color sidebar-bg-color sidebar-fg-color \
  sidebar-border-color active-toggle-bg-color active-toggle-fg-color \
  blue-1 blue-2 green-1 yellow-1 orange-1 red-1 purple-1 purple-2 dark-1; do
  want=$(value "$stock" "$key")
  got=$(value "$generated" "$key")
  [[ ${want,,} == "${got,,}" ]] || fail "gruvbox $key: Rewaita has $want, generated $got"
done

# Fine Tune edits survive; the keys this repository owns are the ones merged.
prefs="$TEST_ROOT/home/.local/share/rewaita/prefs.json"
mkdir -p "$(dirname "$prefs")"
cat >"$prefs" <<'EOF'
{ "dark-theme": "Nord 🏔️.css", "transparency": false, "sharp": true, "no-pills": true, "accent": "'red'" }
EOF
run_steps "$(build '{ name = "onedark"; }')" seedRewaitaPreferences
jq -e '."dark-theme" == "Dotfiles onedark.css" and .transparency == true and
       .accent == "'"'"'blue'"'"'" and .sharp == true and ."no-pills" == true' "$prefs" >/dev/null ||
  fail "preferences merge: $(cat "$prefs")"

# Transparency reaches GTK, Firefox and Blur my Shell.
package=$(build '{ name = "gruvbox"; transparency = false; }')
run_steps "$package" seedRewaitaPreferences
jq -e '.transparency == false and .sharp == true' "$prefs" >/dev/null ||
  fail "transparency off did not reach Rewaita: $(cat "$prefs")"
opaque=$(nix eval --impure --json --expr "$(home "$(themed '{ transparency = false; }')").config.dconf.settings.\"org/gnome/shell/extensions/blur-my-shell/applications\".blur" 2>/dev/null)
[[ $opaque == false ]] || fail "blur does not follow transparency: $opaque"
# user.js is linked into Firefox's machine-local profile by activation, so
# the generated file is named in the script rather than in the generation.
user_js=$(grep -oP '/nix/store/\S+-user\.js' "$package/activate" | head -1)
grep -q 'allow_transparent_browser", false' "$user_js" ||
  fail 'Firefox page transparency does not follow the switch'

# With no GNOME session to talk to, GNOME waits for the next login and the
# notice says so instead of claiming it recolored live.
rm -f "$TEST_ROOT/home/.local/state/dotfiles/theme"
notice=$(
  unset XDG_CURRENT_DESKTOP WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS
  run_steps "$(build '{ name = "autumn-glass"; }')" \
    dotfilesThemeInit seedRewaitaPreferences applyRewaitaTheme dotfilesThemeHint
)
grep -q 'Log out and back in: GNOME Shell, GTK and Firefox' <<<"$notice" ||
  fail "GNOME is not on the re-login line over SSH: $notice"
grep -q 'Updated live: WezTerm' <<<"$notice" || fail "WezTerm left the live line: $notice"

printf 'theme GNOME tests passed\n'
