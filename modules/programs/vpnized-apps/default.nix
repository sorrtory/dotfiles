{ config, lib, pkgs, ... }:

let
  proxy = config.dotfiles.localProxy;
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
in
{
  config = lib.mkIf proxy.enable {
    home.packages = [ vpn ];

    systemd.user.services.vpn-capture = {
      Unit = {
        Description = "On-demand VPN capture namespace for tunneled programs";
        Wants = [ "sing-box.service" ];
        After = [ "sing-box.service" ];
        StopWhenUnneeded = true;
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
  };
}
