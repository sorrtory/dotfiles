# Autumn Leaves: Gruvbox's structure in the wallpaper's colors. The surfaces
# are the deep red-brown the picture sits in rather than Gruvbox's neutral
# grays, the text is its warm parchment, and the accents are its copper and
# maple. The text is a pastel cream with the picture's peach in it rather than
# Gruvbox's yellowed one, which is easier to read a page of. It carries more
# contrast than Gruvbox — the background is darker and the text lighter — while staying short of a pure cream
# on near-black, which is harsh to read a file in. Warmth is what keeps that
# readable: the same numbers in Gruvbox's neutral grays glare.
#
# The 16 terminal colors keep Gruvbox's roles and shapes, each pulled toward
# the picture: warmer reds and oranges, smoky umber in the ANSI blue slot,
# and no dim neutrals, which disappear on a background this dark. Green is the
# one color the picture cannot give — its leaves are yellow
# — so it is a dry-leaf olive, red enough to sit with the rest and still green
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
    surface = "#33221d";
    overlay = "#4d332b";
    text = "#fbeada";
    subtext = "#dcc4ab";
    muted = "#9c7f6c";
    accent = "#d2703f";
    accent2 = "#e9a15e";
    error = "#e8604c";
    warning = "#e9a15e";
    success = "#c2ad4b";
    info = "#97c973";
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
    black = "#38271f";
    red = roles.error;
    green = roles.success;
    yellow = roles.warning;
    blue = "#a98c7f";
    magenta = "#bd7467";
    cyan = roles.info;
    white = "#eedcc4";
    brightBlack = "#8a6f60";
    brightRed = "#f4715c";
    brightGreen = "#d3bf5c";
    brightYellow = "#f3b673";
    brightBlue = "#c5a798";
    brightMagenta = "#d9947f";
    brightCyan = "#a9d489";
    brightWhite = roles.text;
  };
}
