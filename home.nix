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
    ./modules/programs/vpnized-apps
    ./modules/programs/vscode.nix
    ./modules/programs/yazi.nix
    ./modules/programs/zsh.nix
    ./modules/secrets.nix
  ];

  home.username = "z";
  home.homeDirectory = "/home/z";
  home.stateVersion = "26.05";

  dotfiles.localProxy.enable = true;
  # Change this to switch VPN profiles. The staging configuration in flake.nix
  # overrides it, because the VM runs alongside this machine.
  dotfiles.vpn.identity = "laptop";
  dotfiles.vpnizedApps.vesktop.enable = true;

  programs.home-manager.enable = true;
}
