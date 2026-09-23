# 07: Control and check the temporary default

Status: claimed
Blocked by: 06 (concurrent backend routes)

**What to build:** Give the operator `vpn-egress` to list named routes,
temporarily switch the active default, restore the declarative default and
run a focused named HTTPS reachability check. A reboot or Home Manager switch
restores the hostname's declarative choice.

- [x] `use NAME` changes proxy, default capture and whole-host traffic
      together without restarting named captures; unknown names leave the
      prior selection intact.
- [x] `status` reads back the actual selector choice and reports temporary
      versus declarative state; list shows safe inventory notes without
      printing credentials.
- [x] `check NAME` uses the backend's named HTTPS probe with a five-second
      timeout and distinct unknown-name, backend, probe and control errors.
      It does not claim to prove DNS or UDP and does not gate launches.
- [x] The loopback-only control API requires a runtime user-only bearer
      secret; no API token or VPN credential enters Nix, argv, environment,
      logs or the store. Selector state is not persisted across reboot.
- [x] Staging observes switch, reset, API refusal and fail-closed behavior
      before a separately approved host activation.

## Staging evidence

The Fedora staging VM activated the generated controller with a private
runtime token. An unauthenticated API request returned HTTP 401. The named
VLESS HTTPS check passed. Switching the default to VLESS changed the live
selector, proxy HTTPS and default capture HTTPS both returned 204, and
`default` restored the declarative WireGuard route. An unknown name returned
exit 3 without changing the active VLESS choice. Backend restart reset the
choice to the declarative default; backend stop made `status` return exit 6.
With the whole-host TUN up, switching to VLESS kept public HTTPS on
`vpn-host0` and default capture HTTPS working; restoring WireGuard returned
204. A transient named WireGuard probe failed once during that check, then
passed both with and without the TUN. `vpn-down` restored the direct route and
the staging sudo helper was removed. Daily-host activation remains a separate
approval gate.
