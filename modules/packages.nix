{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bat
    curl
    exiftool
    fd
    fzf
    gnupg
    htop
    httpie
    imagemagick
    ripgrep
    tealdeer
    tree
    wget
    wl-clipboard
  ];
}
