{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.localProxy;
  # One spelling of the endpoint, shared by the wrappers below and by $PROXY.
  proxyUrl = "http://127.0.0.1:3128";
  proxyProgram = program: pkgs.writeShellScriptBin program.name ''
    export HTTP_PROXY="${proxyUrl}"
    export HTTPS_PROXY="$HTTP_PROXY"
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTP_PROXY"
    export NO_PROXY="127.0.0.1,localhost"
    export no_proxy="$NO_PROXY"
    exec ${lib.getExe' program.package program.executable} "$@"
  '';
  generator = pkgs.writeShellApplication {
    name = "sing-box-config";
    runtimeInputs = [ pkgs.coreutils pkgs.jq cfg.package ];
    text = builtins.readFile ./generate-config.sh;
  };
  prepare = pkgs.writeShellScript "sing-box-prepare" ''
    exec ${lib.getExe generator} ${lib.optionalString (!cfg.ipv6.enable) "--no-ipv6"} \
      ${config.sops.secrets."sing-box-wireguard".path} "$1/sing-box/config.json"
  '';
in
{
  options.dotfiles.localProxy = {
    enable = lib.mkEnableOption "the per-machine sing-box local proxy";
    package = lib.mkPackageOption pkgs "sing-box" { };
    # A property of the VPN server, not of one identity: every profile keeps
    # its IPv6 address and route, so turning this on needs no secret edit.
    ipv6.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Use IPv6 through the tunnel. Off, names resolve to IPv4 only, IPv6
        destinations are refused at once instead of timing out, and tunneled
        programs get no IPv6 address. IPv6 still never leaves outside the
        tunnel either way.
      '';
    };
    wrappedPrograms = lib.mkOption {
      default = [ ];
      description = ''
        Commands that always use the local HTTP proxy. Their child processes
        inherit the proxy environment too.
      '';
      type = lib.types.listOf (lib.types.submodule ({ config, ... }: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Command name exposed in the user profile.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            description = "Package containing the command to wrap.";
          };
          executable = lib.mkOption {
            type = lib.types.str;
            default = config.name;
            description = "Executable name inside the package's bin directory.";
          };
        };
      }));
    };
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
    home.packages = [ cfg.package ] ++ map proxyProgram cfg.wrappedPrograms;

    # For programs that take a proxy argument instead of needing to be wrapped:
    # `yt-dlp --proxy "$PROXY"`. Naming the endpoint once means an alias cannot
    # drift from the service it is meant to reach.
    home.sessionVariables.PROXY = proxyUrl;

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
        ExecStartPre = "${prepare} %t";
        ExecStart = "${cfg.package}/bin/sing-box run -c %t/sing-box/config.json";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
