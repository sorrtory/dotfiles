# 04 — Anime4K shaders and the input.conf bindings

Status: claimed
Blocked by: 01

## Goal

Source Anime4K from Nixpkgs and update the seven shader bindings its directory
layout invalidates.

## Work

1. Use `pkgs.anime4k` (4.0.1 in the pinned Nixpkgs). Do not write a local
   package for it.
2. Expose the shaders at a stable path MPV can reach. Prefer pointing
   `input.conf` at the store path over copying files into
   `~/.config/mpv/shaders/`.
3. Rewrite the seven bindings in `configs/mpv/input.conf` (`CTRL+1` to
   `CTRL+6`, and `CTRL+0`) for the new layout.

## Constraints

- **The layouts differ.** The legacy checkout nests shaders in `Restore/`,
  `Upscale/`, `Upscale+Denoise/`, `Deblur/`, `Denoise/` and
  `Experimental-Effects/`. `pkgs.anime4k` installs every `.glsl` **flat** in
  one directory. Every existing binding uses a nested path such as
  `~~/shaders/Anime4K/Restore/Anime4K_Restore_CNN_VL.glsl` and will fail to
  load unchanged.
- Do not build a derivation that re-nests the shaders to preserve the old
  paths. That invents a directory structure matching nothing upstream, for
  the sole benefit of not editing seven lines in a file this repository owns.
- These nine shader files are the ones actually bound, and all nine exist in
  4.0.1: `Anime4K_Clamp_Highlights`, `Anime4K_Restore_CNN_VL`,
  `Anime4K_Restore_CNN_Soft_VL`, `Anime4K_Restore_CNN_M`,
  `Anime4K_Restore_CNN_Soft_M`, `Anime4K_Upscale_CNN_x2_VL`,
  `Anime4K_Upscale_CNN_x2_M`, `Anime4K_Upscale_Denoise_CNN_x2_VL`,
  `Anime4K_AutoDownscalePre_x2`, `Anime4K_AutoDownscalePre_x4`.
- Keep each mode's `show-text` label exactly as it is. The labels are how the
  operator tells the modes apart.

## Acceptance

- After activation on the staging VM, pressing `CTRL+1` through `CTRL+6`
  during playback shows the matching `Anime4K: Mode ...` message and no
  shader load error appears in `mpv` output run with `--msg-level=all=info`.
- `CTRL+0` clears the shader list and shows `GLSL shaders cleared`.
- No path in `configs/mpv/input.conf` refers to a nested Anime4K directory.

## Comments

`pkgs.anime4k` 4.0.1 is exposed as
`xdg.configFile."mpv/shaders/Anime4K".source = pkgs.anime4k`, which symlinks
the whole store directory into the config tree rather than copying any file.
That keeps the ticket's preference — nothing is copied — while letting
`input.conf` keep using mpv's `~~/` config-directory prefix, which a bare store
path could not, since `input.conf` is repository material and must not carry a
store hash.

All ten bound shader files were confirmed present in 4.0.1 before editing. The
seven bindings now name the file directly under `~~/shaders/Anime4K/`; no
nested `Restore/`, `Upscale/`, or `Upscale+Denoise/` path remains, and every
`show-text` label is untouched.

Outstanding, and worth stating because it is not a small gap: **the shader
bindings have not been proven to load.** `--vo=null` never reaches shader
loading, so a deliberately wrong path exits exactly as cleanly as the right
one — the check has no discriminating power without a real render context.
Only playback on the VM, or on the host after approval, can confirm `CTRL+1`
through `CTRL+6`. That the files exist at the rewritten paths in the built
generation is necessary but not sufficient.
