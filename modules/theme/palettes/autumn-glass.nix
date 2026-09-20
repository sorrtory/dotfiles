# Autumn Glass: espresso surfaces, parchment text, copper and maple accents
# and a muted teal, from the theme AyuGram, Obsidian and Spotify carried
# before there was a palette (configs/ayugram/autumn-glass). Two tweaks come
# from the terminal: text is brighter than that theme's #f6e9da, and the
# normal ANSI colors are Gruvbox's bright ones, because Gruvbox's dim neutrals
# sit too close to a dark background.
{
  roles = {
    base = "#261814";
    mantle = "#1d1210";
    surface = "#34231e";
    overlay = "#4a3028";
    text = "#fbf1c7";
    subtext = "#bda18e";
    muted = "#957c6e";
    accent = "#c86138";
    accent2 = "#e9a15e";
    error = "#e96b58";
    warning = "#e9a15e";
    success = "#6fc5b7";
    info = "#79c9ba";
  };

  # No Neovim plugin carries these colors, and no VS Code extension does
  # either, so both editors generate a theme from the palette instead.
  assets = {
    gnomeAccent = "orange";
    iconTheme = "Yaru-wartybrown-dark";
  };

  overrides = {
    # Spotify is where this palette came from, so it keeps the hand-picked
    # shades of the theme it was taken from rather than the steps
    # modules/theme/spotify-scheme.nix derives: the stock parchment text
    # rather than the terminal's brighter one, and four surfaces the roles do
    # not name, each within a few units of the derived value but chosen by
    # eye. Every other slot comes from the roles.
    # Obsidian's hand-made theme used the same parchment text.
    obsidian.text = "#f6e9da";

    spotify = {
      text = "#f6e9da";
      scheme = {
        card = "#3a251f";
        notification = "#3a251f";
        shadow = "#0f0907";
        misc = "#725046";
        highlight-elevated = "#5a392f";
      };
    };
  };

  ansi = {
    black = "#282828";
    red = "#fb4934";
    green = "#b8bb26";
    yellow = "#fabd2f";
    blue = "#83a598";
    magenta = "#d3869b";
    cyan = "#8ec07c";
    white = "#ebdbb2";
    brightBlack = "#928374";
    brightRed = "#fb4934";
    brightGreen = "#b8bb26";
    brightYellow = "#fabd2f";
    brightBlue = "#83a598";
    brightMagenta = "#d3869b";
    brightCyan = "#8ec07c";
    brightWhite = "#ebdbb2";
  };
}
