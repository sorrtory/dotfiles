# Autumn Leaves: Gruvbox's structure in the wallpaper's colors. The surfaces
# are the deep red-brown the picture sits in rather than Gruvbox's neutral
# grays, the text is its warm parchment, and the accents are its copper and
# maple. The text is a warm cream with the picture's peach in it rather than
# Gruvbox's yellowed one, which is easier to read a page of. It carries more
# contrast than Gruvbox — the background is darker and the text lighter —
# while staying short of a pure cream on near-black, which is harsh to read a
# file in. Warmth is what keeps that
# readable: the same numbers in Gruvbox's neutral grays glare.
#
# The 16 terminal colors keep Gruvbox's roles and shapes, each pulled toward
# the picture: saturated copper, gold, olive, and red leaves alongside smoky
# umber in the ANSI blue slot. Green is the one color the picture cannot give
# — its leaves are yellow — so it is a dry-leaf olive, red enough to sit with
# the rest and still green
# enough to read as one in a diff. It is kept bright: at this saturation a
# green goes dull against the browns long before a warm color does.
# The ANSI magenta slot is weathered clay, not Gruvbox purple: the name is a
# terminal color index, while the hue follows the wallpaper's red-brown hair
# and leaf shadows. Its bright partner is a lighter terracotta.
# The ANSI blue slot likewise names a terminal index, not a leaf hue. Its
# muted umber and lighter mushroom follow the wallpaper's hair and coat
# shadows while staying readable as terminal text.
let
  roles = {
    base = "#261814";
    mantle = "#1c1210";
    surface = "#39251e";
    overlay = "#56382d";
    text = "#fbe2c8";
    subtext = "#e8c59f";
    muted = "#b68a68";
    accent = "#e76d27";
    accent2 = "#f3a727";
    error = "#f54e35";
    warning = "#f3a727";
    success = "#b6c62d";
    info = "#87c64b";
  };
in
{
  inherit roles;

  # No Neovim plugin or VS Code extension carries these colors, so both
  # editors generate a theme from the palette. The wallpaper is
  # ~/Pictures/wallpapers/autumn-leaves.jpg, by the name of the theme.
  assets = {
    gnomeAccent = "orange";
    iconTheme = "Yaru-wartybrown-dark";
  };

  ansi = {
    black = "#402a21";
    red = roles.error;
    green = roles.success;
    yellow = roles.warning;
    blue = "#b18355";
    magenta = "#d7676a";
    cyan = roles.info;
    white = "#f4d8ac";
    brightBlack = "#977663";
    brightRed = "#ff7057";
    brightGreen = "#cddd3a";
    brightYellow = "#ffc14d";
    brightBlue = "#c99b66";
    brightMagenta = "#ef8b7e";
    brightCyan = "#a4db62";
    brightWhite = roles.text;
  };
}
