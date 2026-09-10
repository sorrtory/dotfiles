# 03 — Local packages for the three scripts Nixpkgs lacks

Status: resolved
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

## Comments

Four local packages rather than three: `packages/mpv-fuzzydir.nix`,
`packages/mpv-show-filename.nix`, `packages/mpv-thumbfast-osc.nix`, and
`packages/mpv-reload-sibwaf.nix`. The fourth arrived from ticket 02, whose
`reload` row named a Nixpkgs attribute that is a different script; see that
ticket's comments. It builds from the same `sibwaf/mpv-scripts` source
`fuzzydir` already fetches, so it costs one file and no extra fetch.

`show_filename` packaged without trouble, so the ticket's permission to drop
it was not needed. Its upstream declares no licence at all, so `meta.license`
is deliberately left unset rather than guessed.

**The OSC question is answered, and the answer is that nothing in `mpv.conf`
changes.** The pinned commit's first two statements are
`mp.set_property("osc", "no")` followed by a check on `mp.get_script_name()`:
the script disables the builtin OSC itself, then reloads itself to reclaim the
`osc` script name once the builtin has unloaded. So neither `osc=no` in
`mpv.conf` nor any special load order is required, which is also why the
legacy setup never needed `osc=no`. The reclaim matches on a source path
ending in `osc.lua`; `buildLua` derives that name from `scriptPath`, so the
installed name is right. This is recorded in the package file so the next
reader does not re-derive it.

Host verification: all four derivations build, and the wrapper loads all eight
scripts from `/nix/store` with no Lua errors against the migrated config.

Outstanding: the two behavioral checks are inherently visual and need the VM —
subtitles auto-loading from a `subs/` subdirectory (proving `fuzzydir`
resolved `**`), a thumbnail on seek-bar hover, and the OSC not drawn twice.

### Follow-up: two local packages, not four

With the operator's go-ahead to take better versions, `reload` moved back to
Nixpkgs (see ticket 02) and `show_filename` was dropped outright. The latter
is worth stating plainly: the whole package existed to bind `Shift+ENTER` to
`show-text ${filename}` for 2000ms, which is one line of `input.conf` and now
is one. Packaging it meant a pinned fetch, a licence question with no answer
upstream, and a file to maintain, for something mpv does natively.

`fuzzydir` and `thumbfast-osc` remain local, both at upstream head — checked,
not assumed: `sibwaf/mpv-scripts` master is still `e4fb662` and thumbfast's
`vanilla-osc` branch is still `9d78edc`.

### Follow-up 2: one local package

The operator chose `uosc` over the vanilla-OSC fork, so
`packages/mpv-thumbfast-osc.nix` is deleted and `fuzzydir` is the only local
package left. uosc draws thumbfast previews natively and, like the fork, sets
`osc` to `no` itself — verified at runtime, the property reads `no` with uosc
loaded — so `mpv.conf` still needs no OSC line. Nixpkgs' uosc also supplies the
icon fonts and the `ziggy` helper through its wrapper arguments, which a local
package would have had to reproduce.

This ticket's original framing — three scripts Nixpkgs lacks — did not survive
contact: one was a one-line binding, one had a maintained Nixpkgs equivalent
under a different name, and one had a better Nixpkgs replacement outright.

## Answer

Resolved as one local package, `fuzzydir`, and it is verified behaviorally
rather than by inspection: on the activated VM, a clip beside a `subs/`
directory auto-loaded `subs/clip.srt` as an external subtitle track, which is
`sub-file-paths=**` being resolved by this script and by nothing else.

Thumbnail drawing moved to `uosc`, and thumbfast itself is confirmed working
end to end: prompted with the same `script-message-to thumbfast thumb` that
uosc sends on hover, it spawned its thumbnailer subprocess and wrote a
120000-byte BGRA buffer whose contents differ per requested timestamp. That
also exercises the environment fix the source override was taken for, since
the subprocess inherits the session environment it needs.
