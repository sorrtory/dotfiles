# Spec: VPNized applications

Status: ready-for-agent

## Purpose and interface

Make everyday Vesktop launches use the shared sing-box backend for TCP and UDP
without requiring the operator to type a VPN command. This updates the existing
VPN effort, not a new implementation alongside it.

The selected Home Manager interface is:

```nix
dotfiles.vpnizedApps.vesktop.enable = true;
```

Enabling Vesktop installs its Nixpkgs package and owns the normal terminal
command, desktop entry and applicable URL handler. Start capture on demand;
do not autostart Vesktop at boot, and do not use its tray: closing the window
must end the process so capture's last-app cleanup applies. Vesktop settings
live in `configs/vesktop/settings.json`, linked out of store so the UI can
still change them; they set `tray`, `minimizeToTray`, `checkUpdates` and
`arRPC` (unreachable from the namespace's own loopback) to false.

Each configuration names its identity explicitly with `dotfiles.vpn.identity`.
The flake's `staging` configuration differs from `z` only in identity; the
bootstrap `home-manager` phase selects it once and remembers the choice.
Several identities, per-app identity and protocol switching are follow-up
work in `.scratch/vpn-followups/`. "Always tunneled" covers these managed launch
paths, not arbitrary execution of the underlying package or a malicious app.
Other applications keep ordinary host networking.

## Selected implementation

Reuse the existing tested prototype: one long-lived sing-box tunnel backend,
plus an on-demand, credential-free sing-box capture process holding a Linux
network namespace. Capture forwards TCP/UDP through the backend's local SOCKS
endpoint. There is only one WireGuard peer connection, not one per app.

Application lifetime tracking keeps capture alive while needed. Backend
restart preserves capture's namespace; backend loss must not cause direct
egress. Capture failure terminates dependent apps rather than silently moving
them to ordinary networking. Last-app exit removes capture-owned resources
without stopping the local proxy.

The prototype builds with pinned sing-box 1.14.0 and has passed CLI networking
and lifecycle tests. Ticket 00 preserves the evidence and remaining desktop
gates; it is not yet a verified everyday Vesktop replacement.

## Ownership and simplification

Target layout, to be created during implementation rather than this plan update:

```text
modules/programs/vpnized-apps/
  default.nix
  enter.sh
  capture-config.sh
```

Keep necessary runtime glue private beside its owning module and package it
with explicit dependencies through writeShellApplication. These helpers do
not belong in scripts/bin/, which is for deliberately user-facing commands.
Keep readable shell source separate rather than hiding its complexity inside
Nix strings. Exact private file count may shrink if behavior and tests survive.

Replace the provisional dotfiles.appVpn module/interface, rather than layering
another independent implementation over it. Reuse namespace-entry and capture
logic; simplify generic CLI dispatch and redundant delegation. Generate
app-specific launchers from one shared implementation. Do not build an
arbitrary-app framework before the first app works.

A generic `vpn <program>` is in scope for one-off use. Its user-facing source
is `scripts/bin/vpn.sh`, and it is the shared implementation managed launchers
call. Electron/Chromium apps beyond Vesktop need their own AppArmor allowance
and are follow-up work. No new doctor/status/cleanup CLI is required here.

AppArmor userns allowances are generated from the exact package paths and
installed by an explicit, numbered bootstrap phase that uses sudo; activation
only warns when installed profiles are stale.

## Behavior baseline

- Payload runs as the invoking user without elevated capabilities and with its
  actual desktop session. Preserve arguments, working directory and required
  environment; document intentional proxy-variable removal.
- UDP capture does not depend on application proxy support.
- Private resolver/nsswitch mounts route app DNS through capture and the tunnel;
  never rewrite host resolver files. Keep the backend's endpoint-bootstrap DNS
  exception and encrypted-secret ownership unchanged.
- Refuse handoff to an existing untunneled Vesktop process, printing its PID.
  Do not kill it, delete singleton locks, or copy login state.
- Preserve Electron sandboxing; do not use --no-sandbox as a workaround.
- Detect unsupported host namespace policy clearly. Normal Home Manager
  activation never invokes sudo or silently relaxes host security policy.
- No secret in arguments, environment, logs, patches or the Nix store.
- Use an exclusive, explicitly checked machine identity. Never run staging,
  legacy WireGuard and the replacement concurrently with the same peer key.
- No host-wide TUN interception, veth/NAT machinery, second WireGuard client,
  new protocol deployment, or automatic browser/editor proxy configuration.
- Session/login data remains machine-local.

## Scope and verification

Support Nixpkgs Vesktop first. Inspect its executable wrapping, desktop ID,
desktop actions and URL scheme metadata before generating overrides. Installation
may be a small package declaration; correct launch integration is separate work.
Snap/Flatpak, other Electron apps and general launcher-family support are deferred.

Reuse the existing configuration and manual integration tests, adapting them to
the module-owned launch path. Verify terminal, desktop and URL launches by actual
process namespace, not by the appearance of a window. Test singleton handoff,
voice UDP, audio/desktop integration, DNS, IPv6 no-escape behavior, backend
stop/restart, capture crash, concurrent launch and last-app cleanup.

Test network loss, resume and connection changes because staging previously
needed a backend restart; do not equate an active process with a healthy tunnel.
If a failure reproduces, diagnose it before selecting recovery machinery.

Build without host activation; use staging where its policy and hardware allow.
Record host-only desktop/GPU checks explicitly. Host activation and changes to
legacy host services require operator approval.

## Completion and retirement

Ship only after tests and operator normal-use review. Machines are bootstrapped
fresh rather than migrated, so there is no coexistence with the legacy launcher,
whole-host WireGuard client or native `/opt/Vesktop`. The partial veth/NAT port
of the legacy launcher is reference material in `.scratch/vpn-followups/`.

Update canonical docs in the implementation/documentation ticket: in particular
the old mandatory VPN command and scripts/bin source-location wording in
docs/DECISIONS.md and docs/MIGRATION.md §7. This operator-approved plan changes
that earlier scope; it does not claim those changes have shipped. Preserve
CONTEXT.md vocabulary until canonical terminology is reviewed.

Keep the existing .scratch/vpn-command paths and ticket numbers for continuity.
Git history preserves superseded kernel-WireGuard and generic-launcher plans.
