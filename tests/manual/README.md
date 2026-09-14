# Application VPN integration test

Run only on a machine where the production `vpn-capture.service` has not been
installed. This test deliberately creates a temporary runtime user unit with
that name and removes it on exit. It needs rootless user/network namespaces,
a user systemd session, Python 3, jq, and sing-box 1.14 on PATH. No sudo, tunnel
credentials, public network access, or Home Manager activation is needed.

Set `VPN_TEST_LAUNCHER` to the built `vpn` executable, then run
`bash tests/manual/vpn_capture.sh`. Ports 15480 and 18453 must be unused.

The fixture backend maps a documentation-only destination to a localhost echo
server. This tests real IPv4/IPv6 TCP and UDP capture, command-symlink dispatch, multiple
application lifetimes, backend-stop failure, backend-restart recovery, and
last-application cleanup, and app termination on capture failure. It does not prove WireGuard transport, Discord voice,
or desktop sandbox compatibility; those require separate live checks.
