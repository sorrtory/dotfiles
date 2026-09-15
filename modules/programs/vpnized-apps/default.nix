{ config, lib, pkgs, ... }:

let
  proxy = config.dotfiles.localProxy;
  cfg = config.dotfiles.vpnizedApps;
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
in
{
  options.dotfiles.vpnizedApps.vesktop.enable =
    lib.mkEnableOption "Vesktop, always launched through the VPN";

  config = lib.mkMerge [
    {
      assertions = [{
        assertion = cfg.vesktop.enable -> proxy.enable;
        message = "dotfiles.vpnizedApps.vesktop requires dotfiles.localProxy.enable.";
      }];
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
    })
  ];
}
