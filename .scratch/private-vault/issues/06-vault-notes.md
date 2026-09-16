# 06 — `vault notes` opens the private notes in Obsidian

Status: resolved

Blocked by: 02, 04

## Goal

`vault notes [path]` takes the operator from a locked vault to their private
notes in one step: mount, then open `Notes/` as an Obsidian vault kept separate
from the knowledge database.

## Work

1. Implement `vault notes [path]` on top of the mount behaviour from ticket 04,
   including the reuse of an already-verified mount.
2. Create `Notes/` inside the mount on the first successful invocation after
   mounting. Initialization does not create it; this command does.
3. Open that directory as an Obsidian vault, and handle what ticket 02 found
   about an instance already running and about first-time vault registration.
4. Register the resulting process with the command's bookkeeping, so ticket
   05's lock owns it and can ask it to close.
5. Keep the two Obsidian collections distinct: the private notes and the
   knowledge database are separate vaults, and opening one must not disturb
   the other.

## Constraints

- Obsidian's vault registration and window state are machine-local session
  state, not declarative configuration.
- Obsidian reaches the network through its own per-process proxy setting, as
  the decision log requires. This ticket does not change that.
- No automatic mounting: `vault notes` mounts because the operator asked for
  notes, never in the background.

## Acceptance

- From locked, one invocation ends with the private notes open in Obsidian on
  the GNOME VM.
- The first invocation creates `Notes/`; later ones reuse it.
- With the knowledge database already open, the private notes open as a second,
  separate vault, and the knowledge database is unaffected.
- `vault lock` afterwards recognizes the Obsidian process as its own.

## Answer

Done, ahead of its blocker, because the operator asked for `<Super>n` to open
the private notes and that needs this command. `vault notes PATH` unlocks the
vault the same way `open` does, creates `Notes/` on first use, and opens it in
Obsidian by URI as a second vault beside the knowledge database.

Verified on the host through `tests/manual/vault.sh`: `Notes/` is created
inside the mount on first use and its name does not appear in the ciphertext.

Ticket 02 is still worth running. What it would have told this ticket in
advance, and what remains unverified here, is Obsidian's behaviour when an
instance is already running and what first-time registration of a vault inside
a mount asks for. Neither is checked on a desktop yet.
