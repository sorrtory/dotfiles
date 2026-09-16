# 07 — Focus existing windows from application shortcuts

Type: task
Status: needs-info
Blocked by: none

## Goal

Application shortcuts must switch to an existing matching window, including
its workspace, and give it keyboard focus. Launch the application only when
no matching window exists. An “application is ready” notification alone does
not satisfy this requirement. The operator called this behavior a must-have
on 2026-09-16.

## Work

1. Verify Run or Raise's package in pinned Nixpkgs, GNOME 50 compatibility,
   configuration format, and window matching on Wayland. Upstream lists
   GNOME 50 support: https://extensions.gnome.org/extension/1336/run-or-raise/.
   Implementation documentation: https://github.com/CZ-NIC/run-or-raise.
2. Manage the extension and shortcut configuration through Home Manager,
   following existing ownership and native-config conventions. Remove
   conflicting media-key registrations for shortcuts it takes over.
3. Cover the existing application shortcuts in `modules/desktops/gnome.nix`,
   including Ctrl+Alt+T, Super+F, Super+K, and the other app launchers.
   Preserve Shift+F11 as an interactive screenshot action.
4. Match Super+K to the knowledge-base Obsidian vault and Super+N to private
   Notes, even when both are open. Preserve `vault notes` unlocking and
   failure handling when private Notes needs to be opened. Do not bypass
   the vault flow or match an arbitrary Obsidian window.
5. Define and document deterministic selection when multiple windows match.
   Use the extension's standard selection: recent matching window first,
   then cycle among matches when one is already focused. Repeated presses
   must not minimize matching windows. Preserve
   launch targets while deliberately replacing new-window behavior, such as
   Nautilus's current `-w`, with reuse of a matching existing window.

## Acceptance

- `nix flake check` and the activation package build pass.
- On the Ubuntu GNOME Wayland VM, after a real re-login for extension
  discovery, press the actual shortcuts and check focused window and active
  workspace through the desktop's control interfaces.
- Verify closed app, already visible window, minimized window, and window on
  another workspace. Existing-window cases create no extra window and need
  no notification click. Verify repeated presses and multiple matches.
- Verify both Obsidian vaults open at once and the private vault's locked
  opening flow, using disposable staging data rather than personal secrets.
- Verify the extension loads without errors and shortcut registration has
  no duplicates after another activation. Record app-specific limitations
  rather than claiming untested behavior.
- No host activation without explicit operator approval; use the GNOME VM,
  not the LXQt VM. Follow AGENTS.md and docs/STAGING.md.

## Answer

Implemented in `modules/desktops/gnome.nix` on 2026-09-16. The pinned
Nixpkgs package is Run or Raise 43 (upstream version-name 45), declaring
GNOME 45–50 support. No local package or upstream patch is needed.
The existing launcher table generates `shortcuts.conf`; media-keys retains
only Gradia. Match application identity, plus the final vault-name/version
suffix for Obsidian, rather than arbitrary text in window titles.

Notes deliberately uses `always-run`: focus its window and still invoke
`vault notes`, because a forced lock can leave an Obsidian window alive.
Other commands run only when no window matches. The standard upstream
multiple-window cycling behavior is documented in README.md.

### Verification

- `nix flake check` and `nix build .#homeConfigurations.z.activationPackage`
  passed after the final implementation. The generated dconf list contains
  only Gradia; the extension's generated file contains nine app shortcuts.
- `tests/vault_test.sh` passed using pinned util-linux's `script` on PATH
  and an isolated runtime directory. This is the existing stubbed command
  test, not a real encrypted mount check.
- The documented VM is unavailable: SSH to `192.168.122.242` reports no
  route to host, and this Fedora machine's system libvirt lists no domains.
- Used a disposable headless GNOME Shell 50.4 Wayland compositor instead,
  with its own D-Bus session, XDG directories, and test profiles under
  `/tmp/dotfiles-run-or-raise-test`. A temporary test-only probe allowed
  reading window identity/focus/workspace and injecting virtual keyboard
  events through Clutter. The production extension keeps its D-Bus feature
  disabled. No Home Manager host activation was performed.
- Actual shortcut presses restored and focused visible, minimized and
  other-workspace windows without creating extra windows for Ptyxis,
  Nautilus, Firefox, Code, Sublime, Spotify, and both Obsidian vaults.
  Repeated presses with one match retained focus. Two Nautilus windows
  verified recent-window selection and cycling. Closing both Files windows
  and pressing Super+E launched one focused window.
- Real Obsidian 1.13.4 windows use `md.Obsidian` on Wayland and titles such
  as `New tab - Notes - Obsidian 1.13.4`. Both disposable vaults were open
  simultaneously. A misleading note title mentioning the other vault was
  rejected by the final suffix matcher.
- The final Notes `always-run` action focused the real test Notes window
  and invoked a recording stand-in for `vault notes` on both presses,
  without creating windows. No FUSE device exists here, so actual encrypted
  unlocking could not be exercised in this compositor.
- Reloading the extension left nine registered accelerators and no
  extension error. The test compositor was stopped after verification.

### Remaining staging checks

Need the GNOME staging VM's reachable address/host, or its restoration by
the operator. Verify normal Home Manager activation and repeat activation,
a real re-login, AyuGram's VPN-backed launch/focus, and actual encrypted
Notes unlock/cancel/failure behavior. The private compositor lacks the
normal user systemd session: Ptyxis's window opened and focus worked, but
its terminal child failed, so it does not verify a usable terminal session.
Normal-use review and host activation remain with the operator.

## Comments

The current shortcuts execute application commands directly. Extension
compatibility is published upstream; this repository's pinned package and
the full requested workflow still need verification. This ticket records
the required behavior, not a claim that the implementation has been tested.
