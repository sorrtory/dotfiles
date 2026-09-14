# 01 — Grill the GNOME baseline

Type: grilling
Status: resolved

## Goal

Settle the spec's open questions with the operator, so tickets 02 to 05 are
mechanical.

## Work

1. Answer each question under "Open questions" in [spec.md](../spec.md).
2. For every row in the spec's drift tables, mark the host value keep, drop,
   or change.
3. Pick the verification venue (question 7) before ticket 02 starts.

## Constraints

- The keyboard behavior itself is the operator's stated requirement. Only its
  representation and the exact XKB option are open.
- `preferred-monitor-by-connector='eDP-1'` is machine-specific. Keeping it
  needs a reason that holds on other hardware.

## Answer

Operator, 2026-09-15.

- **Target.** Nothing here will be switched on the current PC. It is
  evidence only. The target is a fresh Ubuntu install on a new PC, and the
  goal is the experience the current PC has now. That makes moving existing
  extension directories aside, and cleaning up `custom0` and `custom1`, a
  non-issue.
- **Representation.** Use declarative `dconf.settings`, and have Home Manager
  own the launchers and the extension list.
- **Launchers.** Keep all eight, renaming `custom0` → `gradia` and
  `custom1` → `telegram`. Global Nix apps are fine for GNOME: put the Home
  Manager profile's `bin` on the session `PATH` through
  `systemd.user.sessionVariables`, and keep launcher commands as plain names.
- **Extensions.** Use `programs.gnome-shell.extensions` with
  `targets.genericLinux.enable = true`, so the profile's `share` reaches the
  session's `XDG_DATA_DIRS`. Declare Ubuntu's default extensions too, which
  makes the enabled list complete.
- **Keyboard.** Keep `caps:escape_shifted_capslock`, and keep `<Super>space`
  alongside Alt+Shift.
- **Verification.** The operator will add an Ubuntu GNOME VM later. Until
  then, check builds and dconf output. Normal use is on the new PC.
- **Defaulted, not asked.** Because "the same experience" is the target,
  `ding` stays disabled, hide-top-bar 124 from Nixpkgs is accepted over 125,
  and GUI tweaks to managed keys are overwritten on switch. Revisit any of
  these if they turn out wrong.
- **Still open.** `targets.genericLinux` enables `targets.genericLinux.gpu`
  by default, and the existing decision rejects it. Whether to keep
  `gpu.enable = false` is raised with the operator, because Code, Obsidian and
  Spotify already come from Nix and `docs/DECISIONS.md` assumes MPV is the
  only GPU consumer.
- **Drift tables.** Mutter, dock and appearance rows are not settled yet,
  and ticket 04 re-asks them.
