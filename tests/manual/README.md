# Manual tests

These need a real environment that the automated tests deliberately stub out.

## VM creation and reboot

Run on a disposable libvirt host after `vm-create NAME` succeeds:

```bash
bash tests/manual/vm-create.sh NAME
```

This reboots only the named guest. It checks its live reboot policy, verifies
that the boot ID changes and the guest returns, and tests user/root key access,
passwordless sudo, services, the guest agent and refusal of password-only SSH.
For a SPICE desktop guest it also waits for the user's GNOME session to return
unlocked after reboot, with automatic screen locking disabled.
Supply a second argument containing another IPv4 address assigned to the host
to also check that UFW rejects SSH originating outside the permitted NAT gateway.
For the Fedora staging host that argument is `192.168.122.21`.
`VM_CREATE_TEST_USER` and `VM_CREATE_TEST_IDENTITY` override the default host
username and server SOPS identity when the guest was created with another pair.

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
