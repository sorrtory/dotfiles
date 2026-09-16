{ config, lib, pkgs, ... }:

let
  inherit (lib.hm.gvariant) mkEmptyArray mkTuple type;

  mediaKeys = "org/gnome/settings-daemon/plugins/media-keys";

  # Where home.nix clones the knowledge database. Obsidian takes a vault as a
  # URI rather than an argument, and reads the query value whole, so the path's
  # separators are encoded.
  knowledgeDatabase = "${config.home.homeDirectory}/Documents/Knowledge-Database";
  knowledgeDatabaseUri =
    "obsidian://open?path=" + lib.replaceStrings [ "/" ] [ "%2F" ] knowledgeDatabase;

  # Declared by modules/programs/vault.nix, which owns the convention. This is
  # the vault the desktop acts on, not a default the command knows about. The
  # vault itself is the operator's data and is not created here: until it
  # exists, the key reports that rather than making one.
  desktopVault = config.dotfiles.desktopVault;

  # Custom launchers, keyed by their dconf path name. Commands are plain names
  # because the session PATH starts with the Home Manager profile (see
  # modules/packages.nix). Firefox and Nautilus stay distro-provided.
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
      # The command Gradia's own preferences suggest outside Flatpak.
      command = "gradia --screenshot=INTERACTIVE";
    };
    # The knowledge database is public-safe: it needs no vault and no unlocking,
    # which is the whole reason it has a key of its own.
    knowledge = {
      binding = "<Super>k";
      command = "obsidian ${knowledgeDatabaseUri}";
    };
    # Unlocks the private vault if it is locked, asking for the password
    # through a dialog, then opens its Notes/ in Obsidian. An already-unlocked
    # vault opens without a prompt.
    notes = {
      binding = "<Super>n";
      command = "vault notes ${desktopVault}";
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

    # Caps Lock is Escape and Shift+Caps Lock is the real Caps Lock. Alt+Shift
    # switches layout, alongside GNOME's own <Super>space, which stays at its
    # default. xkb-options is replaced as a whole list, so every option to keep
    # is named here. The console and GDM keymap in /etc/default/keyboard stay
    # host-owned.
    "org/gnome/desktop/input-sources" = {
      sources = [
        (mkTuple [ "xkb" "us" ])
        (mkTuple [ "xkb" "ru" ])
      ];
      xkb-options = [
        "grp:alt_shift_toggle"
        "caps:escape_shifted_capslock"
      ];
    };

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

    # Both already match Ubuntu's defaults. They are declared so other distros
    # place windows the same way. Mutter's edge-tiling and toggle-tiled-* keys
    # are left out on purpose: Tiling Assistant sets them while it runs and
    # restores them when disabled.
    "org/gnome/mutter" = {
      center-new-windows = true;
      workspaces-only-on-primary = true;
    };

    # Ubuntu Dock (dash-to-dock) is distro-provided. These keys are inert
    # wherever it isn't installed. The whole set is declared, not only its
    # differences from Ubuntu's defaults, so the dock is the same wherever the
    # extension runs. The preferred-monitor keys are machine-specific and left
    # to each machine.
    "org/gnome/shell/extensions/dash-to-dock" = {
      always-center-icons = true;
      autohide = true;
      background-opacity = 0.0;
      click-action = "minimize";
      dash-max-icon-size = 48;
      dock-fixed = false;
      dock-position = "LEFT";
      extend-height = true;
      height-fraction = 0.9;
      hot-keys = false;
      intellihide = true;
      intellihide-mode = "ALL_WINDOWS";
      isolate-monitors = false;
      isolate-workspaces = false;
      show-show-apps-button = false;
      show-trash = false;
      transparency-mode = "FIXED";
    };

    # The Yaru-sage-dark themes are distro-provided and exist only on Ubuntu.
    # Elsewhere the names fall back, while color-scheme and accent-color still
    # apply.
    "org/gnome/desktop/interface" = {
      accent-color = "slate";
      clock-show-weekday = true;
      color-scheme = "prefer-dark";
      gtk-enable-primary-paste = true;
      gtk-theme = "Yaru-sage-dark";
      icon-theme = "Yaru-sage-dark";
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
