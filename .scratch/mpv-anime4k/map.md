# MPV and Anime4K

Give this repository an MPV that works on a fresh machine: native config it
owns, scripts from Nixpkgs where they exist and local packages where they do
not, and Anime4K shaders from `pkgs.anime4k`. See [spec.md](spec.md) for the
behavior baseline the legacy symlinks currently provide.

## Tickets

- [01: MPV module and native configuration](issues/01-mpv-module-and-native-config.md) — ready-for-agent.
- [02: Scripts available from Nixpkgs](issues/02-nixpkgs-scripts.md) — ready-for-agent; blocked by 01.
- [03: Local packages for the three scripts Nixpkgs lacks](issues/03-local-script-packages.md) — ready-for-agent; blocked by 01.
- [04: Anime4K shaders and the input.conf bindings](issues/04-anime4k-shaders.md) — ready-for-agent; blocked by 01.
- [05: Documentation corrections](issues/05-documentation.md) — ready-for-agent; blocked by 02, 03, 04.

## Context

- `docs/MIGRATION.md` §8.
- Every legacy `scripts/` and `shaders/` entry is an absolute symlink into
  `~/.local/share/configs-manager/`, which no fresh machine has. A fresh
  bootstrap today yields an MPV with no scripts and no shaders.
- `docs/DECISIONS.md` still expects Anime4K to become a pinned local package.
  Nixpkgs carries `anime4k` 4.0.1, so working rule 3 applies and ticket 05
  corrects the decision log.
- The Nixpkgs package lays shaders flat; the legacy checkout nests them. All
  seven `input.conf` shader bindings change as a result — ticket 04.
- Two of the three local packages are load-bearing rather than optional:
  `fuzzydir` provides the `**` syntax `mpv.conf` depends on, and
  `thumbfast-osc` is what draws thumbfast's previews.
