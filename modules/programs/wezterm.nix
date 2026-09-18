{ config, pkgs, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/wezterm";
in
{
  # Like tmux, this owns the package but not through programs.wezterm, which
  # generates wezterm.lua itself. The config is a native Lua file that WezTerm
  # reloads on save, so it stays live-editable in configs/wezterm.
  home.packages = [ pkgs.wezterm ];

  xdg.configFile."wezterm/wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/wezterm.lua";
}
