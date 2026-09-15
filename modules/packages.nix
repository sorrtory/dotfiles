{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # age, gh and keepassxc are also the secret-recovery app's closure. Plain
    # attributes from the same pin give identical store paths, so activation
    # reuses what recovery downloaded; an override here would fetch them twice.
    age

    # The Telegram client. Its login and session state stay machine-local.
    ayugram-desktop

    bat
    cargo
    curl
    exiftool
    fd
    ffmpeg
    fzf
    gcc
    gh
    gnumake
    go
    gnupg
    htop
    httpie
    imagemagick
    jdk21
    keepassxc

    # Global rather than per-project because mason installs ten of Neovim's
    # language servers as npm packages, and they need Node at runtime, not
    # only to install. Without it the editor looks subtly broken rather than
    # obviously broken. See docs/SOFTWARE.md for the selection this settles.
    nodejs

    obs-studio
    pkg-config
    ripgrep
    rustc
    sops
    spotify
    tealdeer
    tree
    wget
    wireguard-tools
    wl-clipboard

    # The X11 half of the same job. Both the tmux copy-mode chain and Yazi's
    # clipboard plugin pick their tool by session type, so an X session — the
    # staging VM is one — needs this to copy at all.
    xclip
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];

  # Desktop launchers and keybinding commands run in the systemd user manager's
  # environment, which never reads hm-session-vars.sh. Put the profile's bin
  # there too, ahead of the distro's directories, so a plain command name finds
  # the Nix program. A distro's Nix installer may already add it, but not every
  # login path does. Read at login.
  systemd.user.sessionVariables.PATH = "${config.home.profileDirectory}/bin\${PATH:+:}$PATH";
}
