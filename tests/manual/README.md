# Manual tests

These need a real environment that the automated tests deliberately stub out.

## Application VPN integration test

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

## Private vault

Needs the host's setuid FUSE helper, `script(1)` and the built `vault`
executable. No sudo, no activation and no access to the operator's real vault:
it creates a throwaway one under a temporary directory and unmounts it on exit.
It unsets `DISPLAY` and `WAYLAND_DISPLAY` deliberately: a file manager opened on
the test vault holds the mount and stops the test cleaning up after itself.

Set `VAULT_TEST_COMMAND` to the built `vault` executable, then run
`bash tests/manual/vault.sh`.

It checks real initialization on a pty and the refusal without one, a real
mount, that plaintext is readable through the mount and absent from the
storage, that a second open reuses the mount instead of stacking one, that the
runtime record names the process actually holding the mount, and that a wrong
password is refused. `tests/vault_test.sh` covers the path rule and every
refusal that needs no real filesystem.
