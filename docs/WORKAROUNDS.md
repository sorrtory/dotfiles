# Nixpkgs workarounds

Every place this repository deviates from what Nixpkgs packages, because of a
defect that belongs to someone else and will one day be fixed. Each entry says
which version the defect was observed in, when that was last confirmed, what
goes wrong, what we do instead, and what has to happen before the override is
deleted rather than carried.

The version recorded is **the packaged version that still has the defect**, not
the version we substitute — that one is in the code and changes when we change
it. The recorded version is a claim about someone else's release, so it is the
thing that goes stale on its own: once Nixpkgs moves past it, the entry needs
re-testing. [`tests/workarounds_test.sh`](../tests/workarounds_test.sh) checks
every recorded version against what the flake evaluates, so an update that
moves one of them fails and names the entry rather than leaving this file
quietly wrong; the check date says when a human last looked.

This is an index. The reasoning lives in a comment at the definition, where
someone reading the code meets it; what a comment cannot give is one place that
answers "what can we drop yet?".

Deliberately absent: overrides that encode our own integration rather than
someone else's defect — Obsidian's and Spotify's proxy flags, Rewaita's XDG
relocation patch — have no removal condition and stay as comments. Packages
taken from the unstable pin are policy, not deviation, and are argued in
[DECISIONS.md](DECISIONS.md#package-policy).

## Carried silently

Nothing announces the expiry of these. They keep building, and keep working,
long after the reason has gone; a stale version pin quietly holds the
environment *behind* the release pin, which is the package policy running
backwards. These are the entries worth re-reading on an update.

### gitleaks

- **Defect in:** `pkgs.gitleaks` at 8.30.1, on both pins.
- **Checked:** 2026-09-20.
- **Upstream:** [gitleaks#2170](https://github.com/gitleaks/gitleaks/issues/2170),
  closed as completed on 2026-07-28, and
  [#2086](https://github.com/gitleaks/gitleaks/issues/2086) behind it. The fix
  is on master and unreleased: 8.30.1 (2026-03-21) is still the newest tag.
- **Defined in:** [flake.nix](../flake.nix).

8.30.1's default rules match nothing at all. A canonical GitHub PAT scans
clean — "no leaks found", exit 0 — where 8.18.4 flags the same token; AWS keys,
Slack tokens and SSH keys behave the same way, across every detection mode.
The release appears to have been cut from off-master code. A secret scanner
that silently passes everything is worse than no scanner, because it is trusted,
and this one gates the staged secret check on a repository intended to go
public.

We pin 8.18.4, the last release whose rules fire, and patch the version string
into the build. `doInstallCheck` is off because that release spells it
`gitleaks version` rather than `--version`, which is what Nixpkgs'
`versionCheckHook` expects.

**Removed when** gitleaks tags a release after 8.30.1 carrying the fix and
Nixpkgs picks it up. Bump the pin and confirm the canonical-token fixture in
[`tests/secret_scan_test.sh`](../tests/secret_scan_test.sh) still fails the
scan — that fixture exists for this bump.

### rewaita

- **Defect in:** `pkgs.rewaita` at 1.1.1, on both pins.
- **Checked:** 2026-09-20.
- **Upstream:** [SwordPuffin/Rewaita](https://github.com/SwordPuffin/Rewaita)
  released 1.1.7; nothing filed against Nixpkgs, which is simply behind.
- **Defined in:** [packages/rewaita.nix](../packages/rewaita.nix).

1.1.1 predates the CLI theme selector and the Firefox output that Rewaita's
current guide describes, and the theme core drives both: the generated palette
is selected non-interactively at activation, which 1.1.1 offers no way to do.

We override `src` to the 1.1.7 tag. The `postPatch` in the same file, which
moves Rewaita's mutable data under its own directory in `~/.local/share`, is
ours rather than a workaround and stays whatever Nixpkgs packages.

**Removed when** Nixpkgs carries 1.1.7 or later: drop `version` and `src`, keep
the `postPatch`.

### mpvScripts.thumbfast

- **Defect in:** `pkgs.mpvScripts.thumbfast` at 0-unstable-2025-02-04, on the
  stable pin. Unstable already carries 0-unstable-2026-06-28.
- **Checked:** 2026-09-20.
- **Upstream:** [po5/thumbfast](https://github.com/po5/thumbfast); fixed
  upstream and in Nixpkgs unstable, so only the release pin is behind.
- **Defined in:** [modules/programs/mpv.nix](../modules/programs/mpv.nix).

The packaged commit spawns the thumbnailer with `env = "PATH=..."`, which
discards every other variable — including the Wayland and X11 ones the
subprocess needs to open a display. Thumbnails never appear on Linux. Upstream
has since restricted that stripping to darwin.

We pin commit `0f711de`, the commit after the packaged one. The legacy checkout
was already on it, so taking the Nixpkgs pin unchanged would have been a
regression rather than a neutral move.

**Removed when** the stable pin reaches `0-unstable-2026-06-28` or later. This
is the closest to expiry of anything in this file.

### gnome-extension-manager

- **Defect in:** `pkgs.gnome-extension-manager` at 0.6.5, on both pins.
- **Checked:** 2026-09-20.
- **Upstream:** a Nixpkgs packaging defect, not an
  [upstream](https://github.com/mjakeman/extension-manager) one. No issue or PR
  filed as of 2026-09-20 — worth filing, since the fix is one line.
- **Defined in:** [modules/desktops/gnome.nix](../modules/desktops/gnome.nix).

Nixpkgs builds it against libsoup3 but leaves `glib-networking` out of its
inputs, so `wrapGAppsHook4` writes a wrapper whose `GIO_EXTRA_MODULES` names
only dconf. GIO then has no TLS backend at all, falls back to
`GDummyTlsBackend`, and every request to extensions.gnome.org fails with "TLS
support is unavailable": the Browse tab is empty and nothing installs. NixOS
never sees this, because its GNOME module exports glib-networking's module
directory session-wide; `targets.genericLinux` has no equivalent, so on Fedora
the missing input is load-bearing rather than cosmetic.

We add `glib-networking` to `buildInputs`, which is enough — the hook picks it
up and prefixes the path itself.

**Removed when** Nixpkgs adds the input. Nothing will say so: an extra
`buildInput` stays harmless-looking forever, which is why this entry exists.

### sublime4

- **Defect in:** `pkgs.sublime4` at 4200, on both pins.
- **Checked:** 2026-09-20.
- **Upstream:** no issue; this is an end-of-life runtime in a vendor binary,
  resolved by Sublime shipping build 4205 or later.
- **Defined in:**
  [modules/programs/sublime-text.nix](../modules/programs/sublime-text.nix).

Both plugin hosts of build 4200, the Python 3.3 and 3.8 ones, link OpenSSL 1.1.
Nixpkgs marks `openssl_1_1` insecure and Hydra builds no insecure package, so
the permitted-insecure exception this needed compiled OpenSSL 1.1 from source
on every pin bump. Neither alternative works: no target distro ships OpenSSL
1.1 for the binary's rpath to find, and the unstable package drops it by
deleting the 3.3 host, a build Nixpkgs marks broken and which leaves the 3.8
host unable to load its libraries, so no plugin runs at all.

We link the `libssl.so.1.1` and `libcrypto.so.1.1` that Sublime's own tarball
already ships — the same end-of-life runtime the official build runs, one patch
release older at 1.1.1v — so the exposure is unchanged and Nix stops flagging
it. That copy's compiled-in certificate directory is a sublimehq build prefix
that exists on no machine, so the wrapper sets `SSL_CERT_FILE` to the Nixpkgs
CA bundle unless the environment already names one.

**Removed when** the stable pin is build 4205 or later, whose plugin host links
OpenSSL 3: delete the vendored derivation and the `SSL_CERT_FILE` wrapper
together. Half-announcing — if Nixpkgs drops the `openssl_1_1` argument,
`.override` throws; if it only bumps the build, nothing does.

## Self-announcing

These patch a named line of someone else's source through `--replace-fail`, so
the build breaks the moment upstream touches it. They still need an entry, to
say what to do when that break arrives, but they will not rot unnoticed.

### gnomeExtensions.blur-my-shell

- **Defect in:** `pkgs.gnomeExtensions.blur-my-shell` at 72, on both pins.
- **Checked:** 2026-09-20.
- **Upstream:** [blur-my-shell#866](https://github.com/aunetx/blur-my-shell/issues/866),
  fixed by [#867](https://github.com/aunetx/blur-my-shell/pull/867), merged
  2026-04-29. v72 was published 2026-04-09 and there is no v73, so the fix is
  in no release.
- **Defined in:** [modules/desktops/gnome.nix](../modules/desktops/gnome.nix).

With application blur on and GNOME's `workspaces-only-on-primary` set, the
secondary monitor's windows disappear after a workspace switch. The extension
patches `_finishWorkspaceSwitch` to hide every window of every inactive
workspace, and a window on the secondary monitor counts as being on all
workspaces, so hiding it for one inactive workspace hides it everywhere. The
windows keep working and still appear in the overview and Alt+Tab; nothing is
drawn.

Nixpkgs fetches this from the published zip on extensions.gnome.org rather than
from git, so neither pin can carry the fix before upstream tags a release — the
unstable pin is no help here.

We apply the upstream hunk to `components/overview.js`, skipping windows for
which `is_on_all_workspaces()` holds.

**Removed when** the packaged version rises above 72. `--replace-fail` breaks
the build at that point rather than leaving a patch that silently matches
nothing.

### python3Packages.spotapi

- **Defect in:** `unstablePkgs.python3Packages.spotapi` at 1.2.7, the pin spotdl
  comes from.
- **Checked:** 2026-09-20.
- **Upstream:** [Aran404/SpotAPI](https://github.com/Aran404/SpotAPI); nothing
  filed.
- **Defined in:** [modules/scripts.nix](../modules/scripts.nix).

spotapi's TLS client is constructed with an empty proxy and never consults the
environment, so its Spotify lookups always go direct. Where Spotify is
region-blocked that request lands on a "not available" page and spotapi dies
with an `IndexError` parsing it. spotdl's own `--proxy` does not cover this: it
reaches only the audio download, while the Spotify and YouTube Music lookups
read the environment.

We fall back to the environment's HTTPS proxy, which `download` sets from
`PROXY`, scoped to that one process. The override goes on the Python scope
rather than on spotdl so that SpotipyFree, its other consumer, gets it too.

**Removed when** upstream honours the environment. `--replace-fail` breaks the
build then.

## Removed

Nothing yet. An entry moves here, cut down to a line naming the version that
fixed it, in the commit that deletes the override — so the next person meeting
the same symptom can see it was already dealt with, and when.
