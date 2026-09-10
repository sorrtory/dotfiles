# 05 — Make key removal and rotation explicit

Status: ready-for-agent
Blocked by: 04

## Goal

Give rotation and removal a procedure that actually removes the key.

## Why

Verifying the SOPS foundation turned up that undeclaring a secret does not
remove the copy already on the machine: sops-nix gates its whole configuration
on a non-empty secret set, so deleting the last secret makes the module inert
rather than making it clean up. `docs/DECISIONS.md` records this.

For WireGuard that is untidy. For SSH it is worse, because rotating a key is
something one does *in response to a suspected compromise*, and the failure mode
is a revoked private key still sitting readable in tmpfs while the configuration
says it is gone. Someone doing the right thing under pressure would reasonably
believe they had removed it.

## Work

1. Write the procedure: what to change in the repository, what to run to clear
   the materialized copy, and how to confirm the key is gone from the machine.
2. Cover the case that matters — removing one key while others remain — and the
   case that exposed the behavior, removing the last one.
3. Decide whether this belongs as a documented manual procedure or as a small
   command. Prefer a command if the manual steps are easy to get half-right.
4. Test it on the staging VM: materialize two keys, remove one, and verify the
   other still works while the removed one is actually absent — including from
   the runtime directory, not just from the configuration.
5. State the rotation order explicitly. Registering the new public key before
   revoking the old one is what keeps the operator from locking themselves out.

## Acceptance

- Removal verified to clear the runtime copy, not just the declaration.
- Removing one key demonstrably does not disturb the others.
- The procedure is written where someone would look for it under pressure, not
  only in a commit message.
