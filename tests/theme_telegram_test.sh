#!/usr/bin/env bash
# Telegram's side of the theme: activation packs a .tdesktop-theme at one
# fixed path, carrying every color the hand-made Autumn Glass theme set, the
# theme's wallpaper as one picture rather than a tile, and nothing at all when
# the theme did not change. New files must be tracked (git add -N is enough)
# for the flake to see them.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v unzip >/dev/null || fail 'unzip must be on PATH'
command -v jq >/dev/null || fail 'jq must be on PATH'

# The commit the hand-made theme and the palette it was painted with are read
# from, since both are due to leave the tree.
BEFORE=1174260

HOME_DIR=$TEST_ROOT/home
THEME_FILE=$HOME_DIR/.local/share/dotfiles/theme/telegram/Dotfiles.tdesktop-theme
WALLPAPERS=$HOME_DIR/Pictures/wallpapers

home() {
  printf '((builtins.getFlake "%s").homeConfigurations.z.extendModules { modules = [ ({ lib, ... }: { dotfiles.theme = lib.mapAttrs (_: lib.mkForce) (%s); home.homeDirectory = lib.mkForce "%s"; }) ]; })' \
    "$REPO_ROOT" "$1" "$HOME_DIR"
}

# The theme's activation steps, run on their own against a scratch home.
activate() {
  local package script
  package=$(nix build --impure --no-link --print-out-paths --expr "$(home "$1").activationPackage" 2>/dev/null) ||
    fail "activation package for $1"
  script=$(awk '/^_iNote "Activating %s" "dotfilesTheme/ { on = 1; next } /^_iNote |^# Create the "current generation"/ { on = 0 } on' \
    "$package/activate")
  (export HOME="$HOME_DIR"; run() { "$@"; }; eval "$script")
}

# What is inside the packed theme.
unpack() {
  rm -rf "$TEST_ROOT/unpacked"
  mkdir "$TEST_ROOT/unpacked"
  unzip -q "$THEME_FILE" -d "$TEST_ROOT/unpacked" || fail 'the packed theme is not a zip'
}

[[ $(nix eval --impure --json --expr "$(home '{ }').config.dotfiles.theme.apps.telegram.apply" 2>/dev/null | jq -r .) == restart ]] ||
  fail 'Telegram is not listed as restart to apply'
nix eval --impure --json --expr "$(home '{ }').config.dotfiles.theme.apps.telegram.setup" 2>/dev/null |
  grep -q 'Choose from file' || fail 'the notice does not carry the one-time Choose from file step'

git -C "$REPO_ROOT" show "$BEFORE:configs/ayugram/autumn-glass/colors.tdesktop-theme" > "$TEST_ROOT/hand-made" ||
  fail 'cannot read the hand-made theme from git'

# Without a wallpaper, one solid picture — never a tile, which Telegram would
# repeat as a pattern across the chat.
activate '{ name = "autumn-leaves"; }' >/dev/null
[[ -f $THEME_FILE ]] || fail 'activation did not pack a theme'
unpack
[[ -f $TEST_ROOT/unpacked/background.png ]] || fail 'no still background for a theme without a wallpaper'
[[ -z $(find "$TEST_ROOT/unpacked" -name 'tiled.*') ]] || fail 'the chat background is tiled'

# The wallpaper the desktop shows is the chat background too, by the name of
# the theme, from the home directory rather than the repository.
mkdir -p "$WALLPAPERS"
# A wallpaper is easily larger on its own than Telegram's 5 MB theme limit,
# so this one is too.
python3 - "$WALLPAPERS/autumn-leaves.jpg" <<'PICTURE'
import random, sys
from PIL import Image
random.seed(0)
image = Image.new("RGB", (4000, 3000))
image.putdata([(random.randrange(256), random.randrange(256), random.randrange(256))
               for _ in range(4000 * 3000)])
image.save(sys.argv[1], quality=95)
PICTURE
(( $(stat -c %s "$WALLPAPERS/autumn-leaves.jpg") > 5 * 1024 * 1024 )) ||
  fail 'the test wallpaper is not large enough to be worth shrinking'

activate '{ name = "autumn-leaves"; transparency = false; }' >/dev/null
unpack
[[ -f $TEST_ROOT/unpacked/background.jpg ]] || fail "the theme's wallpaper is not the chat background"
(( $(stat -c %s "$THEME_FILE") < 5 * 1024 * 1024 )) ||
  fail "a large wallpaper is packed whole, over Telegram's 5 MB limit"

# The chat list covers the left of the window, so the background is the right
# of the wallpaper: narrower than the picture, the same height, and blurred.
python3 - "$WALLPAPERS/autumn-leaves.jpg" "$TEST_ROOT/unpacked/background.jpg" <<'PICTURE' || fail 'the chat background is not a blurred crop of the wallpaper'
import sys
from PIL import Image, ImageFilter, ImageStat
source, packed = (Image.open(path) for path in sys.argv[1:3])
cropped = packed.size[0] / packed.size[1] / (source.size[0] / source.size[1])
# Sharp edges survive a resize; a blur is what takes them out.
edges = ImageStat.Stat(packed.convert("L").filter(ImageFilter.FIND_EDGES)).stddev[0]
print(f"crop {cropped:.2f} of the wallpaper's shape, edges {edges:.1f}", file=sys.stderr)
sys.exit(0 if 0.5 < cropped < 0.8 and edges < 12 else 1)
PICTURE

# An unreadable picture is not packed as a broken background.
mv "$WALLPAPERS/autumn-leaves.jpg" "$TEST_ROOT/wallpaper.jpg"
printf 'not really a jpeg' > "$WALLPAPERS/autumn-leaves.jpg"
activate '{ name = "autumn-leaves"; }' >/dev/null
unpack
[[ -f $TEST_ROOT/unpacked/background.png ]] || fail 'an unreadable wallpaper is not replaced by a plain one'
[[ ! -f $TEST_ROOT/unpacked/background.jpg ]] || fail 'an unreadable wallpaper is packed anyway'
mv "$TEST_ROOT/wallpaper.jpg" "$WALLPAPERS/autumn-leaves.jpg"
activate '{ name = "autumn-leaves"; transparency = false; }' >/dev/null
unpack

# Transparency off makes the surfaces solid; a faint shadow stays faint.
grep -qx 'windowBg: #261814;' "$TEST_ROOT/unpacked/colors.tdesktop-theme" ||
  fail 'transparency off leaves the window translucent'
grep -qP '^shadowFg: #[0-9a-f]{6}2e;$' "$TEST_ROOT/unpacked/colors.tdesktop-theme" ||
  fail 'transparency off made a shadow solid'

# An unchanged theme is not repacked, so AyuGram is handed a changed file only
# when something actually changed.
before=$(stat -c %Y "$THEME_FILE")
activate '{ name = "autumn-leaves"; transparency = false; }' >/dev/null
[[ $(stat -c %Y "$THEME_FILE") == "$before" ]] || fail 'the theme was repacked without a change'

for theme in gruvbox autumn-leaves onedark; do
  activate "{ name = \"$theme\"; }" >/dev/null
  (( $(stat -c %s "$THEME_FILE") < 5 * 1024 * 1024 )) || fail "$theme: the theme is over Telegram's 5 MB limit"
  unpack
  colors=$TEST_ROOT/unpacked/colors.tdesktop-theme
  [[ -f $colors ]] || fail "$theme: no colors.tdesktop-theme inside"

  # Every line is a literal color: a reference is resolved while the theme is
  # generated, so none depends on the order tdesktop reads them in.
  bad=$(grep -vP '^(//.*|\w+: #[0-9a-f]{6}([0-9a-f]{2})?;)$' "$colors" || true)
  [[ -z $bad ]] || fail "$theme: lines that are not a color: $bad"

  # Nothing the hand-made theme set is left to the stock light palette, apart
  # from keys AyuGram no longer knows.
  missing=$(comm -23 <(grep -oP '^\w+(?=:)' "$TEST_ROOT/hand-made" | sort -u) \
                     <(grep -oP '^\w+(?=:)' "$colors" | sort -u) | wc -l)
  (( missing <= 22 )) || fail "$theme: $missing keys the hand-made theme set are unset"
done

# Handed the colors the hand-made theme was painted with, the table paints it
# again: every color within a small step of the original and every alpha the
# same. The per-user colors are the palette's ANSI ones instead, so they are
# left out.
keys() { grep -oP '^\w+: #[0-9a-fA-F]{6,8}(?=;)' "$1" | tr -d ':' | tr 'A-F' 'a-f' | sort; }
git -C "$REPO_ROOT" show "$BEFORE:modules/theme/palettes/autumn-glass.nix" > "$TEST_ROOT/autumn-glass.nix"
nix eval --impure --raw --expr "
  let lib = (builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.pkgs.lib;
      p = import $TEST_ROOT/autumn-glass.nix;
  in import $REPO_ROOT/modules/theme/telegram-theme.nix { inherit lib; }
    (p.roles // p.ansi // { text = \"#f6e9da\"; alpha.window = 0.9; })" 2>/dev/null > "$TEST_ROOT/repainted" ||
  fail 'cannot render the table with the hand-made colors'
python3 - <(keys "$TEST_ROOT/hand-made") <(keys "$TEST_ROOT/repainted") <<'PY' || fail 'the table no longer repaints the hand-made theme'
import sys
load = lambda path: dict(line.split() for line in open(path))
was, now = load(sys.argv[1]), load(sys.argv[2])
bad = []
for key, before in was.items():
    if key not in now or "Peer" in key:
        continue
    after = now[key]
    a, b = ([int(v[i:i + 2], 16) for i in (1, 3, 5)] for v in (before, after))
    if max(abs(x - y) for x, y in zip(a, b)) > 32 or (before[7:] or "ff") != (after[7:] or "ff"):
        bad.append(f"{key}: {before} -> {after}")
print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad else 0)
PY

# An override in home.nix reaches the theme.
nix eval --impure --raw --expr "
  let lib = (builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.pkgs.lib;
      cfg = ((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
        modules = [ { dotfiles.theme.overrides.telegram.base = \"#123456\"; } ];
      }).config;
  in import $REPO_ROOT/modules/theme/telegram-theme.nix { inherit lib; } (cfg.dotfiles.theme.forApp \"telegram\")" 2>/dev/null |
  grep -qP '^windowBg: #123456' || fail 'an override does not reach Telegram'

printf 'theme Telegram tests passed\n'
