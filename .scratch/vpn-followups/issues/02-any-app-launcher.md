# 02 — Add another sandboxed VPNized application

Status: needs-triage
Blocked by: 05

## Goal

Add exact-path host policy and a managed launcher for another application only
when it is actually adopted. Element is the current candidate. This is not the
ticket for `vpn --egress`, which belongs to 05 and continues to support ordinary
programs without an AppArmor allowance.

The ticket remains `needs-triage` until an actual second application is chosen.

## Sketch

1. Confirm the selected package actually creates a restricted user namespace;
   detect its real executable chain
   (Nix wrappers exec an unwrapped Electron), and explain the failure clearly
   instead of letting Electron abort with the `chrome-sandbox` error.
2. Reuse the vpn-command AppArmor generator and bootstrap phase to add exact-path
   allowances for a declared list of apps. Never a wildcard over `/nix/store`,
   and never `--no-sandbox`.
3. Prefer another explicit `dotfiles.vpnizedApps.<name>` adapter over a generic
   policy-grant list. Installing policy needs sudo and remains an explicit
   bootstrap action.
4. Give the app its native preferences/state treatment and global-or-pinned
   egress option through ticket 05's interface. Do not generalize from Vesktop
   assumptions that the second app does not share.

## References

See ../spec.md: `reference/vpn-veth-port.sh` and the operator's original
`~/Documents/scripts/vpn.sh`, whose history carries Discord screen-sharing
and DNS fixes worth rechecking against the namespace design.
