{ config, lib, pkgs, ... }:

let
  proxy = config.dotfiles.localProxy;
  cfg = config.dotfiles.vpnizedApps.vesktop;
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/vesktop";
  vpn = config.dotfiles.vpn.command;
  vesktopLauncher = pkgs.writeShellApplication {
    name = "vesktop";
    runtimeEnv = {
      VPN_COMMAND = vpn;
      VPN_VESKTOP = lib.getExe pkgs.vesktop;
    };
    text = builtins.readFile ./vpnized-apps/vesktop.sh;
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
        assertion = cfg.enable -> proxy.enable;
        message = "dotfiles.vpnizedApps.vesktop requires dotfiles.localProxy.enable.";
      }];
    }
    (lib.mkIf (proxy.enable && cfg.enable) {
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
