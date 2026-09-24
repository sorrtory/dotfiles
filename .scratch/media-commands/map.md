# Media download and conversion commands

Replace the scattered `download-*` aliases and the legacy `convert-to-*` shell
functions with two real commands, `download` and `convert-to`, dispatching over
yt-dlp, gallery-dl, aria2c, spotdl and FFmpeg. See [spec.md](spec.md).

## Tickets

- [01 — Support image targets in `convert-to`](issues/01-convert-image-targets.md) — resolved: `jpg`/`png` targets added; colon paths fixed
- [02 — Diagnose Spotify download failure](issues/02-spotify-download-fails.md)
- [03 — Preserve the requested video format](issues/03-video-original-format.md)

The implementation landed before these field reports. They are follow-up bugs
and scope decisions against the original settled design.
The `download` command's type-first interface was replaced on 2026-09-24 by
URL-based backend selection with `--as` and `--using`; the old interface in
`spec.md` is preserved as history and marked there as superseded.

## Context

- Grew out of adding `gallery-dl` to the repository. That package landed first,
  from the `nixpkgs-unstable` input, with its rationale in `docs/DECISIONS.md`.
- The interim state this effort replaces is already in the working tree: three
  `download-*` aliases in `modules/programs/zsh.nix` and
  `scripts/bin/download-jpg.sh` with its test. All are removed by this effort,
  and the `--exec` converter in that script moves into `download` intact after
  being verified against real PNG, GIF and proxy cases.
- `$PROXY` is exported by the local-proxy module from the same `proxyUrl`
  binding the `claude` and `codex` wrappers use, so it was added as part of the
  interim state and survives into this one.
- The design was settled over five rounds of grilling rather than proposed
  whole. Two recommendations were withdrawn after being checked against the
  tools: `--remux-video` in place of `--recode` (it fails rather than degrades),
  and a `-o` destination flag on `download` (it collides four ways with the
  backends' own meanings for `-o`). Both reversals are recorded in the spec
  because the reasoning is not recoverable from the result.
- New dependencies: `aria2` for `download file`, `spotdl` for Spotify. Both are
  packaged in the pins this repository already uses.
- Documentation this effort must revisit: the `gallery-dl` and `yt-dlp` rows in
  `docs/SOFTWARE.md`, the downloader paragraphs in `docs/DECISIONS.md`, and the
  "Local proxy" section of `README.md`, all of which currently describe the
  interim aliases.
