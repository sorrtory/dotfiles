{ config, lib, pkgs, ... }:

let
  inherit (lib.hm.gvariant) mkEmptyArray mkTuple type;

  # Stable and unstable Nixpkgs both still carry 1.1.1, which predates the
  # CLI theme selector and Firefox output described by Rewaita's current
  # guide. packages/rewaita.nix keeps the newer upstream pin local to the one
  # consumer that needs it.
  rewaita = pkgs.callPackage ../../packages/rewaita.nix { };

  # Nixpkgs builds Extension Manager against libsoup3 but leaves
  # glib-networking out of its inputs, so wrapGAppsHook4 writes a wrapper
  # whose GIO_EXTRA_MODULES names only dconf. GIO then has no TLS backend,
  # falls back to GDummyTlsBackend, and every request to extensions.gnome.org
  # fails with "TLS support is unavailable": the Browse tab is empty and
  # nothing installs. NixOS never sees this because its GNOME module exports
  # glib-networking's module directory session-wide; targets.genericLinux has
  # no equivalent, so on Fedora the missing input is load-bearing. Adding it
  # here is enough: the hook picks it up and prefixes the path itself. Still
  # absent from nixpkgs master as of 2026-09-20, with no issue or PR open.
  gnome-extension-manager = pkgs.gnome-extension-manager.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ pkgs.glib-networking ];
  });

  # Blur my Shell 72 loses the windows on the secondary monitor after a
  # workspace switch. Application blur patches _finishWorkspaceSwitch to hide
  # every window of every inactive workspace, and with GNOME's
  # workspaces-only-on-primary the secondary monitor's windows are on all
  # workspaces, so hiding them for an inactive one hides them everywhere: they
  # keep working and still show in the overview and Alt+Tab, but nothing is
  # drawn. Upstream fixed it by skipping such windows (aunetx/blur-my-shell#866,
  # merged as #867 on 2026-04-29), after v72 was published on
  # extensions.gnome.org, which is where Nixpkgs fetches this from, so neither
  # the stable pin nor unstable can carry it before upstream tags v73. Drop
  # this when the packaged version rises above 72; --replace-fail then fails
  # the build rather than leaving a silently dead patch behind.
  blurMyShell = pkgs.gnomeExtensions.blur-my-shell.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace components/overview.js --replace-fail \
        'window => window.get_compositor_private().hide()' \
        'window => {
                                          if (window.is_on_all_workspaces()) return;
                                          window.get_compositor_private().hide();
                                      }'
    '';
  });

  theme = config.dotfiles.theme;
  themeColors = theme.forApp "gnome";
  rewaitaCss = import ../theme/rewaita-css.nix { inherit lib; };

  # One palette per theme, so Rewaita's own list shows them all and the
  # declared one is simply the one activation selects. Rewaita names a theme
  # by its file: lowercased, without the extension, spaces as dashes.
  paletteFile = name: "Dotfiles ${name}.css";
  paletteName = name: "dotfiles-${name}";

  rewaitaPalettes = lib.listToAttrs (map
    (name: lib.nameValuePair "rewaita/dark/${paletteFile name}" {
      text = rewaitaCss {
        colors = theme.forAppIn name "gnome";
        gnomeAccent = (theme.assetsIn name).gnomeAccent or null;
      };
    })
    (lib.attrNames theme.palettes));

  rewaitaPreferences = pkgs.writeText "rewaita-preferences.json" (builtins.toJSON {
    light-theme = paletteFile theme.name;
    dark-theme = paletteFile theme.name;
    window-controls = "default";
    modify-gtk3-theme = true;
    modify-gnome-shell = true;
    run-in-background = false;
    # Rewaita's transparency toggle uses its built-in translucent surfaces;
    # the local package override sets those GTK surfaces to 90% opacity.
    transparency = theme.transparency;
    window = false;
    sharp = false;
    firefox-theme = true;
    accent-fg = false;
    accent-tabs = true;
    light-text = false;
    dark-panel = false;
    trans-panel = false;
    no-pills = false;
    # Only read off GNOME, which reads its own accent setting instead.
    accent = "'${theme.assets.gnomeAccent or "blue"}'";
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

  # Ptyxis's profile ID format: 32 lowercase hex digits, no dashes.
  ptyxisProfile = "5f1d0c7a9e3b4c2d8a6f0b1e2d3c4a5b";

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
      # Real Obsidian windows on Wayland report their app ID as
      # md.obsidian.Obsidian (matching upstream's Flatpak/systemd identity,
      # visible in `app-md.obsidian.Obsidian-<pid>.scope`), not the
      # StartupWMClass in obsidian.desktop. Without this alternative, Run or
      # Raise never matches the running window and instead relaunches the
      # command every press, which Obsidian's single-instance lock turns into
      # an unfocused "ready" notification rather than a raise.
      wmClass = "/^(obsidian|Obsidian|md\\.Obsidian|md\\.obsidian\\.Obsidian)$/";
      title = "/(^| - )Knowledge-Database - Obsidian( v?[0-9.]+)?$/";
    };
    # Always check the mount: a forced lock can leave a Notes window behind.
    # Focus it immediately, but still unlock through the usual dialog when
    # needed. An already-unlocked vault opens without a password prompt.
    notes = {
      binding = "<Super>n";
      mode = "always-run";
      command = "vault notes ${lib.escapeShellArg desktopVault}";
      wmClass = "/^(obsidian|Obsidian|md\\.Obsidian|md\\.obsidian\\.Obsidian)$/";
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
    default = "wezterm";
    example = "ptyxis";
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
        { package = blurMyShell; }
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
        # Unlike GNOME's separate maximize action, this makes a second press
        # restore the window. Keep Alt+F10, GNOME's default toggle, alongside it.
        maximize = mkEmptyArray type.string;
        toggle-maximized = [ "<Super>Up" "<Alt>F10" ];
        move-to-workspace-left = [ "<Control><Super>Left" ];
        move-to-workspace-right = [ "<Control><Super>Right" ];
        switch-to-workspace-left = [ "<Control><Alt>Left" ];
        switch-to-workspace-right = [ "<Control><Alt>Right" ];

        # Super+1..9 switches directly to that workspace.
        switch-to-workspace-1 = [ "<Super>1" ];
        switch-to-workspace-2 = [ "<Super>2" ];
        switch-to-workspace-3 = [ "<Super>3" ];
        switch-to-workspace-4 = [ "<Super>4" ];
        switch-to-workspace-5 = [ "<Super>5" ];
        switch-to-workspace-6 = [ "<Super>6" ];
        switch-to-workspace-7 = [ "<Super>7" ];
        switch-to-workspace-8 = [ "<Super>8" ];
        switch-to-workspace-9 = [ "<Super>9" ];

        # Shift+Super+1..9 moves the active window to that workspace. Was
        # Ctrl+Super+N, but that chord races GNOME's overlay-key: if Super's
        # release is seen before Ctrl+N land as a chord, mutter treats it as a
        # bare Super tap and opens the Activities Overview, where 1..9 are
        # hardcoded (outside org/gnome/shell/keybindings) to launch the
        # dash's Nth pinned favorite instead of moving the window. This is
        # GNOME's own default binding for the action, so it's exercised far
        # more and less likely to still race.
        move-to-workspace-1 = [ "<Shift><Super>1" ];
        move-to-workspace-2 = [ "<Shift><Super>2" ];
        move-to-workspace-3 = [ "<Shift><Super>3" ];
        move-to-workspace-4 = [ "<Shift><Super>4" ];
        move-to-workspace-5 = [ "<Shift><Super>5" ];
        move-to-workspace-6 = [ "<Shift><Super>6" ];
        move-to-workspace-7 = [ "<Shift><Super>7" ];
        move-to-workspace-8 = [ "<Shift><Super>8" ];
        move-to-workspace-9 = [ "<Shift><Super>9" ];
      };

      # GNOME's defaults would take the obsidian (<Super>n), spotify (<Super>s)
      # and telegram (<Super>m) keys before the launchers see them.
      "org/gnome/shell/keybindings" = {
        focus-active-notification = [ "disabled" ];
        toggle-quick-settings = [ "disabled" ];
        toggle-message-tray = mkEmptyArray type.string;

        # GNOME normally uses Super+1..9 for applications in the dash.
        switch-to-application-1 = mkEmptyArray type.string;
        switch-to-application-2 = mkEmptyArray type.string;
        switch-to-application-3 = mkEmptyArray type.string;
        switch-to-application-4 = mkEmptyArray type.string;
        switch-to-application-5 = mkEmptyArray type.string;
        switch-to-application-6 = mkEmptyArray type.string;
        switch-to-application-7 = mkEmptyArray type.string;
        switch-to-application-8 = mkEmptyArray type.string;
        switch-to-application-9 = mkEmptyArray type.string;
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
      # way Rewaita does for GTK and Firefox. Sublime Text has no opacity
      # setting at all. Blur my Shell fades the whole window instead, text
      # included, and blurs what is behind it. Opacity is out of 255; dynamic
      # opacity would make the focused window opaque again. Sublime's WM class
      # varies in case between builds, as in its launcher above.
      "org/gnome/shell/extensions/blur-my-shell/applications" = {
        blur = theme.transparency;
        whitelist = [ "Spotify" "Sublime_text" "sublime_text" ];
        opacity = 230;
        dynamic-opacity = false;
      };

      # Rewaita reads GNOME's accent to choose within the theme's palette, so
      # the theme declares which name to set and its generated palette puts
      # its own accent on that name. GTK 3 starts from adw-gtk3 while Rewaita
      # supplies its generated color override; icons remain a regular packaged
      # theme rather than generated CSS. A theme that declares neither keeps
      # what is set.
      "org/gnome/desktop/interface" = {
        clock-show-weekday = true;
        color-scheme = "prefer-dark";
        gtk-enable-primary-paste = true;
        gtk-theme = "adw-gtk3-dark";
      } // lib.optionalAttrs (theme.assets ? gnomeAccent) {
        accent-color = theme.assets.gnomeAccent;
      } // lib.optionalAttrs (theme.assets ? iconTheme) {
        icon-theme = theme.assets.iconTheme;
      };

      # Rewaita writes this Shell theme beneath ~/.local/share/themes. The User
      # Themes extension owns loading it; Rewaita refreshes the CSS at login.
      "org/gnome/shell/extensions/user-theme" = {
        name = "rewaita";
      };
    }
    // lib.optionalAttrs (theme.assets ? wallpaper) {
      # A theme may bring its own background; one that does not leaves the
      # picture alone.
      "org/gnome/desktop/background" = {
        picture-uri = "file://${theme.assets.wallpaper}";
        picture-uri-dark = "file://${theme.assets.wallpaper}";
      };
    }
    // {

      # Ptyxis's GNOME palette, with no opacity of its own: Rewaita's translucent
      # surfaces already style its window. Ptyxis generates a random profile
      # UUID on first run, so a fixed one is declared and made the only profile.
      # Profiles added in the GUI are dropped from the list at next activation.
      "org/gnome/Ptyxis" = {
        default-profile-uuid = ptyxisProfile;
        profile-uuids = [ ptyxisProfile ];
      };
      "org/gnome/Ptyxis/Profiles/${ptyxisProfile}" = {
        palette = "Gnome";
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

    # One generated palette per theme, in the directory Rewaita reads user
    # palettes from. Rewaita copies the selected one into GTK 4's gtk.css and
    # feeds its values to the GTK 3 and GNOME Shell templates.
    xdg.dataFile = rewaitaPalettes // {
      # GLib's generic terminal launcher only considers desktop files
      # registered below xdg-terminals (see the note on WezTerm below).
      "xdg-terminals/org.wezfurlong.wezterm.desktop".source =
        "${pkgs.wezterm}/share/applications/org.wezfurlong.wezterm.desktop";
    };

    # Preferences stay mutable so the GUI's Fine Tune controls remain useful:
    # only the keys this repository owns are merged into whatever is there,
    # and a fresh installation gets the whole file.
    home.activation.seedRewaitaPreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      preferences="$HOME/.local/share/rewaita/prefs.json"
      run mkdir -p "$(dirname "$preferences")"
      if [[ -e $preferences ]] && ${lib.getExe pkgs.jq} -e . "$preferences" >/dev/null 2>&1; then
        merged=$(${lib.getExe pkgs.jq} -s '.[0] * (.[1] | {
          "light-theme", "dark-theme", "transparency", "accent"
        })' "$preferences" ${rewaitaPreferences})
        printf '%s\n' "$merged" > "$preferences.new"
        run mv "$preferences.new" "$preferences"
      else
        run cp --no-preserve=mode ${rewaitaPreferences} "$preferences"
      fi
    '';

    # Rewaita regenerates GTK, GNOME Shell and Firefox CSS in the running
    # session, which needs that session: over plain SSH there is no display to
    # talk to, so GNOME waits for the login autostart below and the notice
    # says to log out and back in.
    home.activation.applyRewaitaTheme = lib.hm.dag.entryAfter [
      "dotfilesThemeInit"
      "seedRewaitaPreferences"
      "linkGeneration"
      "dconfSettings"
    ] ''
      if (( dotfilesThemeChanged )); then
        if [[ ''${XDG_CURRENT_DESKTOP-} == *GNOME* && -n ''${DBUS_SESSION_BUS_ADDRESS-}
              && ( -n ''${WAYLAND_DISPLAY-} || -n ''${DISPLAY-} ) ]]; then
          run ${lib.getExe rewaita} --theme=${paletteName theme.name} ||
            dotfilesThemeApply[gnome]=relogin
        else
          dotfilesThemeApply[gnome]=relogin
        fi
      fi
    '';

    dotfiles.theme.apps.gnome = {
      label = "GNOME Shell, GTK and Firefox";
      apply = "live";
      # The Shell, the accent and the icons change in place. GTK reads
      # gtk.css when a program starts, so windows already open keep the
      # colors they started with.
      restartNote = "already-open windows keep their colors";
    };

    # GLib's generic terminal launcher only considers desktop files registered
    # below xdg-terminals. This covers Terminal=true applications, but not
    # Nautilus's built-in "Open in Console", which hard-codes GNOME Console
    # (Ptyxis in Fedora's build). modules/programs/wezterm.nix redirects that
    # action to WezTerm.
    xdg.configFile."xdg-terminals.list".text = "org.wezfurlong.wezterm.desktop\n";

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
      Name=Apply the Rewaita theme
      Comment=Generate the theme's GTK, GNOME Shell and Firefox colors
      Exec=${lib.getExe rewaita} --theme=${paletteName theme.name}
      OnlyShowIn=GNOME;
      X-GNOME-Autostart-enabled=true
      X-GNOME-Autostart-Delay=5
    '';
  };
}
