{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bat
    cargo
    curl
    exiftool
    fd
    ffmpeg
    fzf
    gcc
    gnumake
    go
    gnupg
    htop
    httpie
    imagemagick
    jdk21
    obs-studio
    obsidian
    pkg-config
    ripgrep
    rustc
    spotify
    tealdeer
    tree
    wget
    wl-clipboard
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];
}
