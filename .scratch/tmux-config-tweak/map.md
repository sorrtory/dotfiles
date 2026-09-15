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

- Follows the closed `native-configs` effort (`docs/MIGRATION.md` §11; its
  tickets are in Git history), which kept everything outside the plugin
  section verbatim on purpose. This effort is where the file itself gets
  reviewed.
- Every "default" claim in the spec was read from a tmux 3.6 server started
  with `-f /dev/null` on a private socket, and every claim about tmux-sensible
  from its store copy (`tmuxplugin-sensible-unstable-2022-08-14`), not from
  memory.
- Retiring continuum changes the `docs/SOFTWARE.md` tmux plugins row, which
  names saving and restoring sessions, and `docs/MIGRATION.md` §11, which
  leaves continuum's save hook to this effort.
- The copy-chain defect also makes a sentence in `docs/DECISIONS.md` and
  `docs/MIGRATION.md` §12 wrong: they say the tmux chain chooses its tool by
  session type, and it chooses by which command exists.
