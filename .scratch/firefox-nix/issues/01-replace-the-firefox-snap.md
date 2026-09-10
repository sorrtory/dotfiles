# 01 — Replace the Firefox snap with a Nix-managed Firefox

Status: needs-triage

## Goal

Own Firefox through Home Manager so its profile lives at a predictable path
and is readable without snap confinement in the way.

## Work

1. Add Firefox from the pinned nixpkgs to the user environment. Override it
   with `nativeMessagingHosts` covering KeePassXC, so vault integration
   survives the move.
2. Migrate the existing profile once, as an explicit operator step: copy
   `~/snap/firefox/common/.mozilla/firefox/<random>.default*` to the new
   profile path, verifying bookmarks, saved logins, cookies and extensions
   afterwards. Record the step in the migration docs; do not attempt to make
   it declarative.
3. Remove the `firefox` snap only after that verification.
4. Install an APT preferences pin under `/etc/apt/preferences.d/` that blocks
   the `firefox` deb. On a fresh Ubuntu this is the load-bearing half: the
   deb is a transitional package whose only job is to install the snap, so a
   removal without a pin is undone by the next `apt upgrade`, weeks later,
   with no obvious cause. Do this as privileged host work in the bootstrap
   flow, following the non-nagging style of `06-docker.sh` — no reboot
   prompt, no "log out and back in" message.
5. Retire anything that globs `~/snap/firefox`, including the activation
   script added by `singbox-local-proxy` ticket 02.

## Constraints

- `AGENTS.md` rule 9: login and session state stays machine-local. Migrate the
  data, do not declare it.
- Do not lose the running proxy configuration during the swap. The PAC pref
  must be reapplied to the new profile in the same change.
- Verify Wayland behavior and hardware video decoding after the swap; the snap
  configures both for you.
- Do not touch `snapd` and do not remove any other snap. The host runs snaps
  this repository has no replacement for, including `cups` and
  `firmware-updater`, which are printing and firmware support. The selected
  policy is a sourcing rule, not a removal campaign; ticket 04 records it.

## Acceptance

- Firefox runs from the Nix profile, with bookmarks, logins and extensions
  intact.
- KeePassXC browser integration works.
- The `firefox` snap is gone and nothing in the repository references
  `~/snap/firefox`.
- On a staging VM from a stock Ubuntu image, a full `bootstrap.sh install`
  followed by `apt update && apt upgrade -y` leaves no `firefox` snap.
- `snap list` still works on that VM and still shows the host's other snaps.
