# 01 — Profiles, egress and system-wide use without silent collisions

Status: needs-info
Blocked by: vpn-command/06

Enlarges the original "several identities" ticket; key management stays
first-class. Keep it simple: one sing-box backend, a few named profiles, one
switch, and guards that refuse or warn instead of colliding silently.

## Goal

- One backend holds this machine's **main** profile plus **fallback**
  profiles and `direct`, and routes the local proxy, `vpn` and VPNized apps
  through whichever is selected, with a per-app override.
- A **system-wide** VPN (kernel `wg-quick` on some profile, or another core such
  as v2rayN in TUN mode) can run without breaking the local proxy: the operator
  points the proxy's egress at `direct` (which then rides the system-wide route)
  or at any other profile.
- No mode silently uses one WireGuard key from two clients, and running a
  second core is detected rather than discovered by flapping traffic.

## Model

- **Profile**: a named credential with an owner machine, a protocol (WireGuard
  today; VLESS and others later) and its ciphertext. Declared once in an
  inventory that replaces the enum in `sing-box.nix`.
- **Egress**: the profile (or `direct`) the backend sends proxy and capture
  traffic through. Apps and capture never change; only the egress does.
- **System-wide router**: something outside the backend that owns the host's
  default route. At most one at a time.

## Work

1. **Inventory and key management.** Each configuration lists the profiles it
   may use and its main one; only those are decrypted. Tooling refuses a profile
   owned by another machine. Document adding, rotating and retiring a key
   (server peer, encrypt, declare, assign).
2. **Egress switch.** A small `vpn-egress status|use PROFILE|direct` command
   in `scripts/bin/`. Simplest mechanism first: record the selection in a
   private runtime file and restart the backend, which capture already survives;
   no control API or secret. Restart returns to the main profile unless decided
   otherwise.
3. **Per-app profile.** `dotfiles.vpnizedApps.<app>.profile` and
   `vpn --profile NAME`, each profile in use getting its own capture instance
   and local SOCKS inbound. Default is the current egress.
4. **System-wide.** `vpn-up`/`vpn-down` bring a chosen profile up with
   `wg-quick`. If that profile is the backend's egress, `vpn-up` first moves the
   egress to `direct` (bound to the new interface, so it fails closed if the
   interface disappears) rather than refusing; `vpn-down` restores it, in an order
   that never sends proxy traffic out directly in between.
5. **Collision guards.** Hard refusal: one profile used by both the backend and
   `wg-quick`, or a profile owned by another machine. Detection with a loud
   warning (see question 3): another core or TUN owning the default route
   (v2rayN, Xray, a second sing-box, another WireGuard interface), egress
   `direct` with no system-wide router (proxy apps go out unprotected), and
   nested tunnels. `vpn-egress status` always shows the egress, the default-route
   interface and any warning.
6. **Protocols.** The backend generator dispatches per profile protocol; capture
   and launchers stay unchanged because they only talk to local SOCKS.

## Prototype gate

Check before building, on staging:

- A WireGuard endpoint that is declared but not selected sends nothing (no
  handshake or keepalive); otherwise the backend must generate only the selected
  profile, or it holds sessions of keys it is not using.
- Restarting the backend on a new egress keeps capture, `vpn` and Vesktop working,
  as backend restart already does today.
- `direct` bound to an interface fails closed when that interface is removed.
- Detection signals for a second core are reliable enough: default route via a
  tun/wg device, extra policy-routing tables, known process names, `wg show`.

## Open questions

Parked for the operator to decide later. Recommendations are initial views.

1. **Switch mechanism**: restart on a runtime selection file (simple, ~1 s drop)
   or sing-box's selector with its control API (instant, adds an API and a
   secret)? Recommend restart until the drop proves annoying.
2. **Fallbacks**: manual only, or automatic failover (sing-box `urltest`)?
   Automatic can flap and hide a broken main profile; recommend manual first.
3. **Unknown second core**: warn, or refuse system-wide actions unless the
   operator confirms? Recommend refuse with an explicit confirmation.
4. **Persistence**: reset to main on restart and reboot, or remember the
   selection? Recommend reset, so a forgotten `direct` ends at reboot.
5. **Profiles for this machine**: which extra keys or protocols does it own, and
   who creates server peers when rotating?
6. **System-wide provider**: keep kernel `wg-quick` in `vpn-up`, rely on external
   tools like v2rayN, or both?
7. **Interface**: CLI only, or a GNOME indicator once the GNOME slice lands?
8. **Per-app granularity**: VPNized apps only, or also `vpn --profile` for
   one-off programs?

## Acceptance

- Switching egress or going system-wide never breaks proxy-configured apps,
  `vpn` or VPNized apps, and never sends their traffic out directly without the
  operator having chosen `direct`.
- No supported combination uses one WireGuard key from two clients; unsupported
  combinations are refused or loudly reported, never silent.
- Only profiles assigned to the machine are decrypted.

## Comments

Until this lands, `vpn-up` refuses while sing-box runs, which is safe but stops
proxy-configured apps while a whole-host tunnel is up. Considered and folded in
here rather than built separately: stopping sing-box for `wg-quick` (breaks
proxy apps), a second WireGuard peer for whole-host use (double tunnel, server
work), and sing-box capturing the whole host itself (root service, host routes
and DNS, fragile next to Docker).
