# 07 — Add a real native protocol alternative

Status: needs-info
Blocked by: 04

## Goal

Extend the uniform egress list with one tested sing-box-native alternative such
as VLESS, TUIC or Hysteria2, without changing the selector interface or capture
namespaces.

## Needs

Choose and deploy a real transport on the operator-controlled server, define its
credential format and confirm TCP, UDP and DNS behavior. Do not add a dormant
adapter, placeholder secret or single-member selection group.

## Work and acceptance

- Add one tagged adapter and runtime-only secret parser; keep protocol fields
  inside the entry and stable IDs outside it.
- Verify it manually through `vpn-egress` with proxy, `vpn`, Vesktop voice/UDP,
  DNS, IPv4/IPv6 policy and fail-closed server loss.
- Confirm unselected endpoint activity. sing-box 1.14 WireGuard endpoints remain
  instantiated and may keep alive even when a selector chooses another tag;
  do not silently equate “unselected” with “inactive.” Reassess an on-demand
  upgrade or accept/document the behavior before multiple native WG entries.
- Keep automatic selection out; this ticket proves a real alternative first.
