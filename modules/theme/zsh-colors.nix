{ lib }:

# Zsh's side of the theme: the prompt, zsh-syntax-highlighting's styles, the
# autosuggestion's ghost text and the completion listing, written in the
# palette's own hexes rather than the terminal's sixteen. WezTerm already
# takes its ANSI colors from this palette, so a prompt written in color names
# would follow the theme there and nowhere else; `%F{#rrggbb}`, which zsh 5.7
# and later understand, follows it in any terminal that can draw it.
#
# The prompt is flazz's layout — the oh-my-zsh theme this replaced — in roles
# instead of the eight named colors flazz reaches for: host and separator
# recede, the path is where the eye lands, the branch carries the second
# accent, the caret is the accent and `error` for root.
#
# The dirty marker is `error` rather than `warning` because it has to read
# against the brackets around it, and `warning` is not guaranteed to: a
# palette is free to make its warning the second accent, and autumn-leaves
# does — both are the same copper, which left the marker the color of the
# brackets it sits between. `error` is the one role no palette can collapse
# into the second accent, and red for a dirty tree is the convention besides.
#
# modules/programs/zsh.nix writes this out as a live file and re-sources it
# from precmd, so a switch recolors shells that are already open. oh-my-zsh
# loads it as $ZSH_THEME=dotfiles, through a one-line theme that sources it:
# the theme itself is a store symlink and could not carry an mtime that
# changes, which is what the reload watches.

colors:
let
  inherit (colors) text subtext muted accent accent2 error warning success info;
  inherit (colors) brightBlack brightMagenta brightCyan;

  inherit (import ./color.nix { inherit lib; }) channels;

  # The completion listing is the one place zsh takes a raw SGR sequence
  # rather than a color name: `list-colors` is LS_COLORS syntax.
  sgr = hex: "38;2;" + lib.concatMapStringsSep ";" toString (channels hex);

  style = name: value:
    "ZSH_HIGHLIGHT_STYLES[${name}]=${lib.escapeShellArg value}";
  fg = hex: name: style name "fg=${hex}";

  # Grouped rather than sorted, because what a reader checks is that the
  # whole of one kind of token got one color, not that a name is present.
  highlighting = lib.concatStringsSep "\n" (
    # Plain text, and the token zsh could not make sense of.
    [
      (style "default" "fg=${text}")
      (style "unknown-token" "fg=${error},bold")
      (style "comment" "fg=${muted}")
    ]
    # What runs: anything resolvable is `success`, and `precommand` — sudo,
    # env, nohup — underlines because it governs the word after it.
    ++ map (fg success) [ "arg0" "command" "builtin" "function" "alias" "hashed-command" ]
    ++ [
      (style "precommand" "fg=${success},underline")
      (style "suffix-alias" "fg=${success},underline")
      (style "global-alias" "fg=${brightCyan}")
      (style "reserved-word" "fg=${warning}")
      (style "commandseparator" "fg=${muted}")
    ]
    # Paths, with the separators dropped back so the components read.
    ++ [
      (style "path" "fg=${accent2},underline")
      (style "path_prefix" "fg=${accent2}")
      (style "autodirectory" "fg=${accent2},underline")
    ]
    ++ map (fg muted) [ "path_pathseparator" "path_prefix_pathseparator" ]
    # Quoting: a quoted string is `success`, and what escapes the quoting to
    # be evaluated — `$var`, a backslash — is `info`, so it stands out inside
    # one. The delimiters of a substitution take the accent for the same
    # reason: they are the part that is not text.
    ++ map (fg success) [ "single-quoted-argument" "double-quoted-argument" "dollar-quoted-argument" ]
    ++ map (fg info) [
      "dollar-double-quoted-argument"
      "back-double-quoted-argument"
      "back-dollar-quoted-argument"
      "rc-quote"
    ]
    ++ map (fg text) [ "command-substitution" "process-substitution" "back-quoted-argument" ]
    ++ map (fg accent) [
      "command-substitution-delimiter"
      "process-substitution-delimiter"
      "back-quoted-argument-delimiter"
    ]
    # Everything the shell itself acts on: globs, history, redirection.
    ++ [
      (style "globbing" "fg=${accent}")
      (style "history-expansion" "fg=${brightMagenta}")
      (style "redirection" "fg=${accent}")
      (style "assign" "fg=${accent2}")
    ]
    ++ map (fg text) [ "named-fd" "numeric-fd" ]
    ++ map (fg subtext) [ "single-hyphen-option" "double-hyphen-option" ]
  );

  # The file types `ls` names, so a completion listing separates a directory
  # from a program the way the terminal's own listing does. An entry zsh has
  # no color for is drawn in the terminal's foreground, which is this
  # palette's `text` already.
  listColors = lib.mapAttrsToList (key: hex: lib.escapeShellArg "${key}=${sgr hex}") {
    di = accent2;
    ln = brightCyan;
    ex = success;
    pi = warning;
    so = brightMagenta;
    bd = warning;
    cd = warning;
    or = error;
  };
in
''
  # Generated from the palette by modules/theme/zsh-colors.nix. Editing it is
  # pointless: the next `home-manager switch` writes over this same file, and
  # every open shell re-reads it at its next prompt.

  setopt PROMPT_SUBST

  # Prompt. `git_prompt_info` comes from oh-my-zsh's lib; the stub keeps the
  # prompt printable in a shell that never loaded it.
  (( $+functions[git_prompt_info] )) || git_prompt_info() { }

  ZSH_THEME_GIT_PROMPT_PREFIX=${lib.escapeShellArg "%F{${accent2}}‹"}
  ZSH_THEME_GIT_PROMPT_SUFFIX=${lib.escapeShellArg "%F{${accent2}}› %f"}
  ZSH_THEME_GIT_PROMPT_DIRTY=${lib.escapeShellArg "%F{${error}}*"}
  ZSH_THEME_GIT_PROMPT_CLEAN=""

  PROMPT=${lib.escapeShellArg (
    "%F{${subtext}}%m %F{${muted}}::%f "
    + "%F{${success}}%3~%f "
    + "$(git_prompt_info)"
    + "%(!.%F{${error}}.%F{${accent}})%#%f ")}
  # Only a failing command says anything on the right.
  RPS1=${lib.escapeShellArg "%(?..%F{${error}}%? ↵%f)"}

  # The suggestion ahead of the cursor has to sit below a comment in weight,
  # not just below plain text, or it reads as something already typed. That
  # is what the palette's dim gray is, in every theme.
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=${lib.escapeShellArg "fg=${brightBlack}"}

  # zsh-syntax-highlighting loads after this file on a fresh shell and takes
  # the array as it finds it, filling in only the styles nobody set. The
  # declaration is here because a subscript assignment to a name that does
  # not exist yet would make an ordinary array, not an associative one.
  typeset -gA ZSH_HIGHLIGHT_STYLES
  ${highlighting}

  zstyle ':completion:*' list-colors ${lib.concatStringsSep " " listColors}
  zstyle ':completion:*:descriptions' format ${lib.escapeShellArg "%F{${accent}}%B%d%b%f"}
  zstyle ':completion:*:messages' format ${lib.escapeShellArg "%F{${info}}%d%f"}
  zstyle ':completion:*:corrections' format ${lib.escapeShellArg "%F{${warning}}%d (errors: %e)%f"}
  zstyle ':completion:*:warnings' format ${lib.escapeShellArg "%F{${error}}no matches for %d%f"}
''
