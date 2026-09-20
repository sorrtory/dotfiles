# One Dark Pro. Surfaces and text follow Rewaita's One Dark ⚛️ palette, with
# the editor background (#282c34) as the base rather than Rewaita's bluer
# window color; the terminal colors are One Dark Pro's.
{
  roles = {
    base = "#282c34";
    # Rewaita's headerbar.
    mantle = "#21252b";
    surface = "#2c3344";
    overlay = "#3e4451";
    text = "#abb2bf";
    subtext = "#9198a5";
    muted = "#5c6370";
    accent = "#61afef";
    accent2 = "#c678dd";
    error = "#e06c75";
    warning = "#e5c07b";
    success = "#98c379";
    info = "#56b6c2";
  };

  assets = {
    gnomeAccent = "blue";
    iconTheme = "Yaru-blue-dark";
    # onedark.nvim's "darker" style, which the editor used before there was
    # a palette.
    neovim = { colorscheme = "onedark"; style = "darker"; };
  };

  ansi = {
    black = "#3f4451";
    red = "#e05561";
    green = "#8cc265";
    yellow = "#d18f52";
    blue = "#4aa5f0";
    magenta = "#c162de";
    cyan = "#42b3c2";
    white = "#d7dae0";
    brightBlack = "#4f5666";
    brightRed = "#ff616e";
    brightGreen = "#a5e075";
    brightYellow = "#f0a45d";
    brightBlue = "#4dc4ff";
    brightMagenta = "#de73ff";
    brightCyan = "#4cd1e0";
    brightWhite = "#e6e6e6";
  };
}
