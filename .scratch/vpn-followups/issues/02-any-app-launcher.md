# 02 — `vpn` for sandboxed (Electron/Chromium) apps

Status: needs-triage
Blocked by: vpn-command/06

## Goal

`vpn obsidian` (or any Electron/Chromium app) should work one-off, not only
programs that avoid user namespaces.

## Sketch

1. Detect the userns restriction and the program's real executable chain
   (Nix wrappers exec an unwrapped Electron), and explain the failure clearly
   instead of letting Electron abort with the `chrome-sandbox` error.
2. Reuse the vpn-command AppArmor generator and bootstrap phase to add exact-path
   allowances for a declared list of apps. Never a wildcard over `/nix/store`,
   and never `--no-sandbox`.
3. Consider a declarative list (`dotfiles.vpn.sandboxedApps`) rather than
   granting policy from an interactive command, since installing needs sudo.

## References

See ../spec.md: `reference/vpn-veth-port.sh` and the operator's original
`~/Documents/scripts/vpn.sh`, whose history carries Discord screen-sharing
and DNS fixes worth rechecking against the namespace design.
