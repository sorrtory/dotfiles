{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.localProxy;
  generator = pkgs.writeShellApplication {
    name = "sing-box-config";
    runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.sing-box ];
    text = builtins.readFile ../../scripts/bin/sing-box-config.sh;
  };
in
{
  options.dotfiles.localProxy = {
    enable = lib.mkEnableOption "the per-machine sing-box local proxy";
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
    home.packages = [ pkgs.sing-box generator ];

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
        ExecStart = "${pkgs.sing-box}/bin/sing-box run -c %t/sing-box/config.json";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
