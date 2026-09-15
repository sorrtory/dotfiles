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

  # VS Code bundles its own Electron, whose sandbox needs a user namespace on
  # Ubuntu, or the editor aborts at startup. Its network uses the local HTTP
  # proxy from settings.json rather than the VPN capture namespace.
  dotfiles.apparmor.usernsAllowances.vscode = {
    executable = "${config.programs.vscode.package}/lib/vscode/code";
    usedBy = [ config.programs.vscode.package ];
  };
}
