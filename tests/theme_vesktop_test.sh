#!/usr/bin/env bash
# Vesktop's side of the theme: a Vencord stylesheet generated per palette at
# the fixed path Vencord watches, written as whole color families so every
# token Discord derives from them follows, and an override in home.nix that
# reaches it.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v jq >/dev/null || fail 'jq must be on PATH'
command -v python3 >/dev/null || fail 'python3 must be on PATH'

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

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

# Every family at every step, and the shape of a step's two declarations: the
# exact hex, and the hsl triple Discord derives its translucent washes from,
# which is the same color rounded to the whole degrees and percents that
# format is written in. A step missing either leaves part of the window stock.
# The washes are the exception — Discord writes those as one color at an
# alpha the step number names, so a wash has the triple alone, the same at
# every step, and a hex there would paint an opaque block.
families() {
  python3 - "$1" "$2" <<'PY'
import colorsys, re, sys

theme, css = sys.argv[1], open(sys.argv[2]).read()

numbered = [100, 130, 160, 200, 230, 260, 300, 330, 345, 360, 400, 430, 460,
            500, 530, 560, 600, 630, 645, 660, 700, 730, 760, 800, 830, 860, 900]
expected = dict(
    [(name, numbered) for name in
     ("primary", "brand", "blue", "red", "yellow", "green", "teal", "orange")]
    + [(name, list(range(1, 101))) for name in
       ("neutral", "blurple", "blue-new", "red-new", "yellow-new", "green-new",
        "teal-new", "orange-new", "pink")]
    + [(name, list(range(10, 71, 10))) for name in
       ("illo-blue", "illo-green", "illo-yellow", "illo-pink", "illo-purple",
        "illo-orange")])
washes = ("opacity", "opacity-blurple", "opacity-blue", "opacity-red",
          "opacity-yellow", "opacity-green", "opacity-teal", "opacity-orange",
          "opacity-pink")
wash_steps = list(range(4, 100, 4))

hexes, triples = {}, {}
for name, step, value in re.findall(
        r'^  --([a-z0-9-]+?)-(\d+): (#[0-9a-f]{6});$', css, re.M):
    hexes.setdefault(name, {})[int(step)] = value
for name, step, h, s, l in re.findall(
        r'^  --([a-z0-9-]+?)-(\d+)-hsl: (\d+) calc\(var\(--saturation-factor, 1\) '
        r'\* (\d+)%\) (\d+)%;$', css, re.M):
    triples.setdefault(name, {})[int(step)] = (float(h), float(s), float(l))

def fail(message):
    sys.exit(f"FAIL: {theme}: {message}")

for name, steps in expected.items():
    if sorted(hexes.get(name, {})) != steps:
        fail(f"--{name} is written at {sorted(hexes.get(name, {}))}, not every step")
    if sorted(triples.get(name, {})) != steps:
        fail(f"--{name} is missing an hsl triple")
    for step in steps:
        want = [int(hexes[name][step][at:at + 2], 16) for at in (1, 3, 5)]
        h, s, l = triples[name][step]
        got = [round(c * 255) for c in colorsys.hls_to_rgb(h / 360, l / 100, s / 100)]
        # The triple is the hex rounded, so a wash Discord mixes itself stays
        # the color the hex paints.
        if any(abs(a - b) > 3 for a, b in zip(want, got)):
            fail(f"--{name}-{step}-hsl is a different color from its hex")
    # A family is a walk from light to dark, which is what makes Discord's
    # own reading of a step number — text at the top, panels at the bottom —
    # hold.
    lightness = [triples[name][step][2] for step in steps]
    if lightness != sorted(lightness, reverse=True):
        fail(f"--{name} is not a walk from light to dark")

for name in washes:
    if name in hexes:
        fail(f"--{name} is written as a solid color, which would paint an opaque block")
    if sorted(triples.get(name, {})) != [1] + wash_steps:
        fail(f"--{name} is not written at every alpha Discord names")
    if len(set(triples[name].values())) != 1:
        fail(f"--{name} changes color between steps, which are alphas of one color")

unknown = set(hexes) - set(expected)
if unknown:
    fail(f"unknown families: {', '.join(sorted(unknown))}")
PY
}

for theme in gruvbox autumn-leaves onedark; do
  stylesheet "$theme" >"$work/$theme.css"
  css=$(cat "$work/$theme.css")

  # Vencord names a theme from the first /** block; without it the file is
  # listed by its file name and the README's step names something else.
  [[ $(sed -n 's/^ \* @name //p' <<<"$css" | head -1) == Dotfiles ]] ||
    fail "$theme: the stylesheet does not name itself Dotfiles"

  # Discord declares its families on :root, and its own `.visual-refresh`
  # class re-derives the older family numbering from the newer one. A class
  # outranks a bare :root, so the block doubles the pseudo-class to sit above
  # both it and `.theme-dark`.
  grep -q '^:root:root {' <<<"$css" ||
    fail "$theme: the stylesheet does not outrank Discord's own class rules"

  families "$theme" "$work/$theme.css"
done

# The families carry the roles where Discord reads them, on both numberings:
# the window, the message text, and the accent on the button it paints.
css=$(cat "$work/gruvbox.css")
step() { sed -n "s/^  --$1: //p" <<<"$css"; }

[[ $(step neutral-69) == '#282828;' ]] || fail "gruvbox's window is not the palette's base"
[[ $(step neutral-73) == '#1d2021;' ]] || fail "gruvbox's server bar is not the palette's mantle"
[[ $(step neutral-64) == '#3c3836;' ]] || fail "gruvbox's raised surface is not the palette's surface"
[[ $(step neutral-4) == '#ebdbb2;' ]] || fail "gruvbox's message text is not the palette's text"
[[ $(step neutral-16) == '#d5c4a1;' ]] || fail "gruvbox's subtler text is not the palette's subtext"
[[ $(step neutral-23) == '#a89984;' ]] || fail "gruvbox's muted text is not the palette's muted"
[[ $(step blurple-50) == '#fe8019;' ]] || fail "gruvbox's button is not the palette's accent"
[[ $(step red-new-38) == '#fb4934;' ]] || fail "gruvbox's danger text is not the palette's error"
[[ $(step teal-new-38) == '#83a598;' ]] || fail "gruvbox's teal is not the palette's info"
[[ $(step illo-blue-30) == '#83a598;' ]] || fail "gruvbox's bright ANSI blue is not the palette's"

[[ $(step primary-600) == '#282828;' ]] || fail "gruvbox's old window step is not the palette's base"
[[ $(step primary-660) == '#1d2021;' ]] || fail "gruvbox's old darkest panel is not the palette's mantle"
[[ $(step primary-230) == '#ebdbb2;' ]] || fail "gruvbox's old message text is not the palette's text"
[[ $(step brand-500) == '#fe8019;' ]] || fail "gruvbox's old button is not the palette's accent"
[[ $(step red-360) == '#fb4934;' ]] || fail "gruvbox's old danger text is not the palette's error"

# A wash is the palette's color at Discord's alpha, not Discord's own.
[[ $(step opacity-blurple-8-hsl) == "$(step blurple-50-hsl)" ]] ||
  fail "gruvbox's accent wash is not the palette's accent"

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
[[ $(sed -n 's/^  --neutral-69: //p' <<<"$css") == '#1d2021;' ]] ||
  fail 'a role override does not reach Vesktop'
css=$(stylesheet gruvbox '{ dotfiles.theme.overrides.vesktop.variables."--text-link" = "#123456"; }')
[[ $(sed -n 's/^  --text-link: //p' <<<"$css") == '#123456;' ]] ||
  fail 'a variable override does not reach Vesktop'

printf 'theme Vesktop tests passed\n'
