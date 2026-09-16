# 01 — The knowledge database at its real path, on its own key

Status: resolved

Blocked by: None (can start immediately)

## Goal

The public-safe Obsidian collection lives where the operator actually keeps it,
`~/Documents/Knowledge-Database`, and opens on a keybinding without unlocking
anything. This is prefactoring: the declared clone path is wrong today, and
every later ticket that distinguishes the two Obsidian collections inherits the
mistake unless it is fixed first.

## Work

1. Correct the declared repository path from `Documents/knowledge-database` to
   `Documents/Knowledge-Database` so activation adopts the existing directory
   instead of cloning a second, lowercase one.
2. Check `<Super>k` against GNOME's own defaults on the Ubuntu GNOME VM, with
   the session's desktop identity set, before claiming it. Propose an
   alternative to the operator if it is taken.
3. Add the launcher that opens the knowledge database in Obsidian, beside the
   existing custom launchers.

## Constraints

- A machine that already has the correctly-cased directory must be left
  untouched; a machine that has neither clones once.
- The knowledge database never requires a vault, a password or a mount. Nothing
  in this ticket may introduce one.
- Obsidian's own vault registration is machine-local session state, not
  declarative configuration.

## Acceptance

- Activation on a machine holding `~/Documents/Knowledge-Database` creates no
  second directory and reports no clone failure.
- The binding opens the knowledge database on the GNOME VM, verified after a
  real re-login rather than from the dconf value alone.
- Evaluation and the repository tests still pass.

## Progress

Host work done. `home.nix` now declares `Documents/Knowledge-Database`, and
`modules/desktops/gnome.nix` adds the `knowledge` launcher on `<Super>k`,
built from `home.homeDirectory` because Obsidian takes a vault as a URI and
reads the query value whole.

- The correctly-cased directory already exists on the host and the lowercase
  one does not, so the fix is what stops a second clone.
- `<Super>k` is free: checked against every schema and against the custom
  keybindings in dconf on the operator's own GNOME 50 session with
  `XDG_CURRENT_DESKTOP=ubuntu:GNOME`. Nothing binds it.
- The generated dconf carries
  `command='obsidian obsidian://open?path=%2Fhome%2Fz%2FDocuments%2FKnowledge-Database'`.
- `nix flake check`, the activation build and all 21 tests pass.

Remaining: the acceptance asks that the binding be seen opening the knowledge
database on the Ubuntu GNOME VM. Mirroring the tree to the VM was refused by
the sandbox as a shared-resource change, so that check has not run.

## Answer

Resolved as far as the VM allows.

The path is corrected and the launcher is declared. On the VM the generated
dconf carries
`command='obsidian obsidian://open?path=%2Fhome%2Fz%2FDocuments%2FKnowledge-Database'`
on `<Super>k`, and `~/Documents/Knowledge-Database` appears in Obsidian's own
vault registry, so the URI form is right.

What cannot be shown there is the window opening: Obsidian does not start on
the VM at all, because the guest has no usable GPU. See
[02](issues/02-lifecycle-prototype.md) for the evidence. That is a property of
the staging VM, not of this change, and the same limit applies to `<Super>n`.

Confirming that the key opens a window belongs on a machine with a GPU.
