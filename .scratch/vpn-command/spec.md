# Spec: VPN command

Status: needs-triage

## Purpose

Provide `vpn <app>`: explicitly launch an application's TCP and UDP traffic
through a tunnel, including Discord voice, while other applications retain
ordinary host connectivity. See `CONTEXT.md` and `docs/DECISIONS.md`.

## Selected architecture

The local proxy effort first establishes one sing-box backend per machine with
an exclusive per-machine WireGuard identity. The VPN command will launch apps
inside a network namespace with a TUN entry point into that same backend.
It must not start another WireGuard client or reuse the shared extra profile.

The existing sing-box pin is 1.13.19. Upstream documents TUN netns and unshare
namespace support for 1.14+. A prototype must verify a suitable pinned version,
host user-namespace policy, and desktop compatibility before implementation
tickets become ready. Rootless operation is a candidate, not a demonstrated
property of this host.

Restarting the shared backend interrupts both proxy and VPN applications.
VPN applications must remain isolated and lose connectivity, never fall back
to host networking. The prototype must decide how to recover when the backend
recreates a namespace while existing processes still hold the old one.

## Behavior baseline

- The application runs as the invoking user, with its desktop environment.
- UDP capture does not depend on application proxy support.
- DNS stays inside the application network environment and traverses the tunnel.
  The host resolver configuration is unchanged.
- An existing untunneled application instance must not silently receive the
  launch request. Refuse such handoff and name the conflicting instance.
- Normal activation never invokes sudo. Any required runtime privilege is
  explicit and limited to namespace setup, never the application payload.
- No private key reaches command arguments, environment, logs, or the store.
- Cleanup removes launcher-owned resources after the last application exits
  without stopping the shared proxy backend.
- No host-wide capture, veth/NAT routing machinery, or direct fallback is part
  of the selected design. If the prototype cannot meet it, report the
  limitation before selecting an alternative architecture.

## Scope

Package separate launcher source through writeShellApplication and expose vpn.
Support launching commands with arguments, reuse of the application namespace,
cleanup, and objective tunnel diagnostics. Verify desktop/native Electron,
Snap and Flatpak launchers individually; unsupported cases must fail clearly.
The existing untracked scripts/bin/vpn.sh is prior work, not authorization to
overwrite it with the new design.

Proxy client configuration, remote-server transport deployment, and retirement
of the operator's legacy installation are separate work. Whole-host aliases
are a different entry point and are not replaced by this command.

## Definition of done

- The namespace prototype passes before implementation tickets are finalized.
- Direct and VPN requests demonstrate distinct egress.
- Discord voice/UDP, DNS and IPv6 behavior are verified objectively.
- For each supported launcher family, the actual application's network
  namespace is checked rather than inferred from a visible window.
- An already-running untunneled instance produces a refusal.
- Backend loss cannot cause direct egress; restart recovery behavior is tested.
- Last-application cleanup leaves the local proxy usable.
- Flake, build and tests pass; the operator verifies normal desktop use before
  host activation/commit according to repository policy.

## Superseded design

The earlier spec retained the legacy script's separate kernel-WireGuard
interface, veth and NAT setup and argued against sing-box. That overlooked
combining sing-box with namespace-scoped TUN capture. The operator selected
the shared backend instead. Git history preserves the old design and tickets.
