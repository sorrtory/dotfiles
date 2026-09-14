{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.appVpn;
  singBox = config.dotfiles.localProxy.package;
  generator = pkgs.writeShellApplication {
    name = "vpn-capture-config";
    runtimeInputs = [ pkgs.coreutils pkgs.jq singBox ];
    text = builtins.readFile ../../scripts/bin/vpn-capture-config.sh;
  };
  enter = pkgs.writeShellApplication {
    name = "vpn-enter";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.util-linux pkgs.iproute2 ];
    text = builtins.readFile ../../scripts/bin/vpn-enter.sh;
  };
  launcher = pkgs.writeShellApplication {
    name = "vpn";
    runtimeInputs = [ pkgs.coreutils pkgs.systemd enter ];
    text = builtins.readFile ../../scripts/bin/vpn-launch.sh;
  };
in
{
  options.dotfiles.appVpn.enable = lib.mkEnableOption "opt-in application VPN capture";

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = config.dotfiles.localProxy.enable;
      message = "The application VPN requires dotfiles.localProxy.enable.";
    }];
    home.packages = [ launcher ];
    systemd.user.services.vpn-capture = {
      Unit = {
        Description = "Opt-in application network capture";
        Wants = [ "sing-box.service" ];
        After = [ "sing-box.service" ];
        StopWhenUnneeded = true;
      };
      Service = {
        Type = "simple";
        RuntimeDirectory = "vpn-capture";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        ExecStartPre = "${generator}/bin/vpn-capture-config %t/sing-box/config.json %t/vpn-capture";
        ExecStart = "${singBox}/bin/sing-box run -c %t/vpn-capture/config.json";
        NoNewPrivileges = true;
        # Do not automatically replace a live application's namespace.
        Restart = "no";
      };
    };
  };
}
