# 06 — Verify under normal use, then retire the legacy material

Status: ready-for-agent
Blocked by: 03, 04, 05

## Goal

Prove the migrated setup works for real, then retire what it replaces — in that
order, per working rule 10.

## Work

1. On the staging VM, from a fresh activation: connect to at least one real host
   with a migrated key using a non-mutating check such as `ssh -T`. Building the
   files is not evidence that authentication works.
2. Confirm the agent-facing invariants hold on the VM: no plaintext key on disk,
   nothing added to the Nix store, activation still free of `sudo`.
3. Exercise the ticket 05 procedure once more on the final configuration.
4. Use the setup normally for a period the operator judges sufficient. Working
   rule 10 asks for verification under normal use, which a single successful
   connection is not.
5. Only then retire the legacy material, and record what was retired.
6. Update `docs/SOFTWARE.md`'s OpenSSH row and `docs/MIGRATION.md` §6 to describe
   what shipped.

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
