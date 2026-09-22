# 04 — Add a real VLESS or Hysteria2 egress

Status: needs-info

Blocked by: 01

## Goal

Prove the inventory carries a protocol other than WireGuard, using a real
server rather than a placeholder.

The ticket stays `needs-info` until a transport is actually deployed and its
credential exists. Do not add a dormant entry or an invented secret.

## Work

1. Paste the provider's or server's own sing-box outbound JSON into
   `egresses.jsonc` under a tag following the naming scheme, with its notes as
   comments. No new code should be needed; if it is, the generator is doing
   too much.
2. If the server's tunnel has no IPv6, list the tag in `policy.jsonc`.
3. Select it with `vpn-egress use` and exercise the full path: the local
   proxy, the VPN command, Vesktop voice and AyuGram calls, DNS, and the
   whole-host tunnel from ticket 03.
4. Confirm fail-closed behaviour when the server is unreachable: traffic stops
   rather than falling back.

## Acceptance

- [ ] A real non-WireGuard egress is selectable and carries TCP, UDP and DNS.
- [ ] Adding it required inventory edits only.
- [ ] Switching between it and a WireGuard egress works in both directions.
- [ ] Server loss fails closed on every entry point.
