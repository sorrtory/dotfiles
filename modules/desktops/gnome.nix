{ pkgs, ... }:

{
  # GNOME Shell finds these through ~/.nix-profile/share, which reaches the
  # session's XDG_DATA_DIRS only through targets.genericLinux (see home.nix).
  # A newly installed extension needs a re-login on Wayland before it loads.
  #
  # A distro's own extensions are not listed. Ubuntu enables Ubuntu Dock,
  # AppIndicators, Tiling Assistant, and the snapd and web search providers
  # through its session mode (/usr/share/gnome-shell/modes/ubuntu.json),
  # independently of enabled-extensions, which a fresh install leaves empty.
  programs.gnome-shell = {
    enable = true;
    extensions = with pkgs.gnomeExtensions; [
      { package = blur-my-shell; }
      { package = clipboard-indicator; }
      { package = hide-top-bar; }
    ];
  };

  # For the same reason, a session-mode extension can only be switched off
  # through disabled-extensions. Ubuntu's desktop icons stay off, as on the
  # current PC; the entry is inert where the distro has no such extension.
  dconf.settings."org/gnome/shell".disabled-extensions = [ "ding@rastersoft.com" ];

  # Nixpkgs rather than the distro, so every machine gets them the same way
  # whether it runs Ubuntu, Fedora or something else. gnome-tweaks costs about
  # 850 MiB of closure, because it links against its own GNOME Shell and
  # Mutter; that was accepted over a per-distro install.
  home.packages = with pkgs; [
    dconf-editor
    gnome-extension-manager
    gnome-tweaks
  ];
}
