# Prove DNS and capture routing

Type: wayfinder:prototype
Status: resolved
Blocked by: 06, 08

## Question

Build a throwaway, nonsecret proof of the selected topology before finalizing
the implementation spec. Can one backend with two dummy egresses serve a
manual default selector, a direct named route, and concurrent on-demand
capture namespaces without DNS or application traffic crossing routes?

Exercise a default switch while a named capture remains running. Observe the
actual route through control interfaces or test endpoints, including DNS and
IPv4/IPv6 behavior, rather than relying on generated config inspection alone.
Exercise the authenticated loopback Clash API for a selector change and for a
direct named HTTPS check, including a WireGuard endpoint tag if available in
the nonsecret fixture. Confirm sing-box does not retain a temporary selector
choice across the intended reset.
Show that unknown names, missing named listeners, and unreachable routes fail
closed. Check the credential-free whole-host forwarding path for loops and
direct fallback without activating a Home Manager generation on the daily
host. Use temporary files and disposable namespaces or staging, then clean
them up. Record any sing-box or Linux constraint that changes the chosen
topology.

## Answer

The throwaway [routing prototype](../prototype-routing.py) ran on the current
Fedora host on 2026-09-23 with sing-box 1.14.1, two local mock SOCKS egresses,
one backend, a default capture namespace, and a named capture namespace. The
fixture generated a temporary TLS certificate and control token, used no
provider credentials, and removed its runtime files and processes afterward.
It did not activate Home Manager or change host routes.

Observed through the applications' network namespace and the mock egresses:

| Probe | Default capture | Named B capture |
| --- | --- | --- |
| HTTP before switch | A | B |
| DNS A answer before switch | `127.0.0.41` via A | `127.0.0.42` via B |
| UDP echo before switch | A | B |
| HTTP, DNS, UDP after selecting B | B | B, still pinned |
| IPv6 when configured IPv4-only | Connection failed | Connection failed |

The authenticated Clash API returned 401 without its bearer token, 200 for a
named B HTTPS URLTest, 404 for an absent tag, and 204 for the manual selector
change. With no cache file, a backend restart restored selector A. A capture
pointed at an absent backend listener failed HTTP and DNS. When mock egress B
stopped accepting connections, named HTTP failed and UDP timed out; mock A
received no fallback requests. With the backend stopped, the default capture
also failed HTTP. These are observations from the synthetic fixture, not
evidence about a real provider or the final wrapper's exit codes.

This establishes the core concurrent capture and route-selection seam for
IPv4-only egresses, including application UDP and DNS carried through the
selected egress. Two conditions surfaced that require separate proof or a
policy decision before the implementation spec is final:

- [Define IPv6 behavior across default switches](10-ipv6-switch-policy.md):
  the default capture is long-lived, while its resolver strategy and address
  family may depend on the selected egress.
- [Prove whole-host TUN loop prevention](11-whole-host-route-proof.md): the
  local namespace fixture proves credential-free TUN-to-SOCKS forwarding, but
  does not put the backend and a whole-host TUN under the same host routes.
  The staging VM at `192.168.122.21` returned `No route to host` on this run.

The selected topology remains provisional until both follow-up gates are
resolved. The prototype script is deliberately nonproduction scratch material.
