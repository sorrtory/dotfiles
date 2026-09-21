{ config, lib, ... }:

let
  wireguardConfig = lib.escapeShellArg
    config.sops.secrets."wireguard/${config.dotfiles.vpn.identity}.conf".path;
in
{
  programs.zsh = {
    enable = true;

    # Debian-family /etc/zsh/zprofile does not source /etc/profile, so a Zsh
    # login shell never runs the multi-user Nix profile script and starts
    # without the user environment on PATH or NIX_PROFILES. The script guards
    # itself against repeated sourcing.
    profileExtra = ''
      if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi
    '';

    autosuggestion = {
      enable = true;
      highlight = "fg=244";
    };

    syntaxHighlighting.enable = true;

    history = {
      size = 50000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      expireDuplicatesFirst = true;
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    setOptions = [
      "COMPLETE_IN_WORD"
      "HIST_VERIFY"
      "INTERACTIVE_COMMENTS"
    ];

    oh-my-zsh = {
      enable = true;
      theme = "flazz";
      plugins = [
        "command-not-found"
        "copyfile"
        "copypath"
        "git"
      ];
      extraConfig = ''
        ENABLE_CORRECTION="false"
        COMPLETION_WAITING_DOTS="true"
      '';
    };

    shellAliases = {
      "p!" = "PAGER=less";
      path = "readlink -f";
      lg = "lazygit";
      lzd = "lazydocker";
      dps = ''docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}"'';
      dpss = ''docker ps --format "table {{.Names}}\t{{.Image}}\t{{.ID}}\t{{.RunningFor}}\t{{.Status}}\t{{.Size}}\t{{.Ports}}"'';
    };

    siteFunctions = {
      "proxy-on" = ''
        export http_proxy="http://127.0.0.1:3128"
        export https_proxy="http://127.0.0.1:3128"
        export all_proxy="socks5://127.0.0.1:1080"
        export no_proxy="127.0.0.1,localhost"
        export NO_PROXY="$no_proxy"
      '';

      "proxy-off" = ''
        unset http_proxy https_proxy all_proxy no_proxy NO_PROXY
      '';

      # Whole-host WireGuard on this machine's VPN identity. sudo cannot
      # resolve a bare name from the Nix profile, and wg-quick wants the config
      # path because the configuration does not live in /etc/wireguard; it
      # names the interface after the file. The sing-box backend uses the same
      # identity, and two clients on one peer key make the server's endpoint
      # roam, so the backend hands it over rather than stopping: the marker
      # restarts it keyless, bound to the interface, so the local proxy and
      # tunneled programs keep working through the whole-host tunnel and fail
      # closed without it. The backend lets go before wg-quick claims the key
      # and takes it back only after the interface is gone.
      "vpn-up" = ''
        local interface=${config.dotfiles.vpn.identity} marker=$XDG_RUNTIME_DIR/whole-host-vpn
        if [[ -e /sys/class/net/$interface ]]; then
          print -u2 "vpn-up: $interface is already up"
          return 1
        fi
        sudo -v || return
        print -r -- $interface >| $marker
        if ! systemctl --user try-restart sing-box.service ||
          ! sudo "$(command -v wg-quick)" up ${wireguardConfig}; then
          if [[ ! -e /sys/class/net/$interface ]]; then
            rm -f -- $marker
            systemctl --user try-restart sing-box.service
          fi
          return 1
        fi
      '';

      "vpn-down" = ''
        local interface=${config.dotfiles.vpn.identity}
        if [[ -e /sys/class/net/$interface ]]; then
          sudo "$(command -v wg-quick)" down ${wireguardConfig} || return
        fi
        rm -f -- $XDG_RUNTIME_DIR/whole-host-vpn
        systemctl --user try-restart sing-box.service
      '';
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
