# 06 — `vault notes` opens the private notes in Obsidian

Status: ready-for-agent

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
