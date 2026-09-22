#!/usr/bin/env bash
# The theme core: palettes resolve with overrides, a broken palette fails
# evaluation by name, WezTerm renders the resolved colors, and activation
# prints its notice only when the theme changes. New files must be tracked
# (git add -N is enough) for the flake to see them.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v wezterm >/dev/null || fail 'wezterm must be on PATH'
command -v jq >/dev/null || fail 'jq must be on PATH'

# The home configuration with one more module, given as a Nix expression.
home() {
  printf '((builtins.getFlake "%s").homeConfigurations.z.extendModules { modules = [ (%s) ]; })' \
    "$REPO_ROOT" "$1"
}
# home.nix sets the theme, so a test's choice has to win over it.
themed() {
  printf '{ lib, ... }: { dotfiles.theme = lib.mapAttrs (_: lib.mkForce) (%s); }' "$1"
}
nix_eval() { nix eval --impure --json --expr "$1" 2>"$TEST_ROOT/eval.err"; }
theme_for() {
  nix_eval "$(home "$(themed "$1")").config.dotfiles.theme.forApp \"wezterm\""
}

# Every theme builds, both ways.
installables=()
for theme in gruvbox autumn-leaves onedark; do
  for transparency in true false; do
    installables+=("$(home "$(themed "{ name = \"$theme\"; transparency = $transparency; }")").activationPackage")
  done
done
for expr in "${installables[@]}"; do
  nix build --impure --no-link --expr "$expr" 2>/dev/null || fail "activation package does not build: $expr"
done

# A missing role is an evaluation error naming the theme and the role.
nix_eval "$(home '{ lib, ... }: { dotfiles.theme.name = lib.mkForce "broken"; dotfiles.theme.palettes.broken = let p = import '"$REPO_ROOT"'/modules/theme/palettes/gruvbox.nix; in p // { roles = removeAttrs p.roles [ "accent" ]; }; }').config.dotfiles.theme.forApp \"wezterm\"" >/dev/null && fail 'a palette without accent evaluated'
grep -q 'palette "broken" is missing required role "accent"' "$TEST_ROOT/eval.err" ||
  fail "unhelpful error for a missing role: $(cat "$TEST_ROOT/eval.err")"

# Operator overrides: a remap follows the theme, a hex pins one value, and
# the theme's own values are kept elsewhere.
for theme in gruvbox autumn-leaves onedark; do
  colors=$(theme_for "{ name = \"$theme\"; overrides.wezterm = r: { base = r.mantle; }; }")
  jq -e '.base == .mantle' <<<"$colors" >/dev/null || fail "$theme: remap did not follow the theme"
done
colors=$(theme_for '{ name = "onedark"; overrides.wezterm = { accent = "#123456"; alpha.window = 0.5; }; }')
jq -e '.accent == "#123456" and .alpha.window == 0.5 and .alpha.popup == 0.9 and .text == "#abb2bf"' \
  <<<"$colors" >/dev/null || fail "hex override: $colors"
colors=$(theme_for '{ transparency = false; overrides.wezterm = { alpha.window = 0.5; }; }')
jq -e '.alpha == { window: 1, surface: 1, popup: 1 }' <<<"$colors" >/dev/null ||
  fail "transparency off is not opaque: $colors"

# WezTerm, loaded through its real config with the generated theme file.
wezterm_scheme() {
  mkdir -p "$TEST_ROOT/data/dotfiles/theme"
  printf 'return require("wezterm").json_parse([[%s]])\n' "$1" >"$TEST_ROOT/data/dotfiles/theme/wezterm.lua"
  cat >"$TEST_ROOT/probe.lua" <<EOF
local wezterm = require("wezterm")
local config = dofile("$REPO_ROOT/configs/wezterm/wezterm.lua")
wezterm.log_error("PROBE " .. wezterm.json_encode({
  scheme = config.color_schemes and config.color_schemes.Dotfiles,
  name = config.color_scheme,
  opacity = config.window_background_opacity,
  titlebar = config.window_frame and config.window_frame.active_titlebar_bg,
}))
return config
EOF
  XDG_DATA_HOME="$TEST_ROOT/data" timeout 30 wezterm --config-file "$TEST_ROOT/probe.lua" show-keys 2>&1 |
    grep -o 'PROBE .*' | cut -d' ' -f2-
}

# Gruvbox is Rewaita's Gruvbox Medium unchanged: WezTerm's bundled
# GruvboxDark, with the headerbar tab bar it always had.
out=$(wezterm_scheme "$(theme_for '{ name = "gruvbox"; }')")
jq -e '
  .name == "Dotfiles" and .opacity == 0.9 and .titlebar == "#1d2021" and
  .scheme.background == "#282828" and .scheme.foreground == "#ebdbb2" and
  .scheme.selection_bg == "#665c54" and
  .scheme.ansi == ["#282828","#cc241d","#98971a","#d79921","#458588","#b16286","#689d6a","#a89984"] and
  .scheme.brights == ["#928374","#fb4934","#b8bb26","#fabd2f","#83a598","#d3869b","#8ec07c","#ebdbb2"] and
  .scheme.tab_bar.background == "#1d2021" and
  .scheme.tab_bar.inactive_tab_hover.bg_color == "#3c3836" and
  .scheme.tab_bar.new_tab_hover.fg_color == "#fe8019"
' <<<"$out" >/dev/null || fail "gruvbox WezTerm: $out"

# Autumn Leaves carries the wallpaper's browns and coppers, with no dim
# neutrals in the terminal's normal slots.
out=$(wezterm_scheme "$(theme_for '{ name = "autumn-leaves"; transparency = false; }')")
jq -e '
  .opacity == 1 and .scheme.background == "#261814" and .scheme.foreground == "#fbeada" and
  .scheme.ansi == ["#38271f","#e8604c","#c2ad4b","#e9a15e","#8fa9b8","#d3869b","#97c973","#eedcc4"]
' <<<"$out" >/dev/null || fail "autumn-leaves WezTerm: $out"

# No theme file: the bundled scheme, not an error.
rm -f "$TEST_ROOT/data/dotfiles/theme/wezterm.lua"
out=$(XDG_DATA_HOME="$TEST_ROOT/data" timeout 30 wezterm --config-file "$TEST_ROOT/probe.lua" show-keys 2>&1 |
  grep -o 'PROBE .*' | cut -d' ' -f2-)
jq -e '.name == "GruvboxDark"' <<<"$out" >/dev/null || fail "no fallback without a theme file: $out"

# The theme's activation steps, run on their own against a scratch home.
activate() {
  local package script
  package=$(nix build --impure --no-link --print-out-paths --expr "$(home "{ lib, ... }: {
    imports = [ ($(themed "$1")) ];
    home.homeDirectory = lib.mkForce \"$TEST_ROOT/home\";
  }").activationPackage" 2>/dev/null) || fail "activation package for $1"
  script=$(awk '/^_iNote "Activating %s" "dotfilesTheme/ { on = 1; next } /^_iNote |^# Create the "current generation"/ { on = 0 } on' \
    "$package/activate")
  (export HOME="$TEST_ROOT/home"; run() { "$@"; }; eval "$script")
}
out=$(activate '{ name = "autumn-leaves"; }')
grep -qx 'Theme is now autumn-leaves, transparency on.' <<<"$out" || fail "no notice on first switch: $out"
grep -q 'Updated live: .*WezTerm' <<<"$out" || fail "WezTerm not listed as live: $out"
grep -q '"#261814"' "$TEST_ROOT/home/.local/share/dotfiles/theme/wezterm.lua" || fail 'theme file not written'
[[ ! -L $TEST_ROOT/home/.local/share/dotfiles/theme/wezterm.lua ]] || fail 'theme file is a symlink'
inode=$(stat -c %i "$TEST_ROOT/home/.local/share/dotfiles/theme/wezterm.lua")

out=$(activate '{ name = "autumn-leaves"; }')
[[ -z $out ]] || fail "notice printed for an unchanged theme: $out"

out=$(activate '{ name = "autumn-leaves"; transparency = false; }')
grep -qx 'Theme is now autumn-leaves, transparency off.' <<<"$out" || fail "no notice for transparency: $out"
[[ $(stat -c %i "$TEST_ROOT/home/.local/share/dotfiles/theme/wezterm.lua") == "$inode" ]] ||
  fail 'theme file replaced rather than rewritten in place'
grep -q '"window"\] = 1' "$TEST_ROOT/home/.local/share/dotfiles/theme/wezterm.lua" || fail 'opacity not rewritten'

printf 'theme tests passed\n'
