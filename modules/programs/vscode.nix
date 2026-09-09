{ config, pkgs, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/vscode";
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
  };

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/settings.json";

  xdg.configFile."Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/keybindings.json";
}
