# Spec: selectable VPN egresses

Status: ready-for-agent

One unprivileged sing-box backend keeps serving the local proxy and the VPN
command. This milestone makes the way out of that backend a selectable egress
rather than the machine's single WireGuard identity, adds the protocols a
WireGuard-only design cannot carry, and replaces the `wg-quick` whole-host
tunnel with one that follows the same selection.

It supersedes `.scratch/vpn-followups/`, retired in the commit that created
this directory. That spec declared egresses in Nix, dispatched them through
repository-owned protocol adapters, switched them live over sing-box's Clash
controller and kept `wg-quick` for the whole-host tunnel. Each of those is
reversed below. Its text remains in Git history.

## Model

- **Egress**: one selectable way for backend traffic to leave the machine,
  named `<provider>-<location>-<protocol>-<name>`, for example
  `vdsina-nl-wg-laptop`. The name is the tag sing-box uses.
- **Active egress**: the one egress the backend is currently compiled against.
  Exactly one exists at a time and every entry point shares it.
- **Default egress**: the egress a machine selects when no runtime choice is
  saved, named per hostname inside the encrypted policy.
- **Entry point**: the local proxy, the VPN command's capture namespace, or
  the whole-host TUN. Traffic is split by entry point before it reaches the
  backend; the backend itself carries no routing policy.

An egress is not bound to a device. Any machine may select any egress, which
is what makes a failing tunnel recoverable by picking another. The cost is
accepted deliberately: every machine holds every credential, so one
compromised machine exposes all of them, and the operator is responsible for
never running two clients on one WireGuard peer at the same time, because the
server's peer endpoint roams between them.

## Storage

Two whole-file SOPS documents under `secrets/vpn/`, replacing
`secrets/wireguard/`:

- `egresses.jsonc` is a sing-box configuration fragment and nothing else: real
  `endpoints` and `outbounds` arrays with their tags, exactly as sing-box
  would take them. `sing-box check` validates the file directly, provider
  JSON can be pasted in unchanged, and `//` comments carry the operator's
  notes — which provider, which account, when it expires — so no separate map
  file exists to fall out of date.
- `policy.jsonc` carries what sing-box has no field for: the default egress
  per hostname, and the egresses whose server has no IPv6.

Both are ciphertext, so no provider, location or protocol name appears in the
repository. Nothing in `home.nix` names an egress either; the machine finds
its default by hostname. sing-box 1.14.1 accepts `//` comments but rejects
unknown fields, which is why the operator's data lives in a second file rather
than beside each entry.

Plain `wg-quick` configurations for devices that do not run sing-box are the
operator's own backups, kept outside this repository.

## Runtime interface

```text
vpn-egress              # list egresses with their notes, marking the active one
vpn-egress status       # the active egress and where the choice came from
vpn-egress use EGRESS   # switch
vpn-egress default      # clear the saved choice
vpn-up                  # whole-host tunnel on the active egress
vpn-down
```

Switching recompiles the configuration for the newly selected egress and
restarts the backend. There is no selector group and no Clash controller: the
backend holds one egress at a time, credentials for unselected egresses never
enter the running configuration, and no local control port exists for another
process to find. The cost is that switching interrupts existing flows, which
is acceptable for a manual action and is the same interruption a backend
restart already causes.

The saved choice lives in the user's state directory and survives reboots; the
default applies only when nothing is saved. A saved egress that no longer
exists falls back to the default with a warning rather than failing to start.

## Whole-host tunnel

`vpn-up` starts a second, credential-free sing-box as a transient system unit
under `sudo`. Its only outbound is SOCKS to the backend on loopback, so it
follows whatever egress is active and holds no keys. This replaces `wg-quick`,
the whole-host WireGuard interface, the identity handover marker and the
keyless backend restart that went with them.

Verified constraints:

- The backend binds its own upstream sockets to the physical interface
  (`route.auto_detect_interface`), so its traffic to the VPN server is not
  captured by the TUN and does not loop. Unprivileged `SO_BINDTODEVICE` has
  been allowed since Linux 5.7.
- `strict_route` stays off, because with it on, interface-bound traffic is
  redirected back through sing-box.
- A systemd user service cannot hold `CAP_NET_ADMIN`, so the TUN process is
  privileged and the backend is not. The privileged half has no credentials.
- All six current WireGuard endpoints are IP literals, so no name has to be
  resolved before the tunnel exists. The host-DNS bootstrap exception is
  deleted rather than narrowed. An egress that needs a hostname later resolves
  it over DoH to a fixed address, dialed direct.

While the backend restarts, the TUN's SOCKS connection is refused and traffic
fails rather than falling back to the host uplink. With the tunnel down, the
host's direct connection is the ordinary state and nothing blocks it.

## Invariants

- No unbound direct outbound is ever compiled into the backend or the TUN.
- Tunneled traffic fails closed. Nothing falls back to the host uplink because
  an egress is missing, a restart is in progress or an interface disappeared.
- DNS follows the active egress. No entry point resolves through the host
  resolver.
- Credentials are parsed only at runtime and never reach Nix evaluation,
  argv, the environment, logs or the Nix store.
- Private and link-local ranges stay off the whole-host tunnel, which also
  keeps the libvirt bridge and the staging VM reachable.

## Documentation

Each slice rewrites the decisions it reverses, in the commit that reverses
them. `docs/DECISIONS.md` currently states that each machine uses its own
WireGuard identity, that only that identity is decrypted, that `wg-quick`
brings up the whole-host tunnel and that resolving a WireGuard endpoint
hostname is the sole host-DNS exception. `CONTEXT.md` defines **VPN identity**,
which this milestone retires in favour of **egress**.

## Verification

Fixtures first, then the staging VM: generated configuration validates,
the tunnel comes up from the new files, `vpn-egress` switches and the choice
survives a reboot, the whole-host TUN carries traffic through the backend,
traffic fails rather than leaks while the backend restarts, and LAN plus the
libvirt bridge stay reachable. The host adds only what needs real applications:
Vesktop and AyuGram through capture while the whole-host tunnel is up. Host
activation stays a separate operator approval.

## Deferred

- **Per-app and one-off egress pinning** (`vpn --egress`, a pinned VPNized
  app). It needs a routing seam inside the backend, which contradicts the
  split-before-the-backend model until there is a reason to pay for it.
- **Automatic selection.** `urltest` measures latency and does not do ordered
  failover or retry; ordered failover would be repository-owned health and
  retry logic. Not before two real egresses have everyday use behind them.
- **Additional sandboxed applications.** Unchanged: each needs an exact-path
  AppArmor allowance and is added only when actually adopted.
- **A double tunnel is accepted.** With the whole-host tunnel up, a VPNized
  application's traffic still goes through capture's namespace and reaches the
  same single egress twice over. The overhead is small, and the alternative —
  making the launcher behave differently depending on invisible state — would
  silently put an application on the direct connection after `vpn-down`.

## Reference material

- `reference/vpn-veth-port.sh` is a non-live legacy reference only.
