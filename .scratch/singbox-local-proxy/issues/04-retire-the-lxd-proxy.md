# 04 — Retire the LXD proxy machinery

Status: ready-for-agent

Blocked by: 02

## Goal

Retire the legacy proxy from the material this repository is responsible for.
The operator is reinstalling the host from the bootstrap flow, so the
container and its snaps disappear with the reinstall; nothing here needs to
dismantle a running host.

## Work

1. Record the retirement in `docs/MIGRATION.md` under "Legacy retirement",
   naming what was replaced and by what: the `ssProxy` LXD container, both
   `shadowsocks-rust` ends, the derived bridge address, and the
   `init_bridge_proxy` shell helper with its `iptables` MASQUERADE rules.
2. Update `docs/SOFTWARE.md`: the `LXD` and `Shadowsocks` rows currently read
   as pending host setup. Both are retired outright — not deferred, not
   migrated. LXD has no remaining use once the proxy is gone.
3. Confirm nothing in this repository still references the legacy design:
   no `ssProxy`, no `SSSERVER_CONF` or `SSLOCAL_CONF` shape, no
   `VPN_CONTAINER_*` variable, no `lxdbr0`, and no `lxc` invocation.

## Constraints

- **Do not remove anything from the operator's current host.** Do not run
  `lxc delete`, do not remove the `lxd` or `shadowsocks-rust` snaps, do not
  drop the `lxd` group membership, and do not edit the legacy `scripts` or
  `configs` repositories. The operator retires all of it by reinstalling, and
  a fresh machine never has any of it. Verification happens on the staging VM
  through the normal bootstrap flow, where none of this legacy state exists
  in the first place.
- Do not delete the WireGuard profiles in `~/Documents/secrets/wireguard/`.
  Ticket 01 encrypts selected ones into this repository; the originals remain
  the operator's material.
- `snapd` itself stays. It is host-owned infrastructure with function this
  repository does not replace. The rule is a sourcing constraint recorded by
  `firefox-nix` ticket 04: nothing this repository declares comes from Snap.

## Acceptance

- On the staging VM, `sing-box` serves `127.0.0.1:1080` and
  `127.0.0.1:3128`, and no legacy proxy process exists to conflict with
  either — the VM was built by the bootstrap flow and never had one.
- `grep -rniE 'ssproxy|lxdbr0|ssserver|sslocal|VPN_CONTAINER' .` matches
  nothing outside `.scratch/` history and `docs/MIGRATION.md`'s retirement
  note.
- No canonical document describes LXD or Shadowsocks as planned, pending, or
  deferred.
- VS Code still works through the proxy after the change.
