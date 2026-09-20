{ config, lib, pkgs, ... }:

{
  options.dotfiles.archive.root = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Archive";
    example = "/run/media/z/backup/Archive";
    description = "Where the archive command puts archives. Activation creates it, and the command is told about it through ARCHIVE_ROOT, so the two cannot disagree.";
  };

  options.dotfiles.repositories = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    example = { "Projects/example" = "https://github.com/owner/example.git"; };
    description = "Repository URLs keyed by paths under ~/Projects or ~/Documents. Existing paths are left untouched.";
  };

  config = {
    assertions = [ {
      assertion = lib.all
        (name:
          builtins.match "(Projects|Documents)/[^/]+" name != null
          && !(builtins.elem (builtins.baseNameOf name) [ "." ".." ]))
        (builtins.attrNames config.dotfiles.repositories);
      message = "dotfiles.repositories paths must name a directory directly under Projects or Documents.";
    } ];

    home.activation.userDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.coreutils}/bin/mkdir -p "$HOME/Projects" "$HOME/Documents" \
        "$HOME/Junk" "$HOME/Memos" \
        ${lib.escapeShellArg config.dotfiles.archive.root}
    '';

    home.activation.cloneRepositories = lib.hm.dag.entryAfter [ "userDirectories" "linkGeneration" ] (
      lib.concatStringsSep "\n" (lib.mapAttrsToList (name: url: ''
        project="$HOME/"${lib.escapeShellArg name}
        if [[ ! -e "$project" && ! -L "$project" ]]; then
          # Reuse the GitHub login established by secret recovery, including
          # private repositories, without changing global Git credentials.
          if ! run ${pkgs.coreutils}/bin/env GIT_TERMINAL_PROMPT=0 ${pkgs.git}/bin/git \
            -c credential.https://github.com.helper= \
            -c 'credential.https://github.com.helper=!${pkgs.gh}/bin/gh auth git-credential' \
            clone -- ${lib.escapeShellArg url} "$project"; then
            warnEcho "Could not clone $project; retry Home Manager activation after checking connectivity and authentication."
          fi
        fi
      '') config.dotfiles.repositories)
    );
  };
}
