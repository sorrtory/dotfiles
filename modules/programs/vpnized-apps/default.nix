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

  # Exact-path user-namespace allowances for Ubuntu's restriction, installed by
  # the apparmor bootstrap phase; see docs/VESKTOP-APPARMOR.md. Vesktop reaches
  # its real Electron binary through two wrappers, so that path is read from
  # them here rather than pinned by hand.
  apparmorProfiles = pkgs.runCommandLocal "dotfiles-apparmor-profiles" { } ''
    mkdir "$out"
    profile() {
      if [[ ! -f $2 || $(head -c 4 "$2") != $'\x7fELF' ]]; then
        echo "AppArmor attachment for $1 is not an ELF executable: $2" >&2
        exit 1
      fi
      substitute ${./apparmor.profile} "$out/$1" \
        --subst-var-by name "$1" --subst-var-by executable "$2"
    }
    profile dotfiles-sing-box ${lib.getExe proxy.package}
    ${lib.optionalString cfg.vesktop.enable ''
      electron=$(grep -o '/nix/store/[^"]*/bin/electron' ${lib.getExe pkgs.vesktop} | head -n 1)
      profile dotfiles-vesktop-electron \
        "$(grep -o '/nix/store/[^"]*/libexec/electron/electron' "$electron" | tail -n 1)"
    ''}
  '';
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
      xdg.dataFile."dotfiles/apparmor".source = apparmorProfiles;

      # Never escalates: it only says when the phase needs running again, which
      # after a flake update moving these packages is otherwise a silent abort.
      home.activation.checkAppArmorProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        restriction=/proc/sys/kernel/apparmor_restrict_unprivileged_userns
        if [[ -r $restriction && $(<"$restriction") == 1 ]]; then
          for profile in ${apparmorProfiles}/*; do
            if ! cmp -s "$profile" "/etc/apparmor.d/''${profile##*/}"; then
              warnEcho "AppArmor profile ''${profile##*/} is missing or stale, so tunneled programs cannot start. Run: ./scripts/bootstrap.sh install apparmor"
              break
            fi
          done
        fi
      '';

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
