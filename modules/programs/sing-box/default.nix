{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.localProxy;
  generator = pkgs.writeShellApplication {
    name = "sing-box-config";
    runtimeInputs = [ pkgs.coreutils pkgs.jq cfg.package ];
    text = builtins.readFile ./generate-config.sh;
  };
in
{
  options.dotfiles.localProxy = {
    enable = lib.mkEnableOption "the per-machine sing-box local proxy";
    package = lib.mkPackageOption pkgs "sing-box" { };
  };

  # No default: a silently shared identity makes the server's peer endpoint
  # roam between machines, so every configuration must name its own.
  options.dotfiles.vpn.identity = lib.mkOption {
    type = lib.types.enum [ "laptop" "desktop-ubuntu" "desktop-old" "desktop-win" "phone" ];
    description = ''
      This machine's exclusive VPN identity: the encrypted profile under
      secrets/wireguard/. Never run another client with the same identity
      concurrently.
    '';
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package generator ];

    sops.secrets."sing-box-wireguard" = {
      sopsFile = ../../../secrets/wireguard + "/${config.dotfiles.vpn.identity}.conf";
      format = "binary";
      mode = "0600";
    };

    systemd.user.services.sing-box = {
      Unit = {
        Description = "Per-machine WireGuard local proxy";
        Wants = [ "sops-nix.service" ];
        After = [ "sops-nix.service" ];
      };
      Service = {
        Type = "simple";
        RuntimeDirectory = "sing-box";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        ExecStartPre = "${lib.getExe generator} ${config.sops.secrets."sing-box-wireguard".path} %t/sing-box/config.json";
        ExecStart = "${cfg.package}/bin/sing-box run -c %t/sing-box/config.json";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
