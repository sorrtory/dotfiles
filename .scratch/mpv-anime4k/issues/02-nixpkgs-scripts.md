# 02 — Scripts available from Nixpkgs

Status: claimed
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

## Comments

Four of the five landed as specified. `mpvScripts.cut` is indeed pinned to
`3b18f1161ffb2ff822c88cb97e099772d4b3c26d`, byte-identical to the legacy
`manager.lock` pin.

**The `reload` row of the table is wrong and was not followed.** The legacy
link points at `sibwaf/mpv-scripts`' `reload.lua`, which binds `Shift+R` and
reopens the current file at the same timestamp. Nixpkgs' `mpvScripts.reload`
is `4e6/mpv-reload` — a different script by a different author, which binds
`Ctrl+r` and additionally reloads automatically on buffering timeouts. Taking
it would have silently moved the operator's key binding and added unrequested
behavior, so `reload` moved to ticket 03 as a local package built from the
sibwaf source that ticket already fetches for `fuzzydir`. The alternative — 
accept the Nixpkgs script and its `Ctrl+r` binding plus auto-reload — is a
live option if the operator prefers it; nothing else depends on the choice.

`mpv-cut` needed one unanticipated change: Nixpkgs marks its custom upstream
licence unfree, so `"mpv-cut"` is now named in `flake.nix`'s
`allowUnfreePredicate` next to the desktop applications. It is a retained
legacy script rather than a new choice, which is what that entry's comment
says.

The `smart-copy-paste-2` major bump is the one deliberate version change, as
the ticket directed; it is called out in the commit message so a later
regression has an obvious first suspect.

The acceptance's `~/.config/mpv/scripts/` check does not apply as written:
`programs.mpv.scripts` bakes `--script=` arguments into an `mpv-with-scripts`
wrapper rather than populating the config directory. The intent is met — all
eight script paths in the wrapper resolve into `/nix/store`, verified on the
host — but a VM check should read the wrapper, not that directory.

Outstanding: the `autoload` playlist check on the VM.
