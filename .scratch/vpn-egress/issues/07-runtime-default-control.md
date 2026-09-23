# 07: Control and check the temporary default

Status: ready-for-agent
Blocked by: 06 (concurrent backend routes)

**What to build:** Give the operator `vpn-egress` to list named routes,
temporarily switch the active default, restore the declarative default and
run a focused named HTTPS reachability check. A reboot or Home Manager switch
restores the hostname's declarative choice.

- [ ] `use NAME` changes proxy, default capture and whole-host traffic
      together without restarting named captures; unknown names leave the
      prior selection intact.
- [ ] `status` reads back the actual selector choice and reports temporary
      versus declarative state; list shows safe inventory notes without
      printing credentials.
- [ ] `check NAME` uses the backend's named HTTPS probe with a five-second
      timeout and distinct unknown-name, backend, probe and control errors.
      It does not claim to prove DNS or UDP and does not gate launches.
- [ ] The loopback-only control API requires a runtime user-only bearer
      secret; no API token or VPN credential enters Nix, argv, environment,
      logs or the store. Selector state is not persisted across reboot.
- [ ] Staging observes switch, reset, API refusal and fail-closed behavior
      before a separately approved host activation.
