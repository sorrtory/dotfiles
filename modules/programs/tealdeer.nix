{ config, pkgs, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/tealdeer";
in
{
  home.packages = [ pkgs.tealdeer ];

  xdg.configFile."tealdeer/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/config.toml";
}
