{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.localProxy;
  generator = pkgs.writeShellApplication {
    name = "sing-box-config";
    runtimeInputs = [ pkgs.coreutils pkgs.jq cfg.package ];
    text = builtins.readFile ../../scripts/bin/sing-box-config.sh;
  };
in
{
  options.dotfiles.localProxy = {
    enable = lib.mkEnableOption "the per-machine sing-box local proxy";
    package = lib.mkPackageOption pkgs "sing-box" { };
    profile = lib.mkOption {
      type = lib.types.enum [ "laptop" "desktop-ubuntu" "desktop-old" "desktop-win" "phone" ];
      default = "laptop";
      description = ''
        This machine's exclusive WireGuard peer identity. Never run another
        WireGuard client with the same identity concurrently.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package generator ];

    sops.secrets."sing-box-wireguard" = {
      sopsFile = ../../secrets/wireguard + "/${cfg.profile}.conf";
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
        ExecStartPre = "${generator}/bin/sing-box-config ${config.sops.secrets."sing-box-wireguard".path} %t/sing-box/config.json";
        ExecStart = "${cfg.package}/bin/sing-box run -c %t/sing-box/config.json";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
