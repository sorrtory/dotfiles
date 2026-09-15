# Spec: selectable VPN egresses

Status: ready-for-agent

This milestone extends the shipped VPN command after vpn-command completes its
current repair and verification gates. It keeps one unprivileged sing-box
backend and the existing capture namespaces while making the backend egress a
small declarative and runtime-selectable interface.

## Model

- **Egress**: one allowed way for backend traffic to leave the machine. It has
  a stable ID and a tagged kind. Initial adapters are sing-box WireGuard and a
  direct outbound bound to an exact host tunnel interface.
- **Default egress**: selected at a new login/reboot and restored explicitly by
  `vpn-egress default`.
- **Alternative**: an allowed manual selection. It does not imply health
  checking, automatic failover or request retry.
- **Managed system tunnel**: a system-interface egress with optional `wg-quick`
  activation metadata. The host distribution still owns privileged networking;
  Home Manager only installs the user command and encrypted configuration.

The public Nix shape is a list so a machine may declare any number of entries:

```nix
dotfiles.vpn = {
  egresses = [
    {
      id = "main";
      kind = "wireguard";
      credential = "laptop";
    }
    {
      id = "system-wg";
      kind = "system-interface";
      interface = "laptop-system";
      activation = {
        kind = "wg-quick";
        credential = "laptop-system";
      };
    }
    {
      id = "v2rayn";
      kind = "system-interface";
      interface = "tun0";
    }
  ];

  policy = {
    default = "main";
    alternatives = [ "system-wg" "v2rayn" ];
  };
};
```

The exact option spelling may change during implementation for a materially
smaller interface, but the model and invariants above may not. Protocol details
remain inside each tagged entry; callers and applications use only the ID.

## Runtime interface

```text
vpn-egress list
vpn-egress status
vpn-egress use EGRESS
vpn-egress default
vpn-up [EGRESS]
vpn-down
vpn [--egress EGRESS] PROGRAM [ARGUMENT...]
```

`vpn-egress` is the supported selector interface. It uses sing-box's
authenticated loopback Clash controller internally and owns validation,
serialization and private runtime state. Raw controller calls are unsupported.
Selection survives a sing-box service restart, but runtime state disappears at
logout/reboot and selection returns to the declared default.

Selector changes interrupt existing TCP and UDP flows so they reconnect through
the new egress. Applications remain running, but an active call is allowed a
brief reconnect; seamless transport migration is not promised.

`vpn-up` manages only entries whose activation kind is `wg-quick`, permits at
most one managed system-wide tunnel, selects its interface-bound egress and
rolls back on failure where possible. With one managed entry its ID is optional;
with several it is required. `vpn-down` restores the default. Other
cores such as v2rayN own their lifecycle; the operator may select their declared
interface with `vpn-egress`, which fails closed while the interface is absent.

## Safety and routing

- The backend and managed system-wide WireGuard use distinct identities. Keep
  the established `laptop` backend identity; a new identity may be named
  `laptop-system`. One peer is never owned by two clients concurrently.
- No unbound direct egress is exposed. A missing/disappearing system interface
  blocks new traffic instead of using the ordinary host uplink.
- Transitions are serialized. Partial failure rolls back to the previous
  healthy state when possible and otherwise leaves affected traffic blocked
  with actionable status.
- DNS policy belongs to routing, not a WireGuard credential. DNS always follows
  the selected egress and must not retain today's hardwired `tunnel` detour.
- Every egress offered to VPNized apps supports their required TCP and UDP.
- Structural interface checks determine activation; diagnostics report tunnel
  health without making a public probe the sole definition of success.
- Secrets remain whole-file ciphertext and are parsed only at runtime. Only
  credentials referenced by the activated machine configuration are decrypted.

## Per-app behavior

A VPNized application follows the global selected egress by default. An
explicit egress pins it independently; absence of that egress fails closed and
never falls back to the global selection. The same milestone adds
`vpn --egress EGRESS` for one-off programs. Vesktop remains the only required
managed application; Element is a candidate when actually adopted.

Additional Electron/Chromium applications still require a declared exact-path
AppArmor allowance on restricted Ubuntu hosts. A generic privileged policy
grant or wildcard is outside this milestone.

## Deferred strategies and protocols

VLESS, TUIC and other native sing-box adapters wait for a real server transport
and credential. Automatic selection is also separate: sing-box 1.14 `selector`
is manual, while `urltest` chooses measured latency and does not implement
ordered fallback or retry a failed request through the next candidate.

## Verification

Use isolated fixtures first, then the staging VM with a disposable, uncommitted
system-wide identity and server peer. Verify TCP, UDP, DNS, IPv4/IPv6 fail-closed
behavior, backend restart, interface removal, partial transitions and unchanged
host routes outside managed `wg-quick`. Do not share a production peer with
staging or activate the host without explicit operator approval.

## Reference material

- `reference/vpn-veth-port.sh` is a non-live legacy reference only.
- The original `~/Documents/scripts/vpn.sh` remains external legacy evidence.
