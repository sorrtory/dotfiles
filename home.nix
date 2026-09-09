{ ... }:

{
  imports = [
    ./modules/packages.nix
    ./modules/programs/sublime-text.nix
    ./modules/programs/vscode.nix
  ];

  home.username = "z";
  home.homeDirectory = "/home/z";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
