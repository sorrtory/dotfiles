# Concurrent VPN egress policy

Type: wayfinder:map

## Destination

A revised `.scratch/vpn-egress/spec.md` and implementation ticket map that can
support a runtime default egress, concurrent per-application egress pins, and
`vpn --egress` for one-off launches without weakening traffic confinement.
This map decides the design and migration order; it does not implement them.

## Notes

- Use `CONTEXT.md`, `docs/DECISIONS.md`, `.scratch/vpn-egress/`, and the
  `grilling`, `domain-modeling`, and `codebase-design` skills when resolving
  decisions.
- The user confirmed that Vesktop and AyuGram may use different egresses at
  the same time. An unpinned launch uses the runtime default, and
  `vpn --egress "name"` serves one-off launches.
- The former egress spec compiled one egress into one backend and deferred
  pinning. Its implementation map has now been rewritten for the concurrent
  runtime model.
- Local Markdown tracker: open tickets are under `issues/`; `Blocked by:`
  records dependencies. The first open, unblocked ticket is the frontier.
- [Rewrite the implementation spec and tickets](issues/13-rewrite-implementation-plan.md)
  closes the design map and identifies the first main implementation slice.

## Decisions so far

- [Define default and pinned egress behavior](issues/01-default-and-pins.md):
  `vpn-egress use` is temporary until reboot or Home Manager switch; it moves
  only unpinned entry points, while pinned routes stay selected.
- [Define failure and recovery for a pinned egress](issues/02-pin-failure.md):
  unknown or failed pins never fall back; `vpn-egress check NAME` is an explicit
  live diagnostic, with probes designed after topology.
- [Choose pin identifiers and policy ownership](issues/03-policy-identifiers.md):
  encrypted JSONC owns the named egress inventory and app/default policy;
  `vpn --egress` names a stable tag directly.
- [Set the credential residency constraint](issues/04-credential-residency.md):
  one unprivileged backend may load the whole inventory at runtime; per-egress
  process isolation is not required.
- [Establish sing-box routing options for concurrent egresses](issues/05-sing-box-capabilities.md):
  inbound routing supports a shared backend; DNS detours and credential
  residency remain explicit design constraints.
- [Choose the runtime and capture topology](issues/06-runtime-topology.md):
  one backend uses a manual selector for the default, direct named routes for
  pins, and one on-demand capture namespace per selected route, later proved
  by the synthetic fixtures.
- [Define the live egress check](issues/08-live-egress-check.md): one
  authenticated loopback Clash API controls the default selector and performs
  a named HTTPS reachability check; DNS and UDP belong to the topology proof.
- [Prove DNS and capture routing](issues/09-prove-routing-topology.md): a
  nonsecret local fixture confirmed concurrent HTTP, DNS, UDP, selector reset,
  and fail-closed capture routing; IPv6 switching and whole-host routing remain
  separate gates.
- [Define IPv6 behavior across default switches](issues/10-ipv6-switch-policy.md):
  default entry points stay IPv4-only across switches; named pins use their
  declared egress capability, later exercised on staging.
- [Prove whole-host TUN loop prevention](issues/11-whole-host-route-proof.md):
  a disposable Fedora VM confirmed the TUN-to-backend route, default switches,
  DNS hijack, fail-closed recovery, and IPv6 policy with synthetic egresses;
  SELinux blocked direct Nix `ExecStart`, but the full synthetic TUN later
  passed in a supervised root unit launched through host-labeled `/usr/bin/env`.
- [Define capture and pinned-app lifecycle](issues/12-capture-lifecycle.md):
  route-specific captures are shared by app scopes; compatible backend
  restarts leave apps in place, while a policy switch stops scopes whose pin
  or route definition changes before replacing the binding.
- [Order the VPN rewrite and module refactor](issues/07-migration-order.md):
  split app, capture and theme responsibilities first; replace `wg-quick`
  with a credential-free TUN on the old backend; then add the concurrent
  backend, runtime control and pins. Fedora staging proved a supervised root
  TUN service through host-labeled `/usr/bin/env`.
- [Rewrite the implementation spec and tickets](issues/13-rewrite-implementation-plan.md):
  the spec and ticket map follow that sequence. A later `to-tickets` pass
  split the refactor into tickets 01–03 and published the current dependency
  order in the [egress map](../vpn-egress/map.md).

## Remaining implementation gates

- Repeat the supervised Fedora TUN proof on the eventual generated config,
  then stage each implementation slice before separately approved host
  activation.
- Complete staging secret recovery before real-credential checks there, and
  gather real Vesktop/AyuGram and normal-use evidence on the host.

## Out of scope

- Implementing the VPN rewrite or activating a Home Manager generation.
- Automatic egress selection and health-based failover.
- Migrating additional applications into VPN capture.
