{ config, lib, pkgs, ... }:

let
  inherit (lib.hm.gvariant) mkEmptyArray mkTuple type;

  # Stable and unstable Nixpkgs both still carry 1.1.1, which predates the
  # CLI theme selector and Firefox output described by Rewaita's current
  # guide. packages/rewaita.nix keeps the newer upstream pin local to the one
  # consumer that needs it.
  rewaita = pkgs.callPackage ../../packages/rewaita.nix { };
  rewaitaPreferences = pkgs.writeText "rewaita-preferences.json" (builtins.toJSON {
    light-theme = "Gruvbox Medium 🌴.css";
    dark-theme = "Gruvbox Medium 🌴.css";
    window-controls = "default";
    modify-gtk3-theme = true;
    modify-gnome-shell = true;
    run-in-background = false;
    # Rewaita's transparency toggle uses its built-in translucent surfaces;
    # the local package override sets those GTK surfaces to 90% opacity.
    transparency = true;
    window = false;
    sharp = false;
    firefox-theme = true;
    accent-fg = false;
    accent-tabs = true;
    light-text = false;
    dark-panel = false;
    trans-panel = false;
    no-pills = false;
    accent = "'orange'";
  });

  # Every image type nomacs's own .desktop file declares support for (see its
  # MimeType=), plus the video types mpv already opened before this file
  # existed. GNOME's "Open With → Set as default" rewrites this file
  # live, same as Rewaita's prefs.json, so this only seeds it for a fresh
  # profile: whatever the GUI decides afterwards, including for the mime
  # types left out here (scheme handlers, editor associations, and image
  # formats nomacs cannot open), stays untouched.
  defaultMimeApps = pkgs.writeText "mimeapps.list" ''
    [Default Applications]
    image/avif=org.nomacs.ImageLounge.desktop
    image/bmp=org.nomacs.ImageLounge.desktop
    image/gif=org.nomacs.ImageLounge.desktop
    image/heic=org.nomacs.ImageLounge.desktop
    image/heif=org.nomacs.ImageLounge.desktop
    image/jpeg=org.nomacs.ImageLounge.desktop
    image/jxl=org.nomacs.ImageLounge.desktop
    image/png=org.nomacs.ImageLounge.desktop
    image/tiff=org.nomacs.ImageLounge.desktop
    image/webp=org.nomacs.ImageLounge.desktop
    image/x-eps=org.nomacs.ImageLounge.desktop
    image/x-ico=org.nomacs.ImageLounge.desktop
    image/x-portable-bitmap=org.nomacs.ImageLounge.desktop
    image/x-portable-graymap=org.nomacs.ImageLounge.desktop
    image/x-portable-pixmap=org.nomacs.ImageLounge.desktop
    image/x-xbitmap=org.nomacs.ImageLounge.desktop
    image/x-xpixmap=org.nomacs.ImageLounge.desktop
    video/3gp=mpv.desktop
    video/3gpp=mpv.desktop
    video/3gpp2=mpv.desktop
    video/avi=mpv.desktop
    video/divx=mpv.desktop
    video/dv=mpv.desktop
    video/flv=mpv.desktop
    video/fli=mpv.desktop
    video/mkv=mpv.desktop
    video/mp2t=mpv.desktop
    video/mp4=mpv.desktop
    video/mp4v-es=mpv.desktop
    video/mpeg=mpv.desktop
    video/msvideo=mpv.desktop
    video/ogg=mpv.desktop
    video/quicktime=mpv.desktop
    video/vnd.avi=mpv.desktop
    video/vnd.divx=mpv.desktop
    video/vnd.mpegurl=mpv.desktop
    video/vnd.rn-realvideo=mpv.desktop
    video/webm=mpv.desktop
    video/x-avi=mpv.desktop
    video/x-flc=mpv.desktop
    video/x-flic=mpv.desktop
    video/x-flv=mpv.desktop
    video/x-m4v=mpv.desktop
    video/x-mpeg2=mpv.desktop
    video/x-mpeg3=mpv.desktop
    video/x-ms-afs=mpv.desktop
    video/x-ms-asf=mpv.desktop
    video/x-ms-wmv=mpv.desktop
    video/x-ms-wmx=mpv.desktop
    video/x-ms-wvxvideo=mpv.desktop
    video/x-msvideo=mpv.desktop
    video/x-ogm=mpv.desktop
    video/x-ogm+ogg=mpv.desktop
    video/x-theora=mpv.desktop
    video/x-theora+ogg=mpv.desktop
  '';

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

  # Run or Raise matches application identity, never a browser tab mentioning
  # the app. Obsidian also needs the vault suffix in its window title.
  # Commands are plain names because the session PATH starts with the profile (see
  # modules/packages.nix). Firefox, Nautilus and Ptyxis stay distro-provided.
  launchers = {
    code = {
      binding = "<Super>c";
      command = "code";
      wmClass = "/^[Cc]ode$/";
    };
    explorer = {
      binding = "<Super>e";
      command = "nautilus";
      wmClass = "/^(org\\.gnome\\.Nautilus|[Nn]autilus)$/";
    };
    firefox = {
      binding = "<Super>f";
      command = "firefox";
      wmClass = "/^(firefox|Firefox|org\\.mozilla\\.firefox)$/";
    };
    # The knowledge database is public-safe: it needs no vault and no unlocking,
    # which is the whole reason it has a key of its own.
    knowledge = {
      binding = "<Super>k";
      command = "obsidian ${knowledgeDatabaseUri}";
      wmClass = "/^(obsidian|Obsidian|md\\.Obsidian)$/";
      title = "/(^| - )Knowledge-Database - Obsidian( v?[0-9.]+)?$/";
    };
    # Always check the mount: a forced lock can leave a Notes window behind.
    # Focus it immediately, but still unlock through the usual dialog when
    # needed. An already-unlocked vault opens without a password prompt.
    notes = {
      binding = "<Super>n";
      mode = "always-run";
      command = "vault notes ${lib.escapeShellArg desktopVault}";
      wmClass = "/^(obsidian|Obsidian|md\\.Obsidian)$/";
      title = "/(^| - )Notes - Obsidian( v?[0-9.]+)?$/";
    };
    spotify = {
      binding = "<Super>s";
      command = "spotify";
      wmClass = "/^[Ss]potify$/";
    };
    # vpnized-apps/default.nix replaces this command with the launcher that
    # always routes Vesktop through the VPN, same as telegram below.
    vesktop = {
      binding = "<Super>d";
      command = "vesktop";
      wmClass = "/^[Vv]esktop$/";
    };
    # AyuGram replaces the official client. The launcher keeps the generic
    # name, so switching back changes only the command.
    telegram = {
      binding = "<Super>m";
      command = "AyuGram";
      wmClass = "/^(AyuGram|com\\.ayugram\\.desktop)$/";
    };
    # home.nix picks the terminal; see terminals below.
    terminal = { binding = "<Control><Alt>t"; } // terminals.${config.dotfiles.terminal};
    typing = {
      binding = "<Super>t";
      command = "subl";
      wmClass = "/^(Sublime_text|sublime_text)$/";
    };
  };

  # Ptyxis is Fedora's distro-provided terminal, kept alongside Firefox and
  # Nautilus rather than a Home Manager package. WezTerm comes from
  # modules/programs/wezterm.nix.
  terminals = {
    ptyxis = {
      command = "ptyxis";
      wmClass = "/^(org\\.gnome\\.Ptyxis|ptyxis)$/";
    };
    wezterm = {
      command = "wezterm";
      wmClass = "/^org\\.wezfurlong\\.wezterm$/";
    };
  };

  # This is an action rather than an application switch: every press captures.
  actionLaunchers.gradia = {
    binding = "<Shift>F11";
    command = "gradia --screenshot=INTERACTIVE";
  };

  # Keep the paths and bindings in one table. Quote fields for the extension's
  # comma-separated format (the vault path can contain a comma).
  shortcutLine = _: launcher:
    lib.concatStringsSep "," (map (field: "\"${field}\"") [
      (launcher.binding + lib.optionalString (launcher ? mode) ":${launcher.mode}")
      launcher.command
      launcher.wmClass
      (launcher.title or "")
    ]);
in
{
  options.dotfiles.terminal = lib.mkOption {
    type = lib.types.enum (lib.attrNames terminals);
    default = "ptyxis";
    example = "wezterm";
    description = "The terminal Ctrl+Alt+T runs or raises.";
  };

  config = {
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
        { package = run-or-raise; }
        { package = user-themes; }
      ];
    };

    # Run or Raise reads this file when enabled; re-login after first install,
    # or disable/re-enable the extension after changing the shortcut table.
    xdg.configFile."run-or-raise/shortcuts.conf".text =
      lib.concatStringsSep "\n" (lib.mapAttrsToList shortcutLine launchers) + "\n";

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

      # Application keys belong exclusively to Run or Raise. Replacing this
      # list also releases the old media-key registrations on migration.
      ${mediaKeys}.custom-keybindings = lib.mapAttrsToList (
        name: _: "/${mediaKeys}/custom-keybindings/${name}/"
      ) actionLaunchers;

      "org/gnome/shell/extensions/run-or-raise" = {
        isolate-workspace = false;
        move-window-to-active-workspace = false;
        switch-back-when-focused = false;
        minimize-when-unfocused = false;
        center-mouse-to-focused-window = false;
        dbus = false;
      };

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

      # Spotify's window has no alpha channel, even with Chromium's
      # --enable-transparent-visuals, so its CSS cannot make it see-through the
      # way Rewaita does for GTK and Firefox. Blur my Shell fades the whole
      # window instead, text included, and blurs what is behind it. Opacity is
      # out of 255; dynamic opacity would make the focused window opaque again.
      "org/gnome/shell/extensions/blur-my-shell/applications" = {
        blur = true;
        whitelist = [ "Spotify" ];
        opacity = 230;
        dynamic-opacity = false;
      };

      # Rewaita reads GNOME's accent to choose within Gruvbox's palette. GTK 3
      # starts from adw-gtk3 while Rewaita supplies its generated color override;
      # icons remain a regular packaged theme rather than generated CSS.
      "org/gnome/desktop/interface" = {
        accent-color = "orange";
        clock-show-weekday = true;
        color-scheme = "prefer-dark";
        gtk-enable-primary-paste = true;
        gtk-theme = "adw-gtk3-dark";
        icon-theme = "Yaru-wartybrown-dark";
      };

      # Rewaita writes this Shell theme beneath ~/.local/share/themes. The User
      # Themes extension owns loading it; Rewaita refreshes the CSS at login.
      "org/gnome/shell/extensions/user-theme" = {
        name = "rewaita";
      };
    }
    // lib.mapAttrs' (
      name: launcher:
      lib.nameValuePair "${mediaKeys}/custom-keybindings/${name}" (launcher // { inherit name; })
    ) actionLaunchers;

    # Nixpkgs rather than the distro, so every machine gets them the same way
    # whether it runs Ubuntu, Fedora or something else. gnome-tweaks costs about
    # 850 MiB of closure, because it links against its own GNOME Shell and
    # Mutter; that was accepted over a per-distro install.
    home.packages = with pkgs; [
      adw-gtk3
      dconf-editor
      gnome-extension-manager
      gnome-tweaks
      rewaita
      # Provides the Yaru-wartybrown-dark icons set above, so Nautilus finds the
      # warm variant on every distro rather than falling back to generic icons.
      yaru-theme
    ];

    # Preferences stay mutable so the GUI's Fine Tune controls remain useful.
    # Seed only a new installation; subsequent edits belong to Rewaita.
    home.activation.seedRewaitaPreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      preferences="$HOME/.local/share/rewaita/prefs.json"
      if [[ ! -e $preferences ]]; then
        run mkdir -p "$(dirname "$preferences")"
        run cp --no-preserve=mode ${rewaitaPreferences} "$preferences"
      fi
    '';

    # Default apps stay mutable the same way: xdg-mime and "Open With → Set as
    # default" both rewrite mimeapps.list live, so this seeds it only when the
    # file doesn't exist yet rather than owning it outright.
    home.activation.seedDefaultMimeApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mimeApps="$HOME/.config/mimeapps.list"
      if [[ ! -e $mimeApps ]]; then
        run mkdir -p "$(dirname "$mimeApps")"
        run cp --no-preserve=mode ${defaultMimeApps} "$mimeApps"
      fi
    '';

    # Run in the real graphical session so Rewaita can refresh GNOME Shell and
    # discover Firefox's machine-local profile. Repeating the preset is
    # idempotent and also repairs generated CSS after an upstream format change.
    xdg.configFile."autostart/rewaita-theme.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Apply Rewaita autumn theme
      Comment=Generate Gruvbox GTK, GNOME Shell and Firefox colors
      Exec=${rewaita}/bin/rewaita --theme=gruvbox-medium
      OnlyShowIn=GNOME;
      X-GNOME-Autostart-enabled=true
      X-GNOME-Autostart-Delay=5
    '';
  };
}
