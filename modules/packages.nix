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
    pkg-config
    ripgrep
    rustc
    tealdeer
    tree
    wget
    wl-clipboard
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];
}
