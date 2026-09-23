# Spec: selectable VPN egresses

Status: ready-for-agent

This is the **target design**. The installed system still uses one per-machine
WireGuard identity; [DECISIONS.md](../../docs/DECISIONS.md) and the README
describe that current baseline until each migration slice lands. The
[implementation map](map.md) orders the change, and the
[policy map](../vpn-policy-design/map.md) preserves the decisions and proofs.

## The picture

One unprivileged sing-box backend loads every egress assigned to its host.
It has one manually selected **active default** and direct listeners for
named routes. Entry points choose their route before traffic reaches the
backend; a named route never passes through the default selector.
An egress is a named route. Shared outbounds may be used by every machine with
the inventory; each WireGuard peer is assigned to one hostname and is loaded
only there, so its server endpoint cannot roam between clients.

| Entry point | Backend path | IPv6 |
| --- | --- | --- |
| Local HTTP/SOCKS proxy | Default listener → manual selector | Always off |
| `vpn PROGRAM` | On-demand default capture → default listener | Always off |
| `vpn --egress NAME -- PROGRAM` | On-demand named capture → listener for `NAME` | Per named egress policy |
| Installed app with a pin | Its named capture → listener for the pinned name | Per named egress policy |
| `vpn-up` | Privileged, credential-free whole-host TUN → default listener | Always off |

The active default applies only to unpinned traffic. `vpn-egress use NAME`
changes it until reboot or Home Manager switch; either event restores the
hostname's **declarative default**. An explicit `--egress` overrides an
installed app's pin, which overrides the active default. Vesktop and AyuGram
may therefore use different named egresses concurrently while the proxy and
whole-host TUN use another. Existing connections may reconnect after a
default switch; named captures do not change route.

## Inventory and policy

Two whole-file SOPS ciphertext documents are the source of truth:

- `secrets/vpn/egresses.jsonc` contains native sing-box `endpoints` and
  `outbounds`, tagged with stable names such as
  `<provider>-<location>-<protocol>-<name>`. `//` comments hold safe operator
  notes. There is no repository-owned protocol adapter or separate alias map.
- `secrets/vpn/policy.jsonc` contains declarative defaults by hostname,
  WireGuard peer owners, installed-app pins, and named egress IPv6 capability. Every reference must
  name an inventory tag; an absent hostname default or unknown pin is an
  error. No egress name or pin goes in a Nix expression.

sing-box can check the native inventory directly, then the runtime compiler
checks the combined backend configuration. Secrets are read only at runtime:
no credential or API token enters Nix evaluation, arguments, the environment,
logs, patches or the Nix store. Each backend holds credentials for all routes
available to its host, even inactive routes. The decrypted inventory still
contains every peer, so compromise of either machine could expose both peers.
An owner map prevents the backend from starting another host's WireGuard peer;
the same peer must not run on two clients at once or its server endpoint would
roam. Old `wg-quick` use ends before the concurrent backend starts.
The backend never has an unbound direct fallback. Current WireGuard and VLESS
server addresses are IP literals. The compiler rejects hostname servers until
they can bootstrap through fixed-address DoH bound to the physical route
rather than host DNS.

## Commands and failure behavior

```text
vpn-egress              list names and safe notes; mark the active default
vpn-egress status       read back the active and declarative defaults
vpn-egress use NAME     temporarily select the default
vpn-egress default      restore the declarative default now
vpn-egress check NAME   run one named HTTPS reachability check
vpn --egress NAME -- PROGRAM
vpn-up / vpn-down       start / stop the whole-host TUN
```

One loopback-only authenticated Clash API controls the manual selector and
performs `GET /proxies/{NAME}/delay`. The bearer secret lives in a user-only
runtime file and the selector choice is not persisted in sing-box's cache.
`check` uses a five-second HTTPS HEAD probe; it reports unknown name,
unavailable backend, failed probe and control error separately. It does not
gate launches or prove DNS, UDP or future connectivity.

An unknown explicit name or invalid pin fails before launch. A configured
egress that later becomes unreachable leaves its app on the same route with
failed connections; it may reconnect when that route recovers. No entry point
falls back to the default or host network because a route, backend, capture
or listener fails. Backend DNS detours follow each selected route, and no
tunneled application DNS uses the host resolver. Default-route DNS resolves
IPv4 only, capture/TUN DNS returns no AAAA answers, and all default entry
points reject IPv6 packets even when the chosen egress supports IPv6. A
named capture follows its declared capability.

## Capture and policy switches

Each `vpn` launch owns a user systemd app scope bound to a capture service
for its resolved route. Scopes on one route share that capture; its last
scope's exit stops it. Capture failure stops bound scopes and payloads,
including apps that move their main process to another scope. A backend
restart with compatible route definitions leaves captures and apps in place
to reconnect; traffic is blocked during the outage.
Installed app launchers cover ordinary commands, desktop entries and links;
launching a package's raw executable can bypass the wrapper. This routing
mechanism is not an application sandbox, and login/session state stays local.

A Home Manager switch validates the new inventory and policy before replacing
runtime bindings. It stops an installed app scope whose pin changes or is
removed. If a named route disappears or changes definition or IPv6 policy,
it stops **all** scopes on that route, including one-off launches, before
replacing the listener. A pin-only change does not stop an old capture still
used by another scope. Each stop reports the app, old route and reason.
Listener addresses cannot be reassigned to another tag while a capture is
live. A private runtime binding record reserves removed tags' ports until
reboot, when no capture from the prior session can survive. Readback compares
the app's route, capture namespace PID/inode and
backend listener binding, and distinguishes an attached route from a backend
outage or mismatch. Failed reconciliation cannot silently reroute an app.

## Whole-host TUN

`vpn-up` explicitly starts a supervised root sing-box TUN whose only outbound
is SOCKS to the backend's default listener. It holds no provider credentials.
The backend binds its upstream sockets to the physical interface using
`route.auto_detect_interface`, preventing a loop; `strict_route` stays off.
The TUN hijacks DNS so the host resolver follows it, excludes private and
link-local routes to keep LAN/libvirt reachable, and rejects IPv6 default
traffic. If the backend stops, whole-host traffic fails closed. After
`vpn-down`, the host's ordinary direct connection resumes. Normal Home
Manager activation never invokes sudo.
The whole-host TUN does not change a VPNized app's capture route. Apps stay
inside capture while it is up, so `vpn-down` cannot release them onto the
host connection.

Fedora 44 SELinux denied a root transient unit that executed the Nix binary
directly. A supervised root unit starting through host-labeled `/usr/bin/env`
ran the **full synthetic** TUN configuration, including routing, DNS,
selector changes, backend loss and cleanup. The generated production config
must pass the same check, and other distributions must use a working
host-labeled executable path. The fixture used synthetic physical-bound
egresses, not real provider credentials. See the
[staging proof](../vpn-policy-design/issues/11-whole-host-route-proof.md).

## Migration and evidence

The [tickets](map.md) first split app, theme and shared VPN responsibilities
without behavior changes. They then replace `wg-quick` with the TUN on the
current backend; move the current default to encrypted native inventory;
load concurrent routes; add default control and one-off named captures; and
finally add installed-app pins and policy reconciliation. Each active cutover
keeps the local proxy, default capture and whole-host path usable. Host
activation needs separate operator approval; legacy machinery is removed
only after normal use proves its replacement.

The [local routing proof](../vpn-policy-design/issues/09-prove-routing-topology.md)
and [Fedora staging proof](../vpn-policy-design/issues/11-whole-host-route-proof.md)
established synthetic TCP, UDP, DNS, selector, IPv6 and fail-closed routing.
They do not validate generated production config or any real provider.
Staging's secret-recovery phase remains the operator's prerequisite for
real-credential checks there. The daily host adds real Vesktop/AyuGram use,
network-change and suspend evidence after approved activations.

Automatic selection and health-based failover remain deferred. A real
non-WireGuard egress is a separate `needs-info` ticket until a server and
credential exist. More sandboxed applications are added only when adopted.
