# Spec: VPN follow-ups

Status: needs-triage

Work deliberately deferred from the vpn-command slice. That slice ships one
identity, one managed app (Vesktop) and a generic `vpn` command for plain
programs. Nothing here is required for it, and nothing in it should block these.

## Profiles, egress and system-wide use

Today one `dotfiles.vpn.identity` names the encrypted WireGuard profile the
backend uses, and `vpn-up` refuses while sing-box runs because both would use
that key. The operator wants, kept simple:

- one backend with a main profile, fallbacks and `direct`, routed globally and
  per app;
- key management: an inventory of profiles with owners, decrypting only this
  machine's;
- a system-wide VPN (kernel WireGuard or another core such as v2rayN) that does
  not break the local proxy, whose egress can be moved to `direct` or another
  profile;
- no silent collisions: one key never used by two clients, and a second core
  detected.

The capture namespace and launchers already talk only to the backend's local
SOCKS endpoint, so they are independent of which profile or protocol leaves the
machine. See [issues/01-identities.md](issues/01-identities.md), which holds the
design and the operator's open questions.

## Any-app launcher

`vpn <program>` works without extra host policy for programs that do not create
their own user namespaces. Chromium/Electron apps do, so on Ubuntu with
`kernel.apparmor_restrict_unprivileged_userns=1` they abort until they receive
an exact-path AppArmor userns allowance, as Vesktop did.

The legacy launcher avoided this in two ways that do not carry over: it ran as
root (`sudo ip netns exec` + `runuser`), so root created the namespace, and the
native `/opt/Vesktop` ships a setuid `chrome-sandbox`, which the Nix store cannot.

## Reference material

- `reference/vpn-veth-port.sh`: a 412-line port of the legacy launcher using
  kernel WireGuard, veth and NAT. Never committed as a live command; the current
  spec forbids that machinery. Kept for its DNS and desktop-session handling.
- `~/Documents/scripts/vpn.sh` on the operator's machine: the original 686-line
  launcher. Its git history includes Discord screen-sharing and DNS fixes.
