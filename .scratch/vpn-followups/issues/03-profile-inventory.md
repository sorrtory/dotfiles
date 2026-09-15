# 03 — Build the egress inventory and compiler

Status: ready-for-agent
Blocked by: vpn-command/06

## Goal

Replace the single identity enum as the backend routing model with the uniform
egress list and policy in ../spec.md, while preserving current behavior for a
configuration that declares only its existing WireGuard identity.

## Work

1. Define a typed list of entries with stable unique `id` and tagged `kind`.
   Initially implement `wireguard` and `system-interface`; reject unimplemented
   kinds rather than accepting raw sing-box JSON.
2. WireGuard entries reference whole-file encrypted credentials and compile to
   sing-box 1.14 `endpoints`. System-interface entries require an exact interface
   and compile to `direct` outbounds using `bind_interface`.
3. Define one valid `policy.default` and ordered manual `alternatives`. Validate
   references, duplicates, machine assignment and TCP/UDP suitability.
4. Generate stable tags, a blocking outbound and one top-level selector. Hide
   sing-box's endpoint/outbound split behind the compiler.
5. Move DNS ownership out of the WireGuard entry: selected application and proxy
   DNS must detour through the selector. Preserve host DNS only for resolving a
   tunnel endpoint hostname.
6. Decrypt only referenced credentials and keep keys out of Nix evaluation,
   argv, environment, logs and persistent storage. Document adding/retiring an
   entry without generalizing multi-machine policy.

## Constraints

- The current `laptop` and `desktop-ubuntu` behavior remains valid. Do not rename
  established identities for symmetry.
- Do not configure unused native WireGuard alternatives until their endpoint
  keepalive/on-demand behavior is deliberately accepted and tested.
- No controller, switching command, per-app routing or host interface creation
  in this ticket.

## Acceptance

- Existing single-WireGuard configurations build the same local proxy behavior.
- Fixture tests cover valid lists, duplicate IDs, invalid default/alternative,
  missing interface/credential, unimplemented kind and secret boundaries.
- Generated configuration passes the pinned sing-box checker and offers no
  unbound direct route.
- TCP, UDP and DNS remain tunneled on staging with one declared egress.
