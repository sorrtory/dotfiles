{ config, lib, pkgs, ... }:

let
  proxy = config.dotfiles.localProxy;

  captureConfig = pkgs.writeShellApplication {
    name = "vpn-capture-config";
    runtimeInputs = [ pkgs.coreutils pkgs.jq proxy.package ];
    text = builtins.readFile ./capture-config.sh;
  };
  hostConfig = pkgs.writeShellApplication {
    name = "vpn-host-config";
    runtimeInputs = [ pkgs.coreutils pkgs.jq proxy.package ];
    text = builtins.readFile ./whole-host-config.sh;
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
  options.dotfiles.vpn.command = lib.mkOption {
    type = lib.types.path;
    readOnly = true;
    default = lib.getExe vpn;
    description = "The shared VPN launcher path used by installed applications.";
  };

  options.dotfiles.vpn.hostConfigCommand = lib.mkOption {
    type = lib.types.path;
    readOnly = true;
    default = lib.getExe hostConfig;
    description = "Build the credential-free whole-host TUN configuration.";
  };
  options.dotfiles.vpn.singBoxExecutable = lib.mkOption {
    type = lib.types.path;
    readOnly = true;
    default = lib.getExe proxy.package;
    description = "sing-box executable used by the whole-host TUN.";
  };

  config = lib.mkIf proxy.enable {
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
  };
}
