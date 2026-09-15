{ lib, pkgs, ... }:

let
  inherit (lib.hm.gvariant) mkEmptyArray type;

  mediaKeys = "org/gnome/settings-daemon/plugins/media-keys";

  # Custom launchers, keyed by their dconf path name. Commands are plain names
  # because the session PATH starts with the Home Manager profile (see
  # modules/packages.nix). Firefox, Nautilus and Flatpak stay distro-provided,
  # so on a machine without Flatpak and Gradia <Shift>F11 does nothing.
  launchers = {
    code = {
      binding = "<Super>c";
      command = "code";
    };
    explorer = {
      binding = "<Super>e";
      command = "nautilus -w";
    };
    firefox = {
      binding = "<Super>f";
      command = "firefox";
    };
    gradia = {
      binding = "<Shift>F11";
      command = "flatpak run be.alexandervanhee.gradia --screenshot=INTERACTIVE";
    };
    obsidian = {
      binding = "<Super>n";
      command = "obsidian";
    };
    spotify = {
      binding = "<Super>s";
      command = "spotify";
    };
    # AyuGram replaces the official client. The launcher keeps the generic
    # name, so switching back changes only the command.
    telegram = {
      binding = "<Super>m";
      command = "AyuGram";
    };
    typing = {
      binding = "<Super>t";
      command = "subl";
    };
  };
in
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

  dconf.settings = {
    # For the same reason, a session-mode extension can only be switched off
    # through disabled-extensions. Ubuntu's desktop icons stay off, as on the
    # current PC; the entry is inert where the distro has no such extension.
    "org/gnome/shell".disabled-extensions = [ "ding@rastersoft.com" ];

    # The whole list is declared, so a switch never duplicates an entry.
    ${mediaKeys}.custom-keybindings = lib.mapAttrsToList (
      name: _: "/${mediaKeys}/custom-keybindings/${name}/"
    ) launchers;

    # Each replaces GNOME's default list for that action rather than adding
    # to it.
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" ];
      move-to-workspace-left = [ "<Control><Super>Left" ];
      move-to-workspace-right = [ "<Control><Super>Right" ];
      switch-to-workspace-left = [ "<Control><Alt>Left" ];
      switch-to-workspace-right = [ "<Control><Alt>Right" ];
    };

    # GNOME's defaults would take the obsidian (<Super>n), spotify (<Super>s)
    # and telegram (<Super>m) keys before the launchers see them.
    "org/gnome/shell/keybindings" = {
      focus-active-notification = [ "disabled" ];
      toggle-quick-settings = [ "disabled" ];
      toggle-message-tray = mkEmptyArray type.string;
    };
  }
  // lib.mapAttrs' (
    name: launcher:
    lib.nameValuePair "${mediaKeys}/custom-keybindings/${name}" (launcher // { inherit name; })
  ) launchers;

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
