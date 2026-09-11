# 01 — Namespace lifecycle

Status: needs-triage

Blocked by: 00

## Design gate

The operator selected a shared sing-box backend and namespace TUN instead of
the separate kernel-WireGuard design. The work below is historical planning,
not an implementation instruction. Resolve ticket 00, then rewrite this ticket
around the verified lifecycle and compatibility results before claiming it.

## Goal

Create the tunnel namespace, reuse it while something is inside, and remove it
and everything it needed when nothing is.

## Work

1. Port the namespace construction from the legacy script: create the
   WireGuard interface on the host, move it into the namespace, configure it
   from the decrypted `extra.conf`, bring up `lo`, add the veth pair, enable
   forwarding, add the NAT and FORWARD rules on the detected WAN interface,
   pin a host route to the peer endpoint through the veth, and default
   everything else through the tunnel.
2. Read the configuration from
   `~/.config/sops-nix/secrets/wireguard/extra.conf`, and fail with a message
   naming the secret and the activation that produces it when it is absent. A
   fresh boot before activation is the normal way to meet that case.
3. Keep the private key on file descriptors, never on a command line or in the
   environment (spec, behavior baseline 3).
4. Make setup idempotent: an existing namespace is reused rather than
   recreated, and a half-built one from a killed run is torn down first rather
   than reused. Decide how to tell those apart and say so in the code.
5. Tear down automatically when the last process leaves. `ip netns pids` gives
   the count; removing the namespace while something is still inside would cut
   off a running application.
6. Keep an explicit `--clean` for the case where teardown did not happen.

## Constraints

- The tunnel's own packets must leave outside the tunnel. The endpoint route
  through the veth is what makes that true, and getting it wrong produces a
  namespace with no connectivity at all rather than an obvious error.
- Do not modify host state that is not namespace-scoped, beyond the veth, the
  two NAT/FORWARD rules, and `ip_forward` — each of which teardown removes.
  Record whether `ip_forward` was already set, and leave it as found.
- `iptables` on this host is the nftables backend. Use `-w` so a concurrent
  run cannot fail on a lock.

## Acceptance

- `vpn curl -s https://ident.me` prints an address that differs from the same
  command run without `vpn`.
- Running it twice concurrently does not corrupt the namespace or duplicate
  rules.
- After the last payload exits: no `vpn` namespace, no veth on the host, no
  matching NAT or FORWARD rule, no `/etc/netns/vpn`.
- Killing the command mid-setup leaves nothing that blocks the next run.
