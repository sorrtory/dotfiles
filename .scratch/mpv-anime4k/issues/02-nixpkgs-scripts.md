# 02 — Scripts available from Nixpkgs

Status: ready-for-agent
Blocked by: 01

## Goal

Replace five of the eight legacy script symlinks with `pkgs.mpvScripts`
packages, so they come from the store instead of a manual checkout.

## Work

Add to `programs.mpv.scripts` in `modules/programs/mpv.nix`:

| Legacy link | Legacy pin | Nixpkgs attribute |
| --- | --- | --- |
| `autoload.lua` | `mpv-player/mpv` @ `94335ab` | `mpvScripts.autoload` |
| `reload.lua` | `sibwaf/mpv-scripts` @ `e4fb662` | `mpvScripts.reload` |
| `thumbfast.lua` | `po5/thumbfast` @ `0f711de` | `mpvScripts.thumbfast` |
| `mpv-cut` | `familyfriendlymikey/mpv-cut` @ `3b18f11` | `mpvScripts.cut` |
| `SmartCopyPaste.lua` | `Eisa01/mpv-scripts` @ `b9e6374` | `mpvScripts.eisa01.smart-copy-paste-2` |

## Constraints

- `mpvScripts.cut` is pinned to `3b18f1161ffb2ff822c88cb97e099772d4b3c26d`,
  byte-identical to the legacy `manager.lock` pin. No behavior change is
  expected there.
- `smart-copy-paste-2` is a major version bump from the legacy v1. The
  operator has accepted it. Record in the commit message that this is the one
  deliberate version change in the slice, so a later regression has an obvious
  first suspect.
- Do not repackage any of these locally. `docs/DECISIONS.md` says existing
  MPV ecosystem packages should not be repackaged.

## Acceptance

- `nix build .#homeConfigurations.z.activationPackage` succeeds.
- After activation on the staging VM, `~/.config/mpv/scripts/` contains the
  five scripts and every one resolves into `/nix/store`.
- `mpv --idle --vo=null` logs no script load errors.
- Opening a directory of media files autoloads the playlist, confirming
  `autoload` is live.
