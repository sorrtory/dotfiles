{ config, lib, pkgs, ... }:

let
  proxy = config.dotfiles.localProxy;
  cfg = config.dotfiles.vpnizedApps;
  theme = config.dotfiles.theme;
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/vesktop";

  captureConfig = pkgs.writeShellApplication {
    name = "vpn-capture-config";
    runtimeInputs = [ pkgs.coreutils pkgs.jq proxy.package ];
    text = builtins.readFile ./capture-config.sh;
  };
  enter = pkgs.writeShellApplication {
    name = "vpn-enter";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.util-linux pkgs.iproute2 ];
    text = builtins.readFile ./enter.sh;
  };
  # No runtimeInputs: the program must be found on the caller's PATH, so the
  # command reaches its own dependencies by absolute path.
  vpn = pkgs.writeShellApplication {
    name = "vpn";
    runtimeEnv = {
      VPN_ENTER = lib.getExe enter;
      VPN_SYSTEMD_RUN = lib.getExe' pkgs.systemd "systemd-run";
    };
    text = builtins.readFile ../../../scripts/bin/vpn.sh;
  };

  vesktopLauncher = pkgs.writeShellApplication {
    name = "vesktop";
    runtimeEnv = {
      VPN_COMMAND = lib.getExe vpn;
      VPN_VESKTOP = lib.getExe pkgs.vesktop;
    };
    text = builtins.readFile ./vesktop.sh;
  };
  # The package with its command and desktop entry replaced by the launcher,
  # so the terminal, the icon and discord:// links all go through the VPN.
  vesktop = pkgs.symlinkJoin {
    name = "vesktop-vpn-${pkgs.vesktop.version}";
    paths = [ pkgs.vesktop ];
    postBuild = ''
      rm "$out/bin/vesktop" "$out/share/applications/vesktop.desktop"
      ln -s ${lib.getExe vesktopLauncher} "$out/bin/vesktop"
      substitute ${pkgs.vesktop}/share/applications/vesktop.desktop \
        "$out/share/applications/vesktop.desktop" \
        --replace-fail 'Exec=vesktop %U' 'Exec=${lib.getExe vesktopLauncher} %U'
    '';
  };

  ayugramLauncher = pkgs.writeShellApplication {
    name = "AyuGram";
    runtimeEnv = {
      VPN_COMMAND = lib.getExe vpn;
      VPN_AYUGRAM = lib.getExe pkgs.ayugram-desktop;
    };
    text = builtins.readFile ./ayugram.sh;
  };
  # The package with its command and desktop entry replaced by the launcher,
  # so the terminal, the icon and tg:// links all go through the VPN. A plain
  # Qt binary, unlike Vesktop's Electron, so it needs no AppArmor userns
  # allowance to run under the VPN command. The entry is DBusActivatable, so
  # GNOME starts it through the D-Bus service file and never reads its Exec;
  # that file is replaced too.
  ayugram = pkgs.symlinkJoin {
    name = "ayugram-vpn-${pkgs.ayugram-desktop.version}";
    paths = [ pkgs.ayugram-desktop ];
    postBuild = ''
      rm "$out/bin/AyuGram" "$out/share/applications/com.ayugram.desktop.desktop" \
        "$out/share/dbus-1/services/com.ayugram.desktop.service"
      ln -s ${lib.getExe ayugramLauncher} "$out/bin/AyuGram"
      substitute ${pkgs.ayugram-desktop}/share/applications/com.ayugram.desktop.desktop \
        "$out/share/applications/com.ayugram.desktop.desktop" \
        --replace-fail 'Exec=env DESKTOPINTEGRATION=1 AyuGram -- %U' \
          'Exec=env DESKTOPINTEGRATION=1 ${lib.getExe ayugramLauncher} -- %U'
      substitute ${pkgs.ayugram-desktop}/share/dbus-1/services/com.ayugram.desktop.service \
        "$out/share/dbus-1/services/com.ayugram.desktop.service" \
        --replace-fail 'Exec=${lib.getExe pkgs.ayugram-desktop}' \
          'Exec=${lib.getExe ayugramLauncher}'
    '';
  };
in
{
  options.dotfiles.vpnizedApps.vesktop.enable =
    lib.mkEnableOption "Vesktop, always launched through the VPN";
  options.dotfiles.vpnizedApps.ayugram.enable =
    lib.mkEnableOption "AyuGram, always launched through the VPN";

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.vesktop.enable -> proxy.enable;
          message = "dotfiles.vpnizedApps.vesktop requires dotfiles.localProxy.enable.";
        }
        {
          assertion = cfg.ayugram.enable -> proxy.enable;
          message = "dotfiles.vpnizedApps.ayugram requires dotfiles.localProxy.enable.";
        }
      ];
    }

    (lib.mkIf proxy.enable {
      home.packages = [ vpn ];

      # Capture creates its rootless network namespace with this binary.
      dotfiles.apparmor.usernsAllowances.sing-box = {
        executable = lib.getExe proxy.package;
        usedBy = [ proxy.package ];
      };

      systemd.user.services.vpn-capture = {
        Unit = {
          Description = "On-demand VPN capture namespace for tunneled programs";
          Wants = [ "sing-box.service" ];
          After = [ "sing-box.service" ];
          StopWhenUnneeded = true;
          # Each tunneled program's exit can stop capture, so a burst of short
          # launches (`vpn curl` in a loop) is a burst of starts. Capture never
          # restarts itself, so the default start limit only breaks those.
          StartLimitIntervalSec = 0;
        };
        Service = {
          Type = "simple";
          RuntimeDirectory = "vpn-capture";
          RuntimeDirectoryMode = "0700";
          UMask = "0077";
          ExecStartPre = "${lib.getExe captureConfig} %t/sing-box/config.json %t/vpn-capture";
          ExecStart = "${lib.getExe proxy.package} run -c %t/vpn-capture/config.json";
          NoNewPrivileges = true;
          # Do not automatically replace a live application's namespace.
          Restart = "no";
        };
      };
    })

    (lib.mkIf (proxy.enable && cfg.vesktop.enable) {
      home.packages = [ vesktop ];

      # Vesktop's two wrappers exec Nixpkgs' Electron 43, whose sandbox needs a
      # user namespace. Applications sharing that Electron share the profile,
      # and usedBy fails the build if Vesktop moves to another Electron.
      dotfiles.apparmor.usernsAllowances."electron-${lib.versions.major pkgs.electron_43.version}" = {
        executable = "${pkgs.electron_43.unwrapped}/libexec/electron/electron";
        usedBy = [ pkgs.vesktop ];
      };

      # Live-editable, so changes made in Vesktop's UI land in the repository.
      xdg.configFile."vesktop/settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${configRoot}/settings.json";

      # Vesktop's first-launch tour runs whenever state.json lacks firstLaunch.
      # It would overwrite the tray settings and can write an autostart entry
      # that starts Electron directly, outside the VPN. Seed the file once; it
      # holds window state and stays machine-local afterwards.
      home.activation.seedVesktopState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        state=${lib.escapeShellArg "${config.xdg.configHome}/vesktop/state.json"}
        if [[ ! -e $state ]]; then
          run mkdir -p "$(dirname "$state")"
          run cp --no-preserve=mode ${pkgs.writeText "vesktop-state.json" ''{ "firstLaunch": false }''} "$state"
        fi
      '';

      # Vencord reads every stylesheet in its themes directory and re-reads
      # one whenever that directory changes, so a switch recolors the running
      # client. The name never changes; what is behind it does. Which themes
      # are enabled is Vencord's own settings file, machine-local state this
      # does not own, so enabling it is a one-time step like Obsidian's.
      dotfiles.theme.liveFiles."${config.xdg.configHome}/vesktop/themes/Dotfiles.css" =
        pkgs.writeText "Dotfiles.css"
          (import ../../theme/vesktop-theme.nix { inherit lib; } (theme.forApp "vesktop"));

      dotfiles.theme.apps.vesktop = {
        label = "Vesktop";
        apply = "live";
        setup = "enable Dotfiles under Settings → Themes";
        # Vencord rewrites this file itself, so the enabled list is read back
        # rather than assumed. No file means Vesktop has never started.
        check = ''
          settings=${lib.escapeShellArg "${config.xdg.configHome}/vesktop/settings/settings.json"}
          [[ -e $settings ]] || exit 0
          ${lib.getExe pkgs.jq} -e '(.enabledThemes // []) | index("Dotfiles.css")' "$settings" >/dev/null \
            || echo "Dotfiles is not enabled under Settings → Themes"
        '';
      };
    })

    (lib.mkIf (proxy.enable && cfg.ayugram.enable) {
      home.packages = [ ayugram ];

      # Telegram's colors come from the palette like every other themed
      # app; modules/theme/telegram.nix generates and packs the theme, and
      # names the fixed path the client is pointed at once by hand.
      dotfiles.theme.telegram.enable = true;
    })
  ];
}
