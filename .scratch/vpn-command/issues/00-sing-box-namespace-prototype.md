# 00 — Finish the namespace prototype and Vesktop compatibility gate

Status: resolved

Blocked by: singbox-local-proxy/01

The dependency is resolved in commit `91793c9`. The operator authorized
implementation for opt-in Discord/Vesktop only; no automatic proxy settings
are to be applied to other applications. The host desktop entry launches
`/opt/Vesktop/vesktop`. Upstream stable 1.14.0 and Nixpkgs unstable's 1.14.0
package were available at the recorded probe. The prototype uses the pinned
1.14.0 package; the initial committed service used 1.13.19.

## Question

Can the verified namespace capture flow run the selected Vesktop package with
its desktop and Electron sandbox intact, before it becomes the default managed
launch path? The networking evidence below remains valid; it is not a claim of
finished Vesktop integration.

## Work

1. Reuse the pinned sing-box capture/entry prototype and the evidence below.
   Do not recreate a kernel WireGuard backend or repeat completed probes without
   a regression-related reason.
2. Build and probe Nixpkgs Vesktop through the existing private entry helper,
   without enabling the unfinished module or replacing the host installation.
   Inspect its actual executable wrapper, sandbox and desktop metadata.
3. Verify the actual app's namespace/user, window, audio and session access.
   Do not use --no-sandbox, migrate login data or alter host namespace policy.
   Record prerequisites and the staging/host difference explicitly.
4. Record what remains for the managed launcher and normal-use tests in tickets
   03–05, including existing-instance handling, real voice use and live IPv6.
   General Snap/Flatpak and other app-family testing is now out of scope.

## Outcome

Record exact commands, version, evidence and privilege requirements. Tickets
01–06 have been rewritten around the operator-selected vpnizedApps interface;
resolve this gate only after the remaining Vesktop package/sandbox probe passes.
This gate is distinct from final voice-call and managed-entry verification in
ticket 05. Keep the operator's existing launcher source intact.

## Evidence — 2026-09-14

Implemented an optional, disabled-by-default `dotfiles.appVpn` module and
separate launcher/capture sources. The original `scripts/bin/vpn.sh` is intact.
The package builds with the pinned Nixpkgs sing-box 1.14.0 package; no host
Home Manager activation has occurred.

The lifecycle design now uses two processes but only one WireGuard backend:
an on-demand, credential-free sing-box capture adapter owns the namespace and
forwards TCP/UDP over local SOCKS5. Application scopes require the adapter;
the adapter only wants the backend, so backend restart preserves the namespace.
Last-scope exit stops the adapter; adapter failure stops dependent scopes.
This replaces the initial assumption that the long-lived WireGuard process
would also own a disposable application namespace.

Verified on the host, using temporary runtime units/configs with cleanup:

- Rootless namespace entry preserves UID 1000; payload capabilities are zero.
- Resolver and nsswitch bind mounts are private to the payload namespace.
- Real IPv4 and IPv6 TCP/UDP sockets reach a localhost echo fixture through
  TUN/SOCKS. This is not a claim about the remote peer's IPv6 Internet support.
- Multiple application scopes share capture; the last exit removes its runtime
  directory and stops its service.
- Killing capture terminates its dependent application scope. Its runtime
  removal can race payload cleanup; cleanup tolerates already-removed files.
- Backend stop fails closed; restarting it restores TCP and UDP in the same
  capture namespace. Reproducible test: `tests/manual/vpn_capture.sh`.
- Live HTTPS and DNS through WireGuard have different egress from direct host
  HTTPS. Native `sing-box tools stun -s stun.l.google.com:19302` succeeds inside
  capture. Tests temporarily stopped staging and used its desktop-ubuntu peer
  on alternate local ports; cleanup removed tmpfs secrets and restored staging.
- Fixed a real launcher bug: canonicalizing executable symlinks before exec
  broke Nix multicall coreutils (`timeout`). Preserve the invoked path, using
  canonical paths only for executable checks. The integration test covers it.

Staging's existing 1.13 backend initially failed numeric and named destinations
while direct HTTPS worked; its journal recorded earlier loss of the default
network interface. Restart restored HTTPS. This does not establish the cause
of the earlier host transport failure, and network-loss recovery needs further
testing before making a reliability claim.

Remaining: native Vesktop/Electron sandbox and normal voice use, existing
instance refusal, live IPv6 egress, and the host-policy path for
staging (which blocks rootless namespace creation). Snap/Flatpak launchers are
explicitly unsupported in this first implementation. Do not enable the module
or declare everyday readiness based solely on CLI/STUN success. No browser/editor
proxy settings have been changed.

## Comments — Plan revision

The operator selected dotfiles.vpnizedApps.vesktop.enable as the primary
interface, installing Vesktop and wrapping its ordinary launch paths. Private
helpers belong beside the module, not scripts/bin/. The generic vpn command
is optional follow-up. This revision updates planning only; it does not move
files, enable the module, install Vesktop, or retire legacy code. The current
prototype remains a starting point to simplify, not an additional supported
VPN flow. See ../spec.md and ../map.md for the revised scope and order.

### Staging Vesktop installation

At the operator's request, added Vesktop to the current standalone package list
for the initial account/desktop test. Ownership moves into vpnizedApps in ticket
03; do not keep a duplicate package declaration then.

Built and activated on staging with the desktop-ubuntu localProxy override,
preserving its exclusive peer identity. Verified the installed Nixpkgs package
is vesktop-1.6.5-unstable-2026-07-16, with a Vesktop desktop entry and Discord URL
scheme metadata. The operator will log in themselves. No host activation.

This installation is not VPN-wrapped: sing-box.service is active, but capture
remains inactive and dotfiles.appVpn remains disabled. A normal account test
does not resolve the namespace/sandbox or voice-over-tunnel gate.

### Staging sandbox prerequisite

The normal package launch initially failed: AppArmor denied Electron namespace
capabilities and the setuid fallback was unavailable. With explicit operator
approval, installed the exact-path profile from
`configs/apparmor/dotfiles-vesktop-electron` on staging only. The same version
probe now succeeds; a normal desktop launch is active, with sandboxed child
namespace isolation and seccomp observed. The global restriction remains on and
ordinary unshare remains denied. See `docs/VESKTOP-APPARMOR.md` for the security
tradeoff, evidence, upgrade maintenance and rollback.

This resolves ordinary Electron startup, not the combined sing-box/Vesktop
namespace gate. The operator's account and voice test remains pending; no login
state was inspected or made declarative. Do not generalize this profile to all
Nix-store executables or mark capture compatibility proved by this result.

### Combined staging capture test

The operator requested completing the actual VPN launch after direct Vesktop
could not load Discord. Added and explicitly installed the exact sing-box
AppArmor allowance on staging, leaving the global restriction on. No nsenter,
unshare, Bash or wildcard store allowance was needed.

Activated a staging-only build with desktop-ubuntu identity and appVpn enabled.
Confirmed no direct Electron process remained, then launched the installed
Nixpkgs Vesktop through the VPN command. Its main process shares capture's
network namespace, distinct from the ordinary VM session; UID 1000, zero main
process capabilities, no-new-privileges, and sandboxed-child seccomp were checked.
Discord HTTPS returned 200 and native UDP/STUN through that same capture passed.

The app is running for operator login/voice testing. Normal icon and bare command
are not yet wrapped. Generic singleton detection for the Nix Electron wrapper,
desktop/audio use, real voice, and final module integration remain unverified;
do not resolve this ticket on the network probes alone. See
`docs/VESKTOP-APPARMOR.md` for the test command and exact scope of the exceptions.

## Answer

Yes. On staging, the Nixpkgs Vesktop launched through the VPN command ran with
its main process in capture's network namespace and Electron sandboxing intact.
The operator then logged in and confirmed a real voice call works over the
tunnel, which closes the gap between the STUN probe and actual voice use.

The gate needed two exact-path AppArmor userns allowances on an Ubuntu host
with the global restriction on: one for Electron and one for sing-box. Both were
installed by hand; ticket 03 makes them reproducible. The staging VM has since
been reset, so the module work is verified from a fresh bootstrap.

Decisions taken while closing this gate, recorded in the spec by ticket 01:
no tray and no autostart; Vesktop settings live in the repository and stay
editable from the UI; one explicit `dotfiles.vpn.identity`; a user-facing `vpn`
command stays in scripts/bin/; the old veth/NAT launcher moves to follow-up
reference material instead of being committed as a live command. Machines are
bootstrapped fresh, so there is no live migration or legacy coexistence.
