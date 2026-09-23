# Prove whole-host TUN loop prevention

Type: wayfinder:prototype
Status: resolved
Blocked by: 09, 10

## Question

Using a disposable staging VM or an isolated equivalent, prove that a
credential-free whole-host sing-box TUN can forward through the default
backend listener while backend upstream sockets stay on the physical route.
Exercise `vpn-egress use` while the TUN is up, simultaneous named capture
traffic, backend restart, and provider failure. Observe the actual egress and
route state, including DNS, LAN/libvirt access, and whether any direct fallback
or TUN loop occurs. Check both IPv4-only and IPv6-capable policy chosen in
[Define IPv6 behavior across default switches](10-ipv6-switch-policy.md).

Do not activate a generation on the daily host. Record what was measured and
on which machine; an unavailable staging VM is an explicit unverified gate.

## Answer

The disposable Fedora 44 staging VM at `192.168.122.21` ran the nonsecret
[whole-host TUN prototype](../prototype-staging-tun.py) with sing-box 1.14.1
on 2026-09-23. Its root TUN held only a SOCKS outbound to a temporary user
backend. The backend used two synthetic direct outbounds explicitly bound to
`enp1s0` and a blocked outbound. These are fixture egresses, not production
VPN routes or provider credentials. The local [routing prototype](../prototype-routing.py)
also ran on the VM with a synthetic IPv6-capable named egress.

Observed on staging:

- With the TUN up, `ip route get` selected `vpnproof0` for a public IPv4
  destination and retained `enp1s0` for the SSH/LAN gateway. A normal HTTPS
  request completed; TUN and backend logs showed its SOCKS hop and bound
  physical outbound. This establishes no routing loop for the tested path.
- The root TUN's DNS hijack made systemd-resolved choose `vpnproof0` and its
  synthetic DNS address for `~.`. An ordinary `resolvectl query` returned over
  that link. Direct queries to the TUN resolver returned an A answer and no
  AAAA answer under the IPv4-only default policy.
- Switching the default selector from synthetic A to B kept whole-host HTTPS
  working. A concurrent named capture continued through B. Selecting a blocked
  default made whole-host HTTPS fail while the named capture still worked.
  Stopping the backend made whole-host HTTPS fail; restarting it restored both
  whole-host and named-capture HTTPS without restarting the TUN.
- A synthetic native IPv6 default route was added temporarily. The route to a
  public IPv6 test address still selected `vpnproof0`, and an IPv6 HTTP request
  failed immediately under the default reject rule. The gateway answered ping,
  and the VM's libvirt bridge address stayed on its local route.
- In the separate synthetic fixture, the default capture and local proxy
  returned no AAAA answer and rejected an IPv6 literal even after selecting
  IPv6-capable B. The named B capture returned AAAA and carried IPv6; its
  direct named listener did too.

The first staging attempts exposed a VM-specific SELinux constraint: a
transient root systemd unit could not execute Nix's `default_t` store binary
(status 203/EXEC). Direct `sudo` execution worked and was supervised by a
65-second timeout and cleanup. This does not invalidate routing, but the
eventual `vpn-up` implementation cannot assume `systemd-run` can execute the
Nix binary on Fedora without an explicit host integration remedy. Record that
remedy in the migration order, keeping Home Manager activation unprivileged.

The scripts removed their temporary processes, TUN, routes, and runtime files.
The uploaded scripts and public-password sudo helper were removed. A final
readback showed no `vpnproof0`, the original `enp1s0` default route and
`192.168.122.1` DNS server, and the pre-existing user sing-box service active.

The evidence proves the selected routing topology with synthetic egresses on
this staging VM. It does not establish that any specific provider credential
works or that the eventual generated production configuration is correct;
those remain implementation verification work.

## Supervised full-config follow-up, 2026-09-23

The same nonsecret [whole-host TUN fixture](../prototype-staging-tun.py) was
run again on Fedora 44 staging with SELinux Enforcing, this time launching
its **full synthetic TUN configuration** as a transient root systemd service:

```text
sudo systemd-run --unit=vpn-proof-tun --collect --property=Type=exec \
  --property=RuntimeMaxSec=65 /usr/bin/env /nix/store/…/sing-box run -c TUN_CONFIG
```

The backend, TUN and named-capture configs passed `sing-box check`. The root
unit started and `vpnproof0` appeared. `ip route get` chose `vpnproof0` for
public IPv4 and `enp1s0` for the staging gateway. Public HTTPS returned 204
through the TUN; the gateway responded to ping, and the libvirt bridge stayed
local. The TUN resolver returned an A answer and no AAAA answer, while
`resolvectl query` reported `vpnproof0` as its DNS link. The Clash API changed
the synthetic default from A to B while whole-host HTTPS and the B named
capture worked. Selecting the blocked default made whole-host HTTPS fail
immediately while the named capture continued. Stopping the backend also
made whole-host HTTPS fail; restarting it restored both paths without
restarting the root TUN unit. A temporary native IPv6 default route was
captured by `vpnproof0`, and an IPv6 request failed under the reject rule.

`systemctl stop vpn-proof-tun.service` removed `vpnproof0`. Final readback
showed public IPv4 using `enp1s0`, no synthetic IPv6 default, the original
`192.168.122.1` resolver, and the pre-existing user `sing-box.service`
active. The temporary fixture and askpass helper were removed from staging.
This closes the Fedora supervised-launch topology proof. The fixture uses
synthetic direct outbounds bound to the physical interface, so the generated
production config and real provider credentials remain implementation gates.
