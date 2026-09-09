{ config, pkgs, ... }:

let
  configRoot =
    "${config.home.homeDirectory}/Documents/dotfiles/configs/sublime-text";
  packageControl = pkgs.fetchurl {
    url = "https://github.com/sublimehq/package_control/releases/download/4.2.8/Package.Control.sublime-package";
    hash = "sha256-jhRvM6SOfELkouk7Dz+f4iguf8u63ZtQL++F0V8FX4M=";
  };
in
{
  home.packages = [ pkgs.sublime4 ];

  xdg.configFile."sublime-text/Packages/User/Preferences.sublime-settings".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/Preferences.sublime-settings";

  xdg.configFile."sublime-text/Packages/User/Default (Linux).sublime-keymap".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/Default (Linux).sublime-keymap";

  xdg.configFile."sublime-text/Packages/User/Package Control.sublime-settings".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/Package Control.sublime-settings";

  xdg.configFile."sublime-text/Installed Packages/Package Control.sublime-package".source =
    packageControl;
}
