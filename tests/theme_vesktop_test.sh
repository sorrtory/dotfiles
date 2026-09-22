#!/usr/bin/env bash
# Vesktop's side of the theme: a Vencord stylesheet generated per palette at
# the fixed path Vencord watches, written as whole color families so every
# token Discord derives from them follows, and an override in home.nix that
# reaches it.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v jq >/dev/null || fail 'jq must be on PATH'

# The configuration for a theme, optionally with extra modules.
config() {
  nix eval --impure --json --expr "
    let cfg = ((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
          modules = [ ({ lib, ... }: { dotfiles.theme.name = lib.mkForce \"$1\"; }) ${3-} ];
        }).config;
    in $2" 2>/dev/null || fail "$2 for $1"
}

# The stylesheet Vencord reads, by the path it watches.
stylesheet() {
  local built
  built=$(nix build --impure --no-link --print-out-paths --expr "
    let cfg = ((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
          modules = [ ({ lib, ... }: { dotfiles.theme.name = lib.mkForce \"$1\"; }) ${2-} ];
        }).config;
    in cfg.dotfiles.theme.liveFiles.\"\${cfg.xdg.configHome}/vesktop/themes/Dotfiles.css\"" 2>/dev/null) ||
    fail "Vesktop stylesheet for $1"
  cat "$built"
}

# The path is Vencord's themes directory, and the theme is a live one: the
# directory watcher reaches a running client.
[[ $(config gruvbox 'builtins.attrNames cfg.dotfiles.theme.liveFiles' | jq -r '.[]' |
  grep -c '/vesktop/themes/Dotfiles\.css$') -eq 1 ]] ||
  fail 'no stylesheet at the path Vencord watches'
[[ $(config gruvbox 'cfg.dotfiles.theme.apps.vesktop.apply' | jq -r .) == live ]] ||
  fail 'Vesktop does not take a switch live'

# Discord reads every family at every step, and derives its translucent
# washes from the -hsl twin rather than the hex, so a step without one leaves
# part of the window stock.
steps=(100 130 160 200 230 260 300 330 345 360 400 430 460 500 530 560 600
       630 645 660 700 730 760 800 830 860 900)
families=(primary brand blue red yellow green)

for theme in gruvbox autumn-leaves onedark; do
  css=$(stylesheet "$theme")

  # Vencord names a theme from the first /** block; without it the file is
  # listed by its file name and the README's step names something else.
  [[ $(sed -n 's/^ \* @name //p' <<<"$css" | head -1) == Dotfiles ]] ||
    fail "$theme: the stylesheet does not name itself Dotfiles"

  # Discord declares its families on :root; .theme-dark only maps tokens onto
  # them, and would win over anything scoped lower.
  grep -q '^:root {' <<<"$css" || fail "$theme: the stylesheet does not scope to :root"

  for family in "${families[@]}"; do
    for step in "${steps[@]}"; do
      hex=$(sed -n "s/^  --$family-$step: \(.*\);$/\1/p" <<<"$css")
      [[ $hex =~ ^#[0-9a-f]{6}$ ]] ||
        fail "$theme: --$family-$step is \"$hex\", not a hex color"
      triple=$(sed -n "s/^  --$family-$step-hsl: \(.*\);$/\1/p" <<<"$css")
      [[ $triple =~ ^[0-9]+\ calc\(var\(--saturation-factor,\ 1\)\ \*\ [0-9]+%\)\ [0-9]+%$ ]] ||
        fail "$theme: --$family-$step-hsl is \"$triple\", not an hsl triple"

      # The triple is the hex rounded to whole degrees and percents, so a
      # wash Discord mixes itself stays the color the hex paints.
      read -r h s l < <(tr -d '%' <<<"$triple" | sed 's/calc(var(--saturation-factor, 1) \* \([0-9]*\))/\1/')
      python3 - "$hex" "$h" "$s" "$l" <<'PY' || fail "$theme: --$family-$step-hsl is a different color from its hex"
import colorsys, sys
hex_value, h, s, l = sys.argv[1], *map(float, sys.argv[2:])
want = [int(hex_value[i:i + 2], 16) for i in (1, 3, 5)]
got = [round(c * 255) for c in colorsys.hls_to_rgb(h / 360, l / 100, s / 100)]
sys.exit(0 if all(abs(a - b) <= 3 for a, b in zip(want, got)) else 1)
PY
    done
  done

  # A family is a walk from light to dark, which is what makes Discord's own
  # reading of a step number — text at the top, panels at the bottom — hold.
  for family in "${families[@]}"; do
    previous=256
    for step in "${steps[@]}"; do
      l=$(sed -n "s/^  --$family-$step-hsl: .* \([0-9]*\)%$/\1/p" <<<"$css")
      (( l <= previous )) ||
        fail "$theme: --$family-$step is lighter than the step above it"
      previous=$l
    done
  done
done

# The neutral family carries the roles where Discord reads them: the window,
# the message text, and the accent on the button it paints.
css=$(stylesheet gruvbox)
[[ $(sed -n 's/^  --primary-600: //p' <<<"$css") == '#282828;' ]] ||
  fail "gruvbox's window is not the palette's base"
[[ $(sed -n 's/^  --primary-660: //p' <<<"$css") == '#1d2021;' ]] ||
  fail "gruvbox's darkest panel is not the palette's mantle"
[[ $(sed -n 's/^  --primary-230: //p' <<<"$css") == '#ebdbb2;' ]] ||
  fail "gruvbox's message text is not the palette's text"
[[ $(sed -n 's/^  --brand-500: //p' <<<"$css") == '#fe8019;' ]] ||
  fail "gruvbox's button is not the palette's accent"
[[ $(sed -n 's/^  --red-360: //p' <<<"$css") == '#fb4934;' ]] ||
  fail "gruvbox's danger text is not the palette's error"

# Solid colors only: the switch reaches Vesktop through Blur my Shell, so the
# stylesheet is the same either way and the window is on that list.
on=$(stylesheet gruvbox '({ lib, ... }: { dotfiles.theme.transparency = lib.mkForce true; })')
off=$(stylesheet gruvbox '({ lib, ... }: { dotfiles.theme.transparency = lib.mkForce false; })')
[[ $on == "$off" ]] ||
  fail 'the stylesheet changes with transparency, which Vesktop cannot draw'
config gruvbox 'cfg.dconf.settings."org/gnome/shell/extensions/blur-my-shell/applications".whitelist' |
  jq -e 'index("vesktop") and index("Vesktop")' >/dev/null ||
  fail 'Vesktop is not faded from the compositor'

# An override in home.nix reaches the stylesheet, both as a role and through
# the palette's escape hatch for a token no family reaches.
css=$(stylesheet gruvbox '{ dotfiles.theme.overrides.vesktop = r: { base = r.mantle; }; }')
[[ $(sed -n 's/^  --primary-600: //p' <<<"$css") == '#1d2021;' ]] ||
  fail 'a role override does not reach Vesktop'
css=$(stylesheet gruvbox '{ dotfiles.theme.overrides.vesktop.variables."--text-link" = "#123456"; }')
[[ $(sed -n 's/^  --text-link: //p' <<<"$css") == '#123456;' ]] ||
  fail 'a variable override does not reach Vesktop'

printf 'theme Vesktop tests passed\n'
