# Selectable VPN egresses

Status: ready-for-agent

The [spec](spec.md) and [concurrent policy decisions](../vpn-policy-design/map.md)
define a temporary default, simultaneous named pins, one shared
credential-bearing backend and fail-closed capture. The implementation
tickets below are numbered in dependency order. A ticket can start when all
its blockers are complete. Host activation remains a separate operator
approval, and normal use precedes legacy retirement.

## Main tickets

| Ticket | Blocked by | What it delivers |
| --- | --- | --- |
| [01: AyuGram ownership](issues/01-ayugram-ownership.md) | None | AyuGram launcher and theme opt-in move out of shared VPN code with behavior intact. |
| [02: Vesktop and theme ownership](issues/02-vesktop-theme-ownership.md) | None | Vesktop launcher and palette integration have separate owners with behavior intact. |
| [03: Shared VPN runtime](issues/03-shared-vpn-runtime.md) | 01, 02 | The remaining core owns only `vpn` and capture. |
| [04: Whole-host TUN](issues/04-whole-host-tun.md) | 03 | `vpn-up` and `vpn-down` use a supervised credential-free TUN on the current backend. |
| [05: Native default inventory](issues/05-native-default-inventory.md) | 04 | Existing default traffic works from encrypted native JSONC. |
| [06: Concurrent backend routes](issues/06-concurrent-backend-routes.md) | 05 | One backend serves selector/default and independent named listeners. |
| [07: Runtime default control](issues/07-runtime-default-control.md) | 06 | `vpn-egress` switches, restores, reports and checks the temporary default. |
| [08: One-off named capture](issues/08-one-off-named-capture.md) | 06 | `vpn --egress NAME` launches a route-bound capture. |
| [09: Installed-app pins](issues/09-installed-app-pins.md) | 07, 08 | Vesktop and AyuGram pin concurrently; policy switches stop affected scopes. |
| [10: Real protocol egress](issues/10-real-protocol-egress.md) | 09 + deployed server | A real non-WireGuard route works end to end. |
| [11: Everyday recovery](issues/11-everyday-recovery.md) | 09 | Real network-change and suspend evidence on the daily machine. |
| [12: Legacy retirement](issues/12-retire-legacy-vpn.md) | 11 | Reviewed legacy VPN material is removed after normal use. |

Tickets **01–08, 13 and 14** are resolved. Ticket 06 uses the shared
`orange-vless` route while each machine keeps its own WireGuard peer. The VM
and separately approved daily host passed real concurrent-route checks.
Tickets 07 and 08 passed staging and daily-host cutovers. Ticket 10's server
and credential are now available, but its
full command and app checks still depend on ticket 09.

## Independent defects

- [13: AppArmor recovery](issues/13-apparmor-recovery.md) — no blockers, P2.
- [14: Relative executable paths](issues/14-relative-executables.md) — no
  blockers, P2.

These can be taken at any time without changing the main cutover order.
Automatic egress selection and additional sandboxed applications remain
deferred.

## Verification gates

The Fedora staging VM has proved the synthetic route topology, including a
full synthetic TUN configuration launched in a supervised root systemd unit
under SELinux Enforcing. The implementation must repeat the relevant checks
on each generated configuration. Real-credential staging checks await the
operator's secret-recovery phase. The daily host adds real application use
and network-change/suspend evidence after separately approved activations.
