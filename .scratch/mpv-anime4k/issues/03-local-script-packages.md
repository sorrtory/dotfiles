# 03 — Local packages for the three scripts Nixpkgs lacks

Status: ready-for-agent
Blocked by: 01

## Goal

Package the three remaining legacy scripts locally, because two of them carry
behavior the retained `mpv.conf` and `input.conf` depend on.

## Work

Create one derivation per script under `packages/`, each using
`mpvScripts.buildLua` with `fetchFromGitHub` at the pin the legacy
`manager.lock` already recorded:

1. `fuzzydir` — `sibwaf/mpv-scripts` @
   `e4fb662207e024f26d7763c9551e429898267974`, file `fuzzydir.lua`.
2. `show_filename` — `yuukidach/mpv-scripts` @
   `85cc0cfb101718aea1c7debeec61a6f851852f0f`, file `show_filename.lua`.
3. `thumbfast-osc` — `po5/thumbfast` @
   `9d78edc167553ccea6290832982d0bc15838b4ac`, file `player/lua/osc.lua`.

Add all three to `programs.mpv.scripts`.

## Constraints

- These are not optional extras. Two of them are load-bearing:
  - `mpv.conf` sets `sub-file-paths=**` and `audio-file-paths=**`. The `**`
    recursive syntax is provided by `fuzzydir`, not by MPV. Without it those
    two lines match nothing and subtitle/audio auto-loading silently breaks.
  - `thumbfast-osc` is a fork of MPV's built-in OSC that renders thumbfast's
    previews. Without it `mpvScripts.thumbfast` from ticket 02 loads and runs
    but draws nothing, which looks like thumbfast being broken.
- `thumbfast-osc` replaces the built-in OSC. It must be loaded as `osc.lua`
  and MPV's own OSC disabled, or both will draw. Verify which of
  `osc=no` plus a script load, or the upstream README's documented method,
  is correct for the pinned commit rather than assuming.
- `show_filename` is cosmetic. If it resists packaging, say so and drop it
  rather than blocking the slice; the other two must land.

## Acceptance

- `nix build` succeeds for each of the three derivations individually.
- After activation on the staging VM:
  - a video in a directory with a separate `subs/` subdirectory auto-loads
    its subtitles, proving `fuzzydir` resolved `**`;
  - hovering the seek bar shows a thumbnail, proving thumbfast and its OSC
    are cooperating;
  - the OSC is not drawn twice.
