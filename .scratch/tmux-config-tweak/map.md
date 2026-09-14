# tmux configuration tweak

Clean up `configs/tmux/tmux.conf` after the native-configs slice moved it in
verbatim: fix copy-mode on X11, retire the two plugins that no longer earn
their place, and remove lines that only restate tmux 3.6 defaults or undo a
better one. See [spec.md](spec.md).

## Tickets

- [01: Grill the cleanup](issues/01-grill-the-cleanup.md) — ready-for-human.
- [02: Apply the cleanup](issues/02-apply-the-cleanup.md) — needs-triage; blocked by 01.

Deliberately two tickets. The proposal is one coherent edit to one file, and
its open questions are judgments for the operator rather than work to divide.

## Context

- Follows [`native-configs`](../native-configs/map.md) ticket 02, which kept
  everything outside the plugin section verbatim on purpose. This effort is
  where the file itself gets reviewed.
- Every "default" claim in the spec was read from a tmux 3.6 server started
  with `-f /dev/null` on a private socket, and every claim about tmux-sensible
  from its store copy (`tmuxplugin-sensible-unstable-2022-08-14`), not from
  memory.
- Retiring continuum amends `native-configs` spec baseline 3, which names
  "resurrect/continuum" as how sessions survive a reboot.
- The copy-chain defect also makes a sentence in `docs/DECISIONS.md` and
  `docs/MIGRATION.md` §12 wrong: they say the tmux chain chooses its tool by
  session type, and it chooses by which command exists.
