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
4. Retire anything that globs `~/snap/firefox`, including the activation
   script added by `singbox-local-proxy` ticket 02.

## Constraints

- `AGENTS.md` rule 9: login and session state stays machine-local. Migrate the
  data, do not declare it.
- Do not lose the running proxy configuration during the swap. The PAC pref
  must be reapplied to the new profile in the same change.
- Verify Wayland behavior and hardware video decoding after the swap; the snap
  configures both for you.

## Acceptance

- Firefox runs from the Nix profile, with bookmarks, logins and extensions
  intact.
- KeePassXC browser integration works.
- The `firefox` snap is gone and nothing in the repository references
  `~/snap/firefox`.
