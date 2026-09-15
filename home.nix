{ ... }:

{
  imports = [
    ./modules/apparmor.nix
    ./modules/desktops/gnome.nix
    ./modules/packages.nix
    ./modules/programs/git.nix
    ./modules/programs/mpv.nix
    ./modules/programs/neovim.nix
    ./modules/programs/obsidian.nix
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

  # A non-NixOS distro. Among other things this puts the profile's share
  # directory into the login session's XDG_DATA_DIRS, which is how GNOME finds
  # Nix-installed Shell extensions and desktop entries.
  targets.genericLinux.enable = true;
  # The target would also deliver GPU drivers through a root-owned
  # /run/opengl-driver. docs/DECISIONS.md keeps them in MPV's wrapper instead.
  targets.genericLinux.gpu.enable = false;

  dotfiles.localProxy.enable = true;
  # Change this to switch VPN profiles. The staging configuration in flake.nix
  # overrides it, because the VM runs alongside this machine.
  dotfiles.vpn.identity = "laptop";
  dotfiles.vpnizedApps.vesktop.enable = true;

  programs.home-manager.enable = true;
}
