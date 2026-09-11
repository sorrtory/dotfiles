# 00 — Prototype the shared sing-box namespace entry point

Status: ready-for-agent

Blocked by: singbox-local-proxy/01

## Question

Can the per-machine backend also serve whole-application TCP and UDP through
a namespace-scoped TUN, preserving the local proxy and ordinary host routing?

## Work

1. Select a reproducibly packaged sing-box version with TUN `netns` support
   (documented since 1.14). Prefer the available Nixpkgs package sets; record
   the exact version and release maturity before changing dependencies.
2. Test unprivileged namespace creation under the actual host policy. Determine
   whether entering it preserves the user's desktop and Electron sandbox.
   If runtime privilege is needed, identify the smallest explicit setup step.
3. Add the namespace TUN to the existing backend, with namespace-only routes
   and DNS. Do not create a second WireGuard connection with the same identity.
4. Launch a CLI probe and Discord. Verify actual process network namespaces,
   distinct egress, UDP voice traffic, tunneled DNS, and IPv4/IPv6 behavior.
5. Interrupt tunnel transport, stop/kill the backend, and restart it with an
   application still running. Prove there is no direct egress. Determine
   whether existing applications recover or need an explicit relaunch when
   the namespace is recreated; never silently leave them on a dead namespace.
6. Check native Electron, Snap and Flatpak launch behavior, including a copy
   already running outside the tunnel. Record tested support and limitations.
7. Prove the local proxy remains usable after the last VPN application exits,
   and that unrelated host networking/resolver state has not changed.

## Outcome

Record exact commands, version, evidence, privilege requirements and lifecycle
decisions. Rewrite tickets 01–06 around the verified design and mark only
fully specified tickets ready. A successful local proxy alone does not resolve
this prototype. Keep the operator's existing launcher source intact.
