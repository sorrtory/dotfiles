# Rewaita's Gruvbox Medium 🌴 as it ships, with no tweaks: the desktop look
# this repository started from. Gruvbox's own names are kept for reference;
# only the roles and ANSI colors below leave this file.
let
  gruvbox = {
    bg0_h = "#1d2021";
    bg0 = "#282828";
    bg0_s = "#32302f";
    bg1 = "#3c3836";
    bg2 = "#504945";
    bg3 = "#665c54";
    bg4 = "#7c6f64";
    gray = "#928374";
    fg4 = "#a89984";
    fg2 = "#d5c4a1";
    fg1 = "#ebdbb2";
    red = "#cc241d";
    green = "#98971a";
    yellow = "#d79921";
    blue = "#458588";
    purple = "#b16286";
    aqua = "#689d6a";
    orange = "#fe8019";
    brightRed = "#fb4934";
    brightGreen = "#b8bb26";
    brightYellow = "#fabd2f";
    brightBlue = "#83a598";
    brightPurple = "#d3869b";
    brightAqua = "#8ec07c";
  };
in
with gruvbox;
{
  roles = {
    base = bg0;
    # Rewaita's headerbar.
    mantle = bg0_h;
    surface = bg1;
    overlay = bg3;
    text = fg1;
    subtext = fg2;
    muted = fg4;
    # GNOME's orange accent picks Gruvbox orange in Rewaita.
    accent = orange;
    accent2 = brightBlue;
    error = brightRed;
    warning = brightYellow;
    success = brightGreen;
    info = brightBlue;
  };

  # GNOME's accent picks the palette color the desktop highlights with, and
  # Yaru's warty brown carries the same warmth into Files and launchers.
  assets = {
    gnomeAccent = "orange";
    iconTheme = "Yaru-wartybrown-dark";
    # Gruvbox's own Neovim plugin, fed this palette's overrides.
    neovim = { colorscheme = "gruvbox"; };
    # The extension the editor ran before there was a palette. The label is
    # the one the extension itself contributes; modules/programs/vscode.nix
    # looks it up rather than guessing a file name.
    vscode = { extension = "jdinhlife.gruvbox"; theme = "Gruvbox Dark Hard"; };
  };

  overrides = {
    # Rewaita's Gruvbox Medium draws sidebar borders and GTK 3's named
    # neutrals with bg2 rather than the lighter bg3 the terminal selects with.
    gnome = { overlay = bg2; };

    # The editor sits on Gruvbox's soft background rather than the terminal's,
    # and its plain text is a cream brighter than any Gruvbox shade, because
    # the window blur fades it. Both were hand-chosen in the scheme this
    # replaced.
    sublime-text = {
      base = bg0_s;
      surface = "#45403d";
      text = "#fffaeb";
    };
    terminus = {
      base = bg0_s;
      text = "#fffaeb";
    };
  };

  ansi = {
    black = bg0;
    inherit red green yellow blue;
    magenta = purple;
    cyan = aqua;
    white = fg4;
    brightBlack = gray;
    inherit brightRed brightGreen brightYellow brightBlue;
    brightMagenta = brightPurple;
    brightCyan = brightAqua;
    brightWhite = fg1;
  };
}
