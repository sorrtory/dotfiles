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
    name = "vpn-inventory-config";
    runtimeInputs = [ pkgs.python3 cfg.package ];
    text = ''
      exec ${lib.getExe pkgs.python3} ${./compile-inventory.py} "$@"
    '';
  };
  egressControl = pkgs.writeShellApplication {
    name = "vpn-egress";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec ${lib.getExe pkgs.python3} ${./vpn-egress.py} "$@"
    '';
  };
  prepare = pkgs.writeShellScript "sing-box-prepare" ''
    exec ${lib.getExe generator} --apps ${config.dotfiles.vpn.appRegistry} --concurrent --bindings "$1/vpn-listeners.json" \
      ${config.sops.secrets."vpn-egresses".path} \
      ${config.sops.secrets."vpn-policy".path} \
      "$1/sing-box/config.json"
  '';
in
{
  options.dotfiles.localProxy = {
    enable = lib.mkEnableOption "the per-machine sing-box local proxy";
    package = lib.mkPackageOption pkgs "sing-box" { };
    # Retained during migration; the selectable default is always IPv4-only.
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

  options.dotfiles.vpn.egressControlPackage = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    default = egressControl;
    description = "Runtime selector and app-pin resolver for VPN launchers.";
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = !cfg.ipv6.enable;
      message = "dotfiles.localProxy.ipv6.enable is obsolete: default VPN routes are IPv4-only.";
    }];
    home.packages = [ cfg.package egressControl ] ++ map proxyProgram cfg.wrappedPrograms;

    # For programs that take a proxy argument instead of needing to be wrapped:
    # `yt-dlp --proxy "$PROXY"`. Naming the endpoint once means an alias cannot
    # drift from the service it is meant to reach.
    home.sessionVariables.PROXY = proxyUrl;

    sops.secrets."vpn-egresses" = {
      sopsFile = ../../../secrets/vpn/egresses.jsonc;
      format = "binary";
      mode = "0600";
    };
    sops.secrets."vpn-policy" = {
      sopsFile = ../../../secrets/vpn/policy.jsonc;
      format = "binary";
      mode = "0600";
    };

    systemd.user.services.sing-box = {
      Unit = {
        Description = "Selected VPN egress backend and local proxy";
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
