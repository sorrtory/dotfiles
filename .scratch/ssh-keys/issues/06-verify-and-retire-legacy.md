# 06 — Verify on the new machine, then retire legacy material

Status: ready-for-human
Blocked by: 05

## Goal

Close the slice only after the operator has used the migrated setup on the new
machine, then retire what it replaces in that order, per working rule 10.

## Work

1. Treat commit `376ef7b`'s staging GitHub authentication and secret/store checks
   as implementation evidence, not as the final normal-use gate.
2. On the new machine, activate through the normal fresh-machine flow and use
   each migrated identity for its intended real destination. Record success
   without recording private host metadata in this public repository.
3. Exercise ticket 05's removal procedure with disposable material, never by
   deleting a working identity as a test.
4. Use the migrated setup normally for a period the operator judges sufficient.
   Working rule 10 asks for verification under normal use, which a single
   successful connection is not.
5. Only then retire the legacy material, and record what was retired.
6. Reconcile canonical documentation with the final result, then remove the
   completed `.scratch/ssh-keys/` directory in the completion commit.

## Constraints

- Do not delete the operator's existing keys as part of this slice's automation.
  Retirement is an operator action on their own material; this ticket prepares
  and verifies, and says clearly what is safe to remove.
- A key that turned out to be needed after being classified `drop` is a signal
  the classification rule in ticket 01 is wrong. Fix the rule, not just the key.

## Acceptance

- A real authentication succeeds using a migrated key on a fresh activation.
- The scans are clean.
- Legacy material retired only after the operator confirms normal use, with a
  record of what was removed.
