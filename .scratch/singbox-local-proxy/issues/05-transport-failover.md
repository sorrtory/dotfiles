# 05 — Transport failover for a blocked protocol

Status: wontfix

## Answer

Superseded by `.scratch/vpn-egress/`, which defines one shared egress
inventory and keeps automatic strategy out until real alternatives exist.
The proposal below is retained as history, not implementation direction.

The old wording also overstated `urltest`: in pinned sing-box 1.14 it is latency
selection, not ordered failover, and it does not retry the same failed request
through another candidate.

## Goal

Keep `127.0.0.1:1080` working when WireGuard itself is blocked, without any
client reconfiguration.

## Why this is not ticket 01's job

sing-box does not make WireGuard undetectable — its WireGuard endpoint is the
same protocol on the wire, with the same UDP signature. Protocol agility only
pays out if a server speaks something else. The VPS is operator-controlled
(all six profiles point at one self-hosted endpoint on the
`wireguard-install` defaults), so the hedge is available, but a second
transport does not exist yet.

Building the group before the server exists would add a config path that has
never been exercised, and a `urltest` group with one member is theater.

## Needs

A decision on which second transport to deploy on the VPS. `sing-box` 1.13.19
at the current pin is built `with_quic` and `with_utls`, so `hysteria2`,
`tuic`, `vless` and `shadowsocks` outbounds are all available client-side
without changing the pin.

## Work, once that is answered

1. Deploy the chosen transport on the VPS.
2. Add it as an outbound alongside the WireGuard endpoint, and a `urltest`
   group containing both. A group accepts an endpoint tag and an outbound tag
   side by side — verified against 1.13.19.
3. Point the route rule at the group instead of the endpoint. The inbound and
   the port do not change, so no client learns anything happened.
4. Verify failover by blocking the WireGuard endpoint's UDP port locally and
   confirming the proxy keeps serving.

## Constraints

- Secrets for the second transport follow ticket 01's pattern: whole-file
  ciphertext under `secrets/`, generated into `RuntimeDirectory`.
- Do not add a `urltest` group with a single member.
