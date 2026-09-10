# Spec: MPV and Anime4K

Status: ready-for-agent

## Why

`docs/MIGRATION.md` §8 asks MPV to stop depending on manually cloned plugin
checkouts and absolute symlinks. Today nothing in this repository provides
MPV, its scripts, or its shaders. The live configuration is the legacy tree at
`~/Documents/configs/mpv/`, whose `scripts/` and `shaders/` entries are
symlinks into `~/.local/share/configs-manager/mpv/`, restored by the legacy
`manager.sh` from pins in `manager.lock`.

Every one of those symlinks is an absolute path into a directory no fresh
machine has. A fresh bootstrap today produces an MPV with no scripts and no
shaders, and the two native config files silently lose features.

## Scope

In scope:

- `modules/programs/mpv.nix` owning the MPV package and its script set.
- `configs/mpv/mpv.conf` and `configs/mpv/input.conf` as repository material,
  exposed through `mkOutOfStoreSymlink`.
- The five scripts obtainable from `pkgs.mpvScripts`.
- Local packages for the three scripts Nixpkgs does not carry.
- `pkgs.anime4k` and the `input.conf` shader bindings its layout forces to
  change.
- The `docs/SOFTWARE.md` and `docs/DECISIONS.md` statements this slice
  invalidates.

Out of scope:

- The legacy `~/Documents/configs/` repository, `manager.sh`, and
  `manager.lock`. The operator is retiring that repository wholesale by
  reinstalling the host; this slice neither edits nor removes it, and nothing
  is deleted from the current host.
- The video, audio, screenshot, and localization settings in `mpv.conf`.
  Those are behavior baseline: they migrate verbatim.
- `yt-dlp` integration, which already has its own bootstrap phase.

## Behavior baseline

The slice must preserve these, because they are selected behavior rather than
legacy accident:

1. `CTRL+1` through `CTRL+6` each select one Anime4K shader mode and
   `CTRL+0` clears all shaders, with the same on-screen labels.
2. `sub-file-paths=**` and `audio-file-paths=**` keep matching recursively.
   The `**` syntax is `fuzzydir`'s, not MPV's; without that script both lines
   silently stop working.
3. Hovering the seek bar shows a thumbnail preview. This needs both
   `thumbfast` and an OSC that draws its output.
4. `save-position-on-quit`, `autofit=50%`, the `[extension.gif]` profile, and
   the `alang`/`slang` ordering are unchanged.

## Definition of done

- `nix flake check` and `nix build .#homeConfigurations.z.activationPackage`
  succeed on the host.
- Every `tests/*.sh` passes.
- On the staging VM, a normal `bootstrap.sh install home-manager` produces an
  MPV whose `~/.config/mpv/scripts` and shader paths resolve entirely inside
  `/nix/store` and `~/Documents/dotfiles`, with no path under
  `~/.local/share/configs-manager/`.
- `mpv --version` and a normal-use check confirm the four baseline behaviors
  above.
- `docs/SOFTWARE.md` and `docs/DECISIONS.md` no longer describe Anime4K as a
  planned local package.
