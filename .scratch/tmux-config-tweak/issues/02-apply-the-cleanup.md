# 02 — Apply the cleanup

Type: task
Status: needs-triage
Blocked by: 01

## Goal

Apply the proposal as settled by ticket 01, in one change.

## Work

1. Edit `configs/tmux/tmux.conf` per the settled proposal.
2. Remove the retired plugin links from `modules/programs/tmux.nix`.
3. Update the documentation listed under the spec's Scope, including the
   copy-chain sentence and `native-configs` spec baseline 3.

## Constraints

- Verify against tmux on a private socket, never the operator's running
  server; continuum's hook and sensible both behave differently there.
- Keep the comments that still describe a line.

## Acceptance

The spec's Definition of done.

## Comments
