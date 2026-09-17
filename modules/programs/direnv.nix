{ ... }:

{
  programs.direnv = {
    enable = true;

    # Replaces direnv's own `use nix` and `use flake` with implementations that
    # cache the evaluated environment and keep a GC root for it. Without the
    # cache, entering a project re-evaluates its flake every time; without the
    # root, a dev shell belongs to no profile, so `nix-collect-garbage` deletes
    # it and the next `cd` re-downloads the toolchain.
    nix-direnv.enable = true;
  };

  # Where nix-direnv keeps that cache and those roots: per project, and never
  # something to commit. Declared here rather than in the Git module because
  # direnv is the reason it exists.
  programs.git.ignores = [ ".direnv/" ];
}
