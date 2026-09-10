# MPV and Anime4K

Give this repository an MPV that works on a fresh machine: native config it
owns, scripts from Nixpkgs where they exist and local packages where they do
not, and Anime4K shaders from `pkgs.anime4k`. See [spec.md](spec.md) for the
behavior baseline the legacy symlinks currently provide.

## Tickets

- [01: MPV module and native configuration](issues/01-mpv-module-and-native-config.md) — claimed; implemented and verified on the host.
- [02: Scripts available from Nixpkgs](issues/02-nixpkgs-scripts.md) — claimed; four of five as specified, `reload` moved to 03.
- [03: Local packages for the scripts Nixpkgs lacks](issues/03-local-script-packages.md) — claimed; four packages, all building.
- [04: Anime4K shaders and the input.conf bindings](issues/04-anime4k-shaders.md) — claimed; bindings rewritten, loading unproven.
- [05: Documentation corrections](issues/05-documentation.md) — claimed; the three documents now describe what shipped.

All five are held at `claimed` rather than `resolved` because every ticket's
acceptance ends on the staging VM, and the VM step has not run.

## Context

- `docs/MIGRATION.md` §8.
- Every legacy `scripts/` and `shaders/` entry is an absolute symlink into
  `~/.local/share/configs-manager/`, which no fresh machine has. A fresh
  bootstrap today yields an MPV with no scripts and no shaders.
- `docs/DECISIONS.md` expected Anime4K to become a pinned local package.
  Nixpkgs carries `anime4k` 4.0.1, so working rule 3 applied and ticket 05
  has corrected the decision log.
- The Nixpkgs package lays shaders flat; the legacy checkout nests them. All
  seven `input.conf` shader bindings change as a result — ticket 04.
- Two of the four local packages are load-bearing rather than optional:
  `fuzzydir` provides the `**` syntax `mpv.conf` depends on, and
  `thumbfast-osc` is what draws thumbfast's previews.

## What the host proved, and what it cannot

Host-side, everything builds and every gate is green: `nix flake check`, the
activation package, all `tests/*.sh`, and both staged-change gates. The
`mpv-with-scripts` wrapper loads all eight scripts from `/nix/store`, and the
migrated config parses without error.

Three things are still unproven, and two of them are the point of the slice:

1. **Shader loading.** `--vo=null` never reaches shader compilation, so a
   deliberately wrong path passes the same check as a correct one. `CTRL+1`
   through `CTRL+6` need real playback.
2. **The two visual behaviors** — thumbnails on seek-bar hover and a
   single OSC — need a display.
3. **A real activation**, which is what would show whether anything still
   points into `~/.local/share/configs-manager/`.

The `rsync` to the staging VM was denied by the sandbox in the session that
did this work, so all three wait on that step.

## Deviations from the tickets

- Ticket 02's `reload` row named `mpvScripts.reload`, which is a different
  script by a different author with a different key binding. It is now a local
  package, and the operator can still choose the Nixpkgs one instead.
- `mpv-cut` is unfree in Nixpkgs, so `flake.nix` names it in
  `allowUnfreePredicate`.
- Ticket 03's OSC question resolved to "no `mpv.conf` change": the fork
  disables the builtin OSC itself.
