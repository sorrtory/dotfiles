# Autumn Leaves: Gruvbox's structure in the wallpaper's colors. The surfaces
# are the deep red-brown the picture sits in rather than Gruvbox's neutral
# grays, the text is its warm parchment, and the accents are its copper and
# maple. It carries more contrast than Gruvbox — the background is darker and
# the text lighter than Gruvbox's pair — while staying short of a pure cream
# on near-black, which is harsh to read a file in.
#
# The 16 terminal colors keep Gruvbox's roles and shapes, each pulled toward
# the picture: warmer reds and oranges, olive greens, a steel blue in place of
# Gruvbox's green-leaning one, and no dim neutrals, which disappear on a
# background this dark.
{
  roles = {
    base = "#291b17";
    mantle = "#1f1311";
    surface = "#362420";
    overlay = "#4d332b";
    text = "#f2e0c8";
    subtext = "#cbb094";
    muted = "#9c7f6c";
    accent = "#d2703f";
    accent2 = "#e9a15e";
    error = "#e8604c";
    warning = "#e9a15e";
    success = "#a9b665";
    info = "#89b482";
  };

  # No Neovim plugin or VS Code extension carries these colors, so both
  # editors generate a theme from the palette. The wallpaper is
  # ~/Pictures/wallpapers/autumn-leaves.jpg, by the name of the theme.
  assets = {
    gnomeAccent = "orange";
    iconTheme = "Yaru-wartybrown-dark";
  };

  ansi = {
    black = "#3b2a24";
    red = "#e8604c";
    green = "#a9b665";
    yellow = "#e9a15e";
    blue = "#8fa9b8";
    magenta = "#d3869b";
    cyan = "#89b482";
    white = "#e6d3b8";
    brightBlack = "#8a6f60";
    brightRed = "#f4715c";
    brightGreen = "#bcc76c";
    brightYellow = "#f3b673";
    brightBlue = "#a3bcc9";
    brightMagenta = "#e09aae";
    brightCyan = "#9cc795";
    brightWhite = "#f2e0c8";
  };
}
