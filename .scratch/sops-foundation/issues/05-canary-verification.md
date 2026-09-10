# 05 — Verify decryption end to end with a canary secret

Status: resolved
Blocked by: 01, 02, 03, 04

## Goal

Prove the foundation works before any real secret depends on it. Nothing in
tickets 01–04 actually decrypts anything, so without this the first evidence
that sops-nix works would arrive in the middle of the WireGuard slice, mixed
with WireGuard's own failure modes.

Per `docs/MIGRATION.md` §"Method", a slice is verified by building on the host,
activating on the staging VM, and checking objectively there.

## Work

1. Create a canary secret under `secrets/` — non-sensitive, obviously
   disposable content — encrypted to the `.sops.yaml` recipient with `sops`.
   Confirm the gate from ticket 03 accepts it.
2. Declare it in `modules/secrets.nix` so activation materializes it. Note that
   `sops.defaultSopsFile` has no default value in the Home Manager module — it
   errors when accessed unset — so declaring a secret requires either setting
   that option or giving the secret an explicit `sopsFile`. Ticket 01 did not
   set it, because with no secrets declared nothing reads it.
3. On the host: `nix flake check` and
   `nix build .#homeConfigurations.z.activationPackage`.
4. Mirror to the staging VM and activate through the normal dispatcher, using
   the canonical commands in `AGENTS.md` §"Mirroring the working tree". Run the
   `rsync` with `-n` first: this slice adds `secrets/`, so the delete list is
   worth reading before it runs.
5. On the VM, check objectively:
   - the decrypted file exists at its declared path with the expected content;
   - its mode is not world-readable;
   - activation completed with no `sudo` prompt (working rule 7);
   - the plaintext is not in the Nix store — grep the store path of the
     activation package for the canary content and expect no match. This is
     the check that would catch the most damaging possible mistake.
6. Remove the canary — the ciphertext, its declaration, and the decrypted file
   on the VM — and re-verify that the host build still succeeds without it.
   The foundation ships empty; the canary is evidence, not a deliverable.
7. Present the result for operator review. Do not activate on the host and do
   not commit before approval.

## Constraints

- The canary is public test data by construction. Do not use real secret
  material to test the mechanism, even briefly.
- The VM is a mirror and never syncs back; every edit starts on the host.

## Acceptance

- Recorded evidence of each check in step 5, including the store-grep result.
- A clean host build after the canary is removed.
- `git status` shows no canary residue.

## Answer

Verified on the staging VM, which already held the identity matching `.sops.yaml`,
so no vault password was needed.

Evidence, in the order the ticket asks for it:

- The canary encrypted through the `.sops.yaml` creation rule to the configured
  recipient, which exercises those rules rather than assuming them.
- The ticket 03 gate accepted it: real ciphertext under `secrets/` passes, which
  is that ticket's allowed path confirmed against a genuine file.
- Host `nix flake check` and the activation build both succeeded.
- Mirrored with `-n` first. The delete list wanted an empty leftover
  `secrets/wireguard/` on the guest, which was inspected before being removed.
- Activation through the normal dispatcher succeeded and ran `Activating
  sops-nix`.
- The decrypted file matched the plaintext exactly, at mode `0400`, owned by the
  user, on tmpfs.
- `activate` contains zero occurrences of `sudo`.
- No plaintext in the store: scanned all 686 paths of the host closure and the
  whole generation closure on the VM, both clean. The store copy of the canary
  is ciphertext.
- Canary removed; the host build succeeds without it and the working tree
  matches `HEAD`.

One finding worth more than the canary itself: **undeclaring a secret does not
remove it from the machine.** After the canary was removed and the VM
reactivated, the decrypted file, its symlink directory, and a runtime copy of
the private age identity all remained, because sops-nix gates its entire config
block on a non-empty secret set and so goes inert rather than cleaning up. The
VM was cleaned by hand and the behavior is recorded in `docs/DECISIONS.md`,
since it makes secret removal and key rotation explicit work in the WireGuard
slice rather than a consequence of editing the module.
