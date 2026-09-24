{ config, lib, pkgs, ... }:

let
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
      # Keep the system `ls`; these opt-in views use eza's terminal icons.
      la = "eza -a --icons=auto --group-directories-first";
      ll = "eza -la --icons=auto --group-directories-first --git --header";
      lt = "eza --tree --level=2 --icons=auto --group-directories-first";
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

      # Explicit whole-host capture, supervised by host systemd. The root
      # process reads only the credential-free adapter configuration.
      "vpn-up" = ''
        local runtime=$XDG_RUNTIME_DIR/vpn-host
        if [[ -e /sys/class/net/vpn-host0 ]]; then
          print -u2 'vpn-up: already up'
          return 1
        fi
        mkdir -p -m 700 -- $runtime || return
        ${config.dotfiles.vpn.hostConfigCommand} $XDG_RUNTIME_DIR/sing-box/config.json $runtime/config.json || return
        sudo systemd-run --unit=vpn-host --collect --property=Type=exec \
          /usr/bin/env ${config.dotfiles.vpn.singBoxExecutable} run -c $runtime/config.json || return
        local tries=0
        until [[ -e /sys/class/net/vpn-host0 ]]; do
          if (( ++tries >= 50 )); then
            print -u2 'vpn-up: TUN did not start'
            sudo systemctl stop vpn-host.service
            return 1
          fi
          sleep 0.1
        done
      '';

      "vpn-down" = ''
        sudo systemctl stop vpn-host.service || return
        rm -f -- $XDG_RUNTIME_DIR/vpn-host/config.json
        rmdir -- $XDG_RUNTIME_DIR/vpn-host 2>/dev/null || true
      '';
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
