# Define the live egress check

Type: wayfinder:grilling
Status: resolved
Blocked by: 06

## Question

Given the chosen runtime topology, how should `vpn-egress check NAME` invoke
sing-box's built-in URLTest for exactly the named outbound or endpoint? The
pinned 1.14.1 Clash API has `GET /proxies/{name}/delay`, while the native API
CLI exposes group URL tests; compare those control surfaces and their access
control before enabling one. A `urltest` outbound that automatically selects
another egress is not the explicit named check.

Define the wrapper's output, timeout and exit status, distinguishing an
unknown name, a stopped local backend, and an unreachable provider. URLTest
proves an HTTPS-over-TCP path only; decide whether DNS and UDP need separate
checks, and how any such checks use the named egress without host resolution
or direct fallback. The command is a manual diagnostic, not a required
preflight for every launch.

## Comments

Initial fact finding on the pinned 1.14.1 release:

- The [Clash API's named `/proxies/{name}/delay` handler](https://raw.githubusercontent.com/SagerNet/sing-box/v1.14.1/experimental/clashapi/proxies.go)
  invokes sing-box URLTest on exactly the looked-up outbound; the outbound
  manager also finds endpoint tags. The handler returns delay on success,
  HTTP 404 for a missing tag, 504 on timeout, and 503 for another probe failure.
- The installed native CLI's `api group urltest <group>` starts a group test
  and says results appear later, so it does not directly return the result for
  one named egress. The [selector documentation](https://sing-box.sagernet.org/configuration/outbound/selector/)
  says the Clash API controls selectors. One authenticated Clash API can thus
  serve both `use NAME` and `check NAME`.
- [URLTest](https://raw.githubusercontent.com/SagerNet/sing-box/v1.14.1/common/urltest/urltest.go)
  makes an HTTPS HEAD request to `https://www.gstatic.com/generate_204` by
  default. Its successful response establishes an HTTPS-over-TCP path through
  that outbound, not application DNS or UDP confinement.
- The [Clash API configuration](https://sing-box.sagernet.org/configuration/experimental/clash-api/)
  supports a loopback listener and bearer secret. Its selector choice is
  persisted when `cache_file.enabled` is set, which conflicts with the chosen
  reboot reset unless selection persistence is disabled or explicitly cleared.

## Answer

Use one local Clash API for both manual default selection and the named live
check. Bind it to loopback only, require a bearer secret, leave the web UI
disabled, and keep private-network access disabled. Generate the control secret
at runtime and keep it in user-only runtime files with mode 0600; neither the
secret nor egress credentials enter Nix evaluation, argv, the environment,
logs, or the Nix store. The command wrapper reads the secret itself and sends
the header from process memory. It validates names against the decrypted
inventory before calling the API, and URL-encodes the selected name.

`vpn-egress check NAME` calls `GET /proxies/{NAME}/delay` with sing-box's
default HTTPS test URL and a 5000 ms probe timeout. Give the local client a
slightly longer overall timeout. On success, print the name, `reachable via
HTTPS`, and the returned delay in milliseconds; exit 0. Give distinct
diagnostics and nonzero statuses for an unknown inventory name (2), stopped or
unreachable local backend (3), named probe timeout or failure (4), and usage,
authentication, or unexpected API errors (1). A name present in the inventory
but absent from the running backend is a configuration mismatch, not an
unknown inventory name. No result silently changes the active default or a
pin.

The check means that an HTTPS-over-TCP request through this named outbound or
endpoint succeeded at that moment. It is an operator-invoked diagnostic, not
an app-launch gate or automatic failover. The separate topology proof checks
DNS and UDP confinement, IPv4/IPv6 behavior, and routing under concurrent
captures. Do not claim that this HTTPS probe establishes those properties.

Selector choices must remain temporary: disable sing-box's selected-outbound
cache, or explicitly prevent its `cache_file` setting from persisting the
selection, and ensure Home Manager switch restores the declarative default.
