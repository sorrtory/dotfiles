# Spec: Firefox under Nix

Status: needs-triage

## Why

Firefox on this host is the Mozilla snap (154.0.1). Snap confinement makes
declarative configuration structurally awkward, and the limits are measured,
not assumed. From inside the snap:

- `$HOME` is `/home/z/snap/firefox/common`, so `~/.config/...` does not mean
  what the rest of the environment means by it.
- The `home` interface denies hidden paths in the real home: reading
  `/home/z/.bashrc` returns `Permission denied`.
- `/run/user/1000/secrets.d/...` returns `Permission denied`; the snap has its
  own runtime directory at `/run/user/1000/snap.firefox`.
- Non-hidden real-home paths are readable, which is the only reason
  `~/Documents/secrets/proxy.pac` works today.

Two consequences drive this effort. First, the profile directory has a random
name, so prefs can only be written by a script that globs for it — which is
why `singbox-local-proxy` ticket 02 ships an activation script rather than a
file declaration. Second, sops-rendered secrets are unreachable by a confined
Firefox, so the PAC file cannot be encrypted while the snap owns the browser.

De-snapping removes both limits at once.

## Scope

In scope:

- Replacing the Firefox snap with a Nix-managed Firefox.
- Declarative preferences and extensions through a named profile.
- Moving `proxy.pac` into `secrets/` as ciphertext, delivered to a path the
  browser can actually read, and pointing `network.proxy.autoconfig_url` at it.

Out of scope:

- The proxy itself. `singbox-local-proxy` owns the transport; this effort only
  changes who reads the PAC and from where.
- Browser userscripts, which `docs/MIGRATION.md` assigns to the separate
  `monkeys` repository.
- Making login and session state declarative. `AGENTS.md` rule 9 keeps that
  machine-local; profile data moves once, by hand, as migration.

## Risks

- **Profile migration is the whole risk.** Bookmarks, history, saved logins,
  cookies and installed extensions live in
  `~/snap/firefox/common/.mozilla/firefox/<random>.default*`. Moving them is a
  one-time operator step, not a declarative one, and it is the step that can
  lose data.
- **Native messaging.** KeePassXC browser integration needs the native
  messaging host registered against the Nix-built Firefox
  (`nativeMessagingHosts`), and KeePassXC itself stays outside these dotfiles.
  A de-snapped Firefox with no `nativeMessagingHosts` silently loses vault
  integration.
- **Snap-specific paths in the legacy installer** disappear, so anything still
  globbing `~/snap/firefox` must be retired in the same change.

## Tickets

See [map.md](map.md).
