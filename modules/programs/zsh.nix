{ config, lib, pkgs, ... }:

let
  wireguardConfig = lib.escapeShellArg
    config.sops.secrets."wireguard/${config.dotfiles.vpn.identity}.conf".path;
  themeFile = "${config.dotfiles.theme.dataDir}/zsh.zsh";
  zshCustom = "${config.xdg.dataHome}/dotfiles/zsh-custom";
in
{
  # The prompt, the highlighting and the completion listing come from the
  # palette, generated into one file rather than written into .zshrc: a shell
  # reads .zshrc once, so a switch would otherwise reach only the shells
  # opened after it. The file is re-sourced from precmd when it changed,
  # which is the same contract WezTerm and Sublime register as "live".
  dotfiles.theme.liveFiles."${themeFile}" =
    pkgs.writeText "zsh-theme.zsh"
      (import ../theme/zsh-colors.nix { inherit lib; }
        (config.dotfiles.theme.forApp "zsh"));
  dotfiles.theme.apps.zsh = {
    label = "Zsh";
    apply = "live";
  };

  # oh-my-zsh loads the colors the way it loads any theme, as $ZSH_THEME. The
  # theme it finds is one line long because the colors cannot live here: this
  # file is a symlink into the store, and every file in the store carries the
  # same epoch mtime, which is the one thing the reload hook watches. The
  # generated colors stay in the live file, and this points at them.
  #
  # The guard is for a shell started before the first activation, when there
  # is nothing to read yet: without it zsh reports the missing file on every
  # prompt of a fresh machine. It is an `if` rather than `&&` so that the
  # theme returns 0 either way — a theme is the last thing .zshrc runs before
  # the first prompt, and a non-zero status there is what RPS1 draws as a
  # failed command.
  xdg.dataFile."dotfiles/zsh-custom/themes/dotfiles.zsh-theme".text = ''
    if [[ -r ${themeFile} ]]; then
      source ${themeFile}
    fi
  '';

  programs.zsh = {
    enable = true;

    # zsh/stat rather than a stamp file: the mtime the activation copy leaves
    # behind is the whole of the state this needs. The hook goes in front of
    # the ones already registered so the colors are in place before oh-my-zsh
    # asks git for the branch it is about to draw.
    #
    # The load here reads a file the theme already sourced a moment ago, and
    # that is deliberate: it is what records the mtime the hook compares
    # against, and without it the first prompt would re-read the file anyway.
    # The file only assigns, so reading it twice costs a few microseconds and
    # changes nothing. It is also the path that still reaches a prompt in a
    # shell where oh-my-zsh never ran and no theme was ever loaded.
    initContent = ''
      typeset -g _dotfiles_theme_file=${lib.escapeShellArg themeFile}
      typeset -g _dotfiles_theme_mtime=
      zmodload -F zsh/stat b:zstat
      _dotfiles_theme_load() {
        local -a entry
        zstat -A entry +mtime -- $_dotfiles_theme_file 2>/dev/null || return 0
        [[ $entry[1] == $_dotfiles_theme_mtime ]] && return 0
        _dotfiles_theme_mtime=$entry[1]
        source $_dotfiles_theme_file
      }
      _dotfiles_theme_load
      precmd_functions=(_dotfiles_theme_load $precmd_functions)
    '';

    # Debian-family /etc/zsh/zprofile does not source /etc/profile, so a Zsh
    # login shell never runs the multi-user Nix profile script and starts
    # without the user environment on PATH or NIX_PROFILES. The script guards
    # itself against repeated sourcing.
    profileExtra = ''
      if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi
    '';

    # The suggestion's color is the theme's, set in the generated file with
    # every other color, so `highlight` stays unset here.
    autosuggestion.enable = true;

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
      # "dotfiles" rather than one of the bundled themes: every one of those
      # writes its own PROMPT out of the terminal's eight named colors, which
      # no palette here controls. This one is generated from the roles and
      # keeps flazz's layout, which is what it replaced.
      enable = true;
      custom = zshCustom;
      theme = "dotfiles";
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
