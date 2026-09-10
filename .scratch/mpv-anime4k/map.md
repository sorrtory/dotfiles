# MPV and Anime4K

Give this repository an MPV that works on a fresh machine: native config it
owns, scripts from Nixpkgs where they exist and local packages where they do
not, and Anime4K shaders from `pkgs.anime4k`. See [spec.md](spec.md) for the
behavior baseline the legacy symlinks currently provide.

## Tickets

- [01: MPV module and native configuration](issues/01-mpv-module-and-native-config.md) — resolved.
- [02: Scripts available from Nixpkgs](issues/02-nixpkgs-scripts.md) — resolved; `reload` came from Nixpkgs after the version review.
- [03: Local packages for the scripts Nixpkgs lacks](issues/03-local-script-packages.md) — resolved; one local package, `fuzzydir`.
- [04: Anime4K shaders and the input.conf bindings](issues/04-anime4k-shaders.md) — resolved; all six modes compile on the GPU path.
- [05: Documentation corrections](issues/05-documentation.md) — resolved.
- [06: GPU driver integration for a non-NixOS host](issues/06-gpu-driver-integration.md) — claimed; drivers verified, the privileged symlink step still unrun.

Tickets 01 to 05 are resolved against the staging VM. Ticket 06 came out of
that verification and is the only thing between this slice and completion.

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
- Only `fuzzydir` ended up local, and it is load-bearing: `mpv.conf` depends
  on the `**` syntax it provides. Thumbnail drawing moved to `uosc`.

## Verified on the staging VM

A normal `bootstrap.sh install home-manager` activated cleanly, and on that
activation:

- `~/.config/mpv/{mpv,input}.conf` resolve to `~/Documents/dotfiles/configs/mpv/`,
  the shader directory resolves into `/nix/store`, and no path anywhere in the
  MPV config tree mentions `configs-manager`.
- All seven scripts in the `mpv-with-scripts` wrapper resolve into `/nix/store`.
- `fuzzydir` works: a clip in a directory with a sibling `subs/` auto-loaded
  `subs/clip.srt` as an external subtitle track, which is `sub-file-paths=**`
  resolving.
- `uosc` owns the OSC: the `osc` property reads `no` at runtime with nothing in
  `mpv.conf` saying so.
- Driving the real bindings over mpv's IPC socket, `CTRL+1` sets exactly the six
  expected shader paths and every one of those files exists at the activated
  path; `CTRL+0` clears them. `Shift+ENTER` shows the filename. `R` reaches
  `script-binding reload/reload_resume` at priority 19, beating mpv's weak
  builtin `add sub-pos +1` — confirmed by pressing it and seeing `sub-pos`
  unchanged.

## The GPU path, once the drivers were reachable

No Nix-built program can open a GPU context on a non-NixOS distro until
`/run/opengl-driver` exists. Pointing one mpv process at the driver set
`targets.genericLinux.gpu` already builds was enough to lift that for a test,
and with `VO: [gpu-next]` running:

- every Anime4K mode compiled — `shaderc compile status 'success' (0 errors,
  0 warnings)`, no shader error in the session, shader counts matching each
  binding, frames still advancing;
- uosc drew: two window screenshots of identical size differ in hash across a
  `flash-timeline`;
- thumbfast rendered: a 120000-byte BGRA buffer whose contents change per
  requested timestamp, from the same message uosc sends on hover.

The renderer was llvmpipe rather than the host's RADV. Compilation is
driver-side, so this proves correctness, not performance. Ticket 06 carries
the remaining privileged step.

## Deviations from the tickets

- `reload` is Nixpkgs' script (4e6), not the legacy sibwaf one the ticket
  table implied; `input.conf` restores the `Shift+R` binding. The operator
  explicitly preferred better versions over legacy fidelity.
- `show_filename` is not packaged at all. It was one `show-text ${filename}`
  binding, which `input.conf` now does directly.
- `thumbfast`'s source is overridden to upstream head, one commit past the
  Nixpkgs pin, for the non-darwin environment-stripping fix.
- `uosc` replaces the vanilla-OSC fork, on the operator's choice, retiring the
  second local package.
- `mpv.conf` is verbatim apart from `hwdec`, now `auto-safe` rather than `no`,
  on the operator's choice.
- `mpv-cut` is unfree in Nixpkgs, so `flake.nix` names it in
  `allowUnfreePredicate`.
- Ticket 03's OSC question resolved to "no `mpv.conf` change" either way: both
  the fork and uosc set `osc` to `no` themselves, confirmed at runtime.

## Still on the table

Nothing on versions: every remaining pin was checked against upstream and is
current. `profile=gpu-hq` in `mpv.conf` is left as-is because mpv 0.41 expands
it to exactly `profile=high-quality` — renaming it is cosmetic and changes no
behavior.
