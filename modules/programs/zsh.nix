{ config, ... }:

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
      dps = ''docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}"'';
      dpss = ''docker ps --format "table {{.Names}}\t{{.Image}}\t{{.ID}}\t{{.RunningFor}}\t{{.Status}}\t{{.Size}}\t{{.Ports}}"'';

      # sudo cannot resolve a bare name from the Nix profile, and wg-quick
      # wants the config path rather than an interface name because the
      # configuration does not live in /etc/wireguard. Both are easy to get
      # wrong by hand; neither needs an argument, since this machine decrypts
      # one device configuration.
      vpn-up = ''sudo "$(command -v wg-quick)" up "$HOME/.config/sops-nix/secrets/wireguard/wg0.conf"'';
      vpn-down = ''sudo "$(command -v wg-quick)" down "$HOME/.config/sops-nix/secrets/wireguard/wg0.conf"'';
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
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
