{ lib, ... }:

{
  programs.git = {
    enable = true;

    # Nix-ified rather than kept native: the file is eleven lines, the operator
    # does not edit it in place, and `git config --global` writing back into a
    # store symlink would fail. The tmux/Yazi live-editable argument does not
    # apply here.
    settings = {
      user = {
        name = "sorrtory";
        email = "62436169+sorrtory@users.noreply.github.com";
      };

      # zdiff3 keeps the merge base visible alongside both sides, which is what
      # makes a conflict readable without re-deriving what the original said.
      merge.conflictStyle = "zdiff3";
    };
  };

  # The legacy ~/.gitconfig carried this commented out; it was intent that was
  # never finished wiring up, so it is enabled rather than dropped.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options.navigate = true;
  };

  # Git ignores ~/.config/git/config entirely while ~/.gitconfig exists — not
  # per key, the whole file, as `git config --list --show-origin` confirms.
  # Home Manager writes the XDG path, so leaving the legacy file in place would
  # make everything above silently inert. Moved aside rather than deleted, and
  # only when it is a real file, so an already-migrated home is left alone.
  home.activation.retireLegacyGitconfig =
    lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      if [[ -f "$HOME/.gitconfig" && ! -L "$HOME/.gitconfig" ]]; then
        run mv $VERBOSE_ARG "$HOME/.gitconfig" "$HOME/.gitconfig.pre-home-manager"
        warnEcho "Moved ~/.gitconfig to ~/.gitconfig.pre-home-manager; it would have shadowed ~/.config/git/config."
      fi
    '';
}
