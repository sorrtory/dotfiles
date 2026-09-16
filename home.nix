{ ... }:

{
  imports = [
    ./modules/apparmor.nix
    ./modules/desktops/gnome.nix
    ./modules/packages.nix
    ./modules/directories.nix
    ./modules/scripts.nix
    ./modules/programs/firefox.nix
    ./modules/programs/git.nix
    ./modules/programs/mpv.nix
    ./modules/programs/neovim.nix
    ./modules/programs/obsidian.nix
    ./modules/programs/ssh.nix
    ./modules/programs/sing-box
    ./modules/programs/sublime-text.nix
    ./modules/programs/tmux.nix
    ./modules/programs/vault.nix
    ./modules/programs/vpnized-apps
    ./modules/programs/vscode.nix
    ./modules/programs/yazi.nix
    ./modules/programs/zsh.nix
    ./modules/secrets.nix
  ];

  home.username = "z";
  home.homeDirectory = "/home/z";
  home.stateVersion = "26.05";

  dotfiles.repositories = {
    "Projects/Uni-Mobile" = "git@github.com:sorrtory/Uni-Mobile.git";
    "Projects/Uni-Julia" = "git@github.com:sorrtory/Uni-Julia.git";
    "Projects/Uni-AI" = "git@github.com:sorrtory/Uni-AI.git";
    "Projects/Uni-Bioinformatics" = "git@github.com:sorrtory/Uni-Bioinformatics.git";
    "Projects/freebooru" = "git@github.com:sorrtory/freebooru.git";
    "Projects/scripts" = "git@github.com:sorrtory/scripts.git";
    "Projects/secrets" = "git@github.com:sorrtory/secrets.git";
    "Documents/keepass" = "git@github.com:sorrtory/keepass.git";
    "Documents/Knowledge-Database" = "git@github.com:sorrtory/knowledge-database.git";
  };

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
  # AyuGram replaces the official Telegram client; calls need UDP, so it is
  # a VPNized app rather than a plain proxy wrapper. Login and session state
  # stay machine-local.
  dotfiles.vpnizedApps.ayugram.enable = true;

  programs.home-manager.enable = true;
}
