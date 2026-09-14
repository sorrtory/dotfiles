# 03 — Install Vesktop and wrap its managed launch paths

Status: ready-for-agent
Blocked by: 01, 02

## Goal

Enabling dotfiles.vpnizedApps.vesktop.enable installs Vesktop and makes ordinary
launches use capture without typing vpn.

## Work

1. Use the pinned Nixpkgs Vesktop package; inspect its executable wrapper,
   desktop entry ID, actions, icons and supported URL schemes. Keep package
   ownership with the module, not duplicated in modules/packages.nix.
2. Generate the normal vesktop command, desktop entry and applicable URL handler
   through the same private namespace-entry implementation. Preserve arguments,
   URL escaping, desktop metadata and working directory. Avoid wrapper recursion
   by retaining the package executable path internally.
3. Start capture on demand, not Vesktop at boot. Check that a pre-existing native
   desktop entry cannot silently take precedence over the managed entry; report
   conflicting host integration without uninstalling it automatically.
4. Preserve the real session environment and required display, audio and portal
   access, normal user identity and zero payload capabilities. Document deliberate
   proxy-environment changes. Do not disable Electron sandboxing.
5. Keep login/session data machine-local. Do not migrate/delete profiles or sign
   in automatically. Test the Nix package rather than assuming the earlier native
   /opt/Vesktop probe is equivalent.
6. Verify disabled/enabled module outputs. Disabling removes managed wrapping,
   not session data or unrelated host packages; document any legacy entry that
   becomes visible again.

## Acceptance

- The selected option installs Vesktop once and exposes its normal launch paths.
- Terminal, desktop and URL launches reach the expected namespace as the user.
- Arguments, URL handoff, audio and desktop integration work.
- The raw executable bypass is documented; this is routing, not a hostile-app
  security sandbox.
