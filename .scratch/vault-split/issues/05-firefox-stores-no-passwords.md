# 05 — Firefox stores no passwords

Status: ready-for-agent
Blocked by: 04, firefox-nix/02

## Goal

Make KeePassXC the only place a login can be saved.

## Work

1. In the declared Firefox profile, set `signon.rememberSignons = false` and
   `services.sync.engine.passwords = false`, so neither Firefox nor another
   synced Firefox writes logins back.
2. After confirming every login exists in `Daily.kdbx`, remove Firefox's saved
   logins by hand in `about:logins`.

## Constraints

- Removing saved logins is an operator step, never a declared one.
- Do not declare Mozilla account sign-in; it stays a mutable session.

## Acceptance

- Signing in to a new site offers a save from KeePassXC-Browser, not Firefox.
- `about:logins` is empty and stays empty after a Sync.
