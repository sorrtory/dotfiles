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
      VPN_OD = lib.getExe' pkgs.coreutils "od";
      VPN_TR = lib.getExe' pkgs.coreutils "tr";
      VPN_JQ = lib.getExe pkgs.jq;
      VPN_EGRESS_COMMAND = lib.getExe config.dotfiles.vpn.egressControlPackage;
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

      # Validate incoming ciphertext before changing live scopes, then stop
      # only scopes affected by a pin or named route change.
      home.activation.stopNamedVpnScopes = lib.hm.dag.entryBefore [ "onFilesChange" ] ''
        # Validate the incoming encrypted inventory before touching live
        # scopes. sops-nix rotates runtime secrets later in activation, so
        # decrypt the new ciphertext privately for this preflight.
        (
          umask 077
          validation=$(${lib.getExe' pkgs.coreutils "mktemp"} -d "$XDG_RUNTIME_DIR/vpn-validate.XXXXXXXX") || exit 1
          trap '${lib.getExe' pkgs.coreutils "rm"} -rf -- "$validation"' EXIT
          if [ -f "$XDG_RUNTIME_DIR/vpn-listeners.json" ]; then
            ${lib.getExe' pkgs.coreutils "cp"} -- "$XDG_RUNTIME_DIR/vpn-listeners.json" "$validation/vpn-listeners.json" || exit 1
          fi
          SOPS_AGE_KEY_FILE=${lib.escapeShellArg config.sops.age.keyFile} \
            ${lib.getExe pkgs.sops} decrypt ${config.sops.secrets."vpn-egresses".sopsFile} > "$validation/egresses" 2>/dev/null || exit 1
          SOPS_AGE_KEY_FILE=${lib.escapeShellArg config.sops.age.keyFile} \
            ${lib.getExe pkgs.sops} decrypt ${config.sops.secrets."vpn-policy".sopsFile} > "$validation/policy" 2>/dev/null || exit 1
          PATH=${lib.makeBinPath [ proxy.package ]}:$PATH \
            ${lib.getExe pkgs.python3} ${../sing-box/compile-inventory.py} \
              --concurrent --bindings "$validation/vpn-listeners.json" \
              "$validation/egresses" "$validation/policy" "$validation/config.json" || {
                echo 'VPN inventory validation failed; live scopes kept' >&2
                exit 1
              }
          ${lib.getExe pkgs.python3} ${./reconcile.py} \
            "$XDG_RUNTIME_DIR/sing-box/config.json" "$validation/config.json" \
            "$XDG_RUNTIME_DIR/vpn-control.json" "$validation/vpn-control.json" || {
              echo 'VPN scope reconciliation failed; service update held' >&2
              exit 1
            }
        ) || exit 1
      '';

      # A ciphertext-only policy edit need not change the sing-box unit file,
      # so Home Manager's service reload alone can leave the old selection
      # running. sops-nix has materialized the new files at this point.
      home.activation.reloadVpnInventory = lib.hm.dag.entryAfter [ "sops-nix" ] ''
        ${lib.getExe' pkgs.systemd "systemctl"} --user restart sing-box.service
      '';

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
      systemd.user.services."vpn-capture@" = {
        Unit = {
          Description = "On-demand named VPN capture for %I";
          Wants = [ "sing-box.service" ];
          After = [ "sing-box.service" ];
          StopWhenUnneeded = true;
          StartLimitIntervalSec = 0;
        };
        Service = {
          Type = "simple";
          RuntimeDirectory = "vpn-capture-%i";
          RuntimeDirectoryMode = "0700";
          UMask = "0077";
          ExecStartPre = "${lib.getExe captureConfig} %t/sing-box/config.json %t/vpn-capture-%i %I";
          ExecStart = "${lib.getExe proxy.package} run -c %t/vpn-capture-%i/config.json";
          NoNewPrivileges = true;
          Restart = "no";
        };
      };
  };
}
