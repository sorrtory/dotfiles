# 01 — Module-owned lifecycle and simplification

Status: resolved
Blocked by: 00

## Goal

Replace the provisional dotfiles.appVpn interface with vpnizedApps, reusing the
tested sing-box capture implementation. Follow [the updated spec](../spec.md).

## Work

1. Create modules/programs/vpnized-apps/default.nix with the selected
   dotfiles.vpnizedApps.vesktop.enable interface. No selected apps means no app
   package, launcher or capture activation; do not implicitly disable the
   separately selected local proxy.
2. Move private namespace-entry and capture-config helpers beside this module.
   Update packaging, imports and tests; remove superseded provisional helper
   locations once references are migrated. Preserve the legacy vpn.sh.
3. Keep only necessary runtime glue. Replace generic CLI dispatch with generated
   app launchers, consolidate redundant delegation, and keep lifecycle management
   with systemd. Do not replace readable shell with large embedded Nix strings.
4. Preserve on-demand capture sharing, last-app cleanup, backend restart
   independence and dependent-app termination when capture fails. Never start a
   second WireGuard peer or add host routes/firewall state.
5. Check required sing-box features and rootless host prerequisites with clear
   errors. Do not introduce implicit sudo or change host namespace policy.
6. Adapt the existing lifecycle regression test to the shared private launch
   implementation; retain multicall executable/symlink behavior coverage.

## Acceptance

- Only one application-capture implementation remains, with private helpers not
  exposed as global user tools.
- Module-disabled and module-enabled evaluations build; no host activation.
- TCP/UDP, concurrent scopes, backend restart, capture failure and cleanup tests
  still pass after simplification.
- Generic vpn CLI is not required or expanded in this ticket.

## Answer

Done. `modules/programs/vpnized-apps/` owns capture: `default.nix`, the private
`enter.sh` and `capture-config.sh`. The provisional `dotfiles.appVpn` and its
`scripts/bin/vpn-*` helpers are gone. Per the operator, the user-facing one-off
command stays: `scripts/bin/vpn.sh`, provided whenever the local proxy is
enabled; managed launchers (ticket 03) call it. Capture is on-demand, so this
adds no running service.

The command is packaged without runtime inputs and reaches `vpn-enter` and
`systemd-run` by absolute path, so programs resolve on the caller's PATH and
receive it unchanged; the prototype leaked helper inputs into the payload's
PATH. The ineffective exe-path singleton check and the `discord` alias were
removed; ticket 04 replaces the check with a namespace comparison.

`dotfiles.localProxy.profile` is now `dotfiles.vpn.identity`, with no default.
`home.nix` names `laptop`; the flake's `staging` configuration forces
`desktop-ubuntu`. The `home-manager` bootstrap phase builds
`DOTFILES_HOME_CONFIGURATION` (default `z`) and remembers it, so later runs on
the VM do not revert to the host's identity.

Verified on the host (restriction off): both configurations build and select
the expected ciphertext; `tests/vpn_command_test.sh`,
`tests/vpn_capture_config_test.sh`, `tests/bootstrap_home_manager_test.sh` and
the phase checker pass; `tests/manual/vpn_capture.sh` passes every stage with
the built command, including a new check that the payload keeps the caller's
PATH without launcher variables. No activation anywhere.
