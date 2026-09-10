{ ... }:

{
  imports = [
    ./modules/packages.nix
    ./modules/programs/neovim.nix
    ./modules/programs/sublime-text.nix
    ./modules/programs/vscode.nix
    ./modules/programs/zsh.nix
    ./modules/secrets.nix
  ];

  home.username = "z";
  home.homeDirectory = "/home/z";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
