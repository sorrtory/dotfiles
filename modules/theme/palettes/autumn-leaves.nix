# Autumn Leaves: Gruvbox's structure in the wallpaper's colors. The surfaces
# are the deep red-brown the picture sits in rather than Gruvbox's neutral
# grays, the text is its warm parchment, and the accents are its copper and
# maple. The text is a pastel cream with the picture's peach in it rather than
# Gruvbox's yellowed one, which is easier to read a page of. It carries more
# contrast than Gruvbox — the background is darker and the text lighter —
# while staying short of a pure cream on near-black, which is harsh to read a
# file in. Warmth is what keeps that
# readable: the same numbers in Gruvbox's neutral grays glare.
#
# The 16 terminal colors keep Gruvbox's roles and shapes, each pulled toward
# the picture: brighter copper, gold, olive, and red leaves alongside smoky
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
    text = "#fbeada";
    subtext = "#e4cbb1";
    muted = "#aa8973";
    accent = "#df773d";
    accent2 = "#efad58";
    error = "#ed624a";
    warning = "#efad58";
    success = "#c9b849";
    info = "#a4cc74";
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
    blue = "#b19680";
    magenta = "#cc7865";
    cyan = roles.info;
    white = "#f2ddc0";
    brightBlack = "#977663";
    brightRed = "#f77b60";
    brightGreen = "#dbc657";
    brightYellow = "#ffc175";
    brightBlue = "#d0ad91";
    brightMagenta = "#e8a087";
    brightCyan = "#b1da8b";
    brightWhite = roles.text;
  };
}
