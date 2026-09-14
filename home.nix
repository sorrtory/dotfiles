{ ... }:

{
  imports = [
    ./modules/packages.nix
    ./modules/programs/git.nix
    ./modules/programs/mpv.nix
    ./modules/programs/neovim.nix
    ./modules/programs/ssh.nix
    ./modules/programs/sing-box.nix
    ./modules/programs/sublime-text.nix
    ./modules/programs/tmux.nix
    ./modules/programs/vscode.nix
    ./modules/programs/yazi.nix
    ./modules/programs/zsh.nix
    ./modules/secrets.nix
  ];

  home.username = "z";
  home.homeDirectory = "/home/z";
  home.stateVersion = "26.05";

  dotfiles.localProxy.enable = true;

  programs.home-manager.enable = true;
}
