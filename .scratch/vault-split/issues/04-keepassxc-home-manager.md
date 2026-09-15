# 04 — KeePassXC under Home Manager

Status: ready-for-agent
Blocked by: 03

## Goal

Replace the APT KeePassXC (2.7.12 at `/usr/bin`) with Home Manager's
`programs.keepassxc`, with browser integration configured for a two-vault
setup.

## Work

1. Enable `programs.keepassxc` with the plain `pkgs.keepassxc`, so the recovery
   app's store path is reused.
2. Declare only portable settings: `Browser.Enabled`, `Browser.UpdateBinaryPath =
   false` (the module installs the manifest), best-matching credentials only,
   search in all opened databases, and the current password generator values.
   Confirm key names against `src/core/Config.cpp` for the pinned version.
3. Decide autostart. If enabled, make sure KeePassXC does not start before the
   sops-nix user service has rendered the key file.
4. Retire the APT package as privileged host work in the bootstrap flow, and
   remove the stale `~/.mozilla/native-messaging-hosts` manifest pointing at
   `/usr/bin`.
5. Update the `KeePassXC` row in `docs/SOFTWARE.md`.

## Constraints

- Declared settings turn `keepassxc.ini` into a read-only store link. Never
  carry over `KeeShare.Own`: it is a private key, and the store is
  world-readable.
- Confirm remembered databases and key files live in KeePassXC's local state
  file, not the declared one, so ticket 03's key file choice survives.
- Until `firefox-nix/01`, the snap Firefox must keep working with the extension,
  or the swap waits for that ticket.

## Acceptance

- `keepassxc` and `keepassxc-cli` resolve to the Nix profile.
- KeePassXC-Browser connects and fills from `Daily.kdbx` with the recovery vault
  closed.
- The recovery app still builds, and its closure is unchanged.
