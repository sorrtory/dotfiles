# 05 — Add per-app and one-off egress selection

Status: ready-for-agent
Blocked by: 04

## Goal

Allow a VPNized application or one invocation of `vpn` to select a declared
egress without changing the global selection.

## Interface

```nix
dotfiles.vpnizedApps.vesktop = {
  enable = true;
  egress = null; # null follows the global selector; an ID pins the app
};
```

```text
vpn [--egress EGRESS] PROGRAM [ARGUMENT...]
```

## Work

1. Give the backend a private routing seam that capture instances can address by
   egress ID without learning protocol details. Preserve one credential-owning
   backend; do not create a WireGuard connection per app.
2. Null/default applications follow subsequent global selector changes. A named
   application egress remains pinned and fails closed if unavailable; it never
   silently follows global selection.
3. Add `--egress` to the existing command with unambiguous option parsing and
   validation. Without it, preserve today's command and global behavior.
4. Keep one on-demand capture per effective routing target where sharing is
   safe. Cleanup of one target must not stop applications using another.
5. A running Vesktop on one pinned egress refuses a launch request for another
   rather than handing it to the wrong singleton. Terminal, desktop and URL
   launches preserve the declared policy.

## Acceptance

- Test global-following, pinned, one-off, invalid and unavailable selections.
- Simultaneous applications on the same/different egresses have correct TCP,
  UDP and DNS; last-user cleanup and backend restart do not cross-stop them.
- Capture failure remains fail-closed and scoped to affected applications.
- Vesktop remains the required managed app. Element support is a separate
  declared application change when adopted; no generic AppArmor grant is added.
