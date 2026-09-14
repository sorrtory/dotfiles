# 03 — Install Vesktop and wrap its managed launch paths

Status: claimed
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

## Comments — Implementation

`dotfiles.vpnizedApps.vesktop.enable` (set in `home.nix`) installs a
`symlinkJoin` of Nixpkgs Vesktop whose `bin/vesktop` and `vesktop.desktop`
`Exec=` are replaced by a private launcher calling `vpn -- <raw vesktop>`.
The desktop ID, icons and `MimeType=x-scheme-handler/discord` are kept, and
Home Manager's desktop database maps `discord://` to `vesktop.desktop`. The
standalone package entry is removed.

`configs/vesktop/settings.json` is linked out of store; Vesktop saves settings
with a plain `writeFileSync`, which writes through the link. Close only quits
when `tray` or `minimizeToTray` is literally false. Activation seeds
`state.json` with `firstLaunch` once, because the first-launch tour resets
those settings and can enable an autostart entry that runs the raw Electron
command line, outside the VPN.

AppArmor profiles are generated from the package paths and installed by the
new `apparmor` bootstrap phase; activation warns when installed ones differ.
The generated attachments equal the hand-pinned paths proven on staging.
Built both configurations; phase, command and shellcheck tests pass. Launch
verification on a freshly bootstrapped VM is pending, after ticket 04.
