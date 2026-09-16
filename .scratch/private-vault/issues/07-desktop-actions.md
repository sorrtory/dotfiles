# 07 — The vault from the desktop, with no terminal

Status: resolved

Blocked by: 05, 06

## Goal

The operator unlocks, opens and unmounts the private vault from the GNOME
session itself, with a graphical password prompt and a keybinding, without
ever opening a terminal.

## Work

1. Add a graphical password dialog for desktop-launched actions, selected at
   invocation by whether a terminal is actually there rather than by a flag the
   operator has to remember. The terminal prompt stays for terminal use.
2. Point `<Super>n` at the private notes action instead of the bare Obsidian
   launcher, so the existing muscle memory now unlocks first.
3. Provide desktop actions for opening the vault in the file manager and for
   unmounting it, reachable without a terminal.
4. Make the desktop path report failures and blockers visibly. A dialog that
   vanishes silently on a wrong password or a blocked unmount is a bug.
5. Verify on the Ubuntu GNOME VM after a real re-login, since the session only
   reads some of this at login.

## Constraints

- The dialog never persists the password and never writes it anywhere.
- Cancelling the dialog cancels the action and leaves the vault as it was.
- The desktop unmount action uses the same lock behaviour as ticket 05,
  including its confirmation before anything risky. It is not a shortcut past
  the blockers report.

## Acceptance

- `<Super>n` on a locked vault prompts graphically and ends with the private
  notes open.
- `<Super>n` on an already-unlocked vault opens the notes without prompting.
- A wrong password and a blocked unmount both produce a visible message in the
  session, not just on a stream nobody is reading.
- The unmount action leaves no mount and no owned process behind.

## Answer

Done, in pieces, as the operator asked for each part.

- The graphical password dialog is gocryptfs's own `-extpass`, running zenity.
  It is used when there is no terminal and a session to draw in, never in
  preference to a terminal. `--terminal` and `--dialog` force either.
- `<Super>n` runs `vault notes ~/Vault`, which is the one place that
  convention is written down.
- Failures are visible from a keybinding: every error goes to the terminal
  when there is one and to a zenity error dialog when there is not. A wrong
  password says so by name, because gocryptfs exit 12 is distinguished from
  the rest. Cancelling the password dialog is gocryptfs exit 9, treated as an
  answer rather than a failure and reported without a popup.

Not done: a desktop action for unmounting. `vault lock` exists and works from
a terminal, but nothing in the session invokes it, and locking is where a
dialog matters most, since it is the case that asks a question. That wants its
own ticket rather than being quietly folded in here.
