# Spec: sing-box local proxy

Status: ready-for-agent

## Why

`docs/MIGRATION.md` §5 calls for recreating WireGuard configurations as
whole-file SOPS ciphertext with user-owned decryption. The legacy repository
implements the browser-facing half of that as an LXD container.
`install.sh setup_external_proxy` launches an Ubuntu container named
`ssProxy`, pushes plaintext `.conf` files into its `/etc/wireguard/`, runs
`wg-quick` and a `shadowsocks-rust` `ssserver` inside it, and pairs that with
a second `shadowsocks-rust` process on the host translating SOCKS5/HTTP into
the container.

Measured on the host while writing this spec:

- The container carries a full Ubuntu 24.04 rootfs with its own `systemd`,
  `systemd-resolved`, `systemd-networkd`, `sshd`, `snapd` and `core22`, to
  host one WireGuard interface and one proxy process.
- Both shadowsocks ends run `method=none`. The second hop encrypts nothing;
  it exists only to bridge into the container.
- `ssserver` binds the shared LXD bridge with no authentication, so every
  other container on `lxdbr0` has an open tunnel into the VPN.
- A third process, a host-side `ssserver` that `snap services` reports as
  `inactive`, holds 13 MB and listens on nothing.
- `mode: tcp_and_udp` is configured but unreachable from the only client:
  Firefox has never implemented SOCKS5 UDP ASSOCIATE, and disables HTTP/3
  when a proxy is set.

One userspace process replaces all of it, needs no privilege, and reads the
same ciphertext the `vpn` command will read.

## Scope

In scope:

- A Home Manager module running `sing-box` as a systemd **user** service,
  exposing a single `mixed` inbound (SOCKS5 + HTTP) on `127.0.0.1:1080`.
- WireGuard as a userspace `endpoint` (`"system": false`, gVisor netstack) —
  no kernel module, no TUN, no routing or resolver changes, no `sudo`.
- The first real ciphertext under `secrets/wireguard/`: whole-file
  `.conf` SOPS secrets, one per device, shared with the future `vpn` command.
- Pointing Firefox and VS Code at the proxy.
- Deleting the legacy container, its snaps, and its setup code.

Out of scope:

- Anything that makes the proxy system-wide. The value of this design is that
  `apt`, `nix` and every CLI keep going direct.
- The netns `vpn` command (`MIGRATION.md` §7). It stays, with a boundary
  recorded in ticket 03.
- Firefox packaging and the PAC file's encryption and delivery. Those are the
  separate `firefox-nix` effort; this effort only points a pref at the PAC
  where it already sits.
- UDP proxying. No client in use needs it.

## Verified on the staging VM

Built from the pinned nixpkgs (`sing-box` 1.13.19), `desktop-ubuntu` profile,
port 1080, as an unprivileged systemd user service:

| Check | Result |
| --- | --- |
| `curl` direct | the host's own ISP address |
| `curl --proxy socks5h://127.0.0.1:1080` | the VPN egress address |
| `curl --proxy http://127.0.0.1:1080` | the VPN egress address |
| WireGuard links / TUN links while running | `0` / `0` |
| Default route, `/etc/resolv.conf`, `ip rule` | unchanged |
| Listening sockets | `tcp 127.0.0.1:1080` only |
| `archive.ubuntu.com`, `cache.nixos.org` | `200` throughout, direct |
| Resident memory | 43 MB (legacy stack: ~109 MB) |
| Stop, then check for residue | port gone, no links, route and resolver identical |
| 240 s hypervisor freeze, then resume | recovered on the first probe, 1 s, `NRestarts: 0` |

The freeze test is why no resume hook is specified: `persistent_keepalive_interval`
plus WireGuard's own handshake retry recover unaided. A hypervisor freeze does
not reproduce a network change across suspend, so that case remains unverified;
if it misbehaves the fix is a `Restart=` nudge, not a design change.

## Design decisions

Settled by grilling before any code was written:

- **Coexist with the netns `vpn` command**, boundary recorded in
  `docs/DECISIONS.md`: sing-box is the always-on per-app proxy for anything
  speaking SOCKS/HTTP; `vpn` is whole-app tunneling for what cannot.
- **Whole-file encrypted `.conf`**, per `MIGRATION.md` §5, not fields split
  between Nix and SOPS. Two mechanisms are only tolerable sharing one source
  of truth; splitting guarantees drift the first time a peer is re-issued.
  The cost is that the sing-box config is generated at service start rather
  than at evaluation time; ticket 01 mitigates that with `sing-box check` in
  `ExecStartPre` and a generator test.
- **One `mixed` inbound on 1080.** A PAC `PROXY host:port` directive means an
  HTTP proxy, and `mixed` answers both protocols on one port, so the existing
  PAC needs no edit.
- **Linger enabled.** Suspend does not end a session, so linger is not about
  suspend; it keeps the proxy up across logout and before login. It is safe
  here only because the SOPS identity is an age keyfile — a GPG identity would
  make sops-nix wanted by `graphical-session-pre.target` and leave a lingering
  pre-login service nothing to decrypt with.
- **No `urltest` failover yet** (ticket 05). A group with one member is
  theater, and a second member pointing at a server that does not exist is an
  untested path.
- **No rollback path.** The flow is dedicated to fresh bootstrap, so ticket 04
  deletes the legacy machinery outright rather than keeping it dormant.

## Tickets

See [map.md](map.md).
