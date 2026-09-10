# 02 — Prove OpenSSH accepts a sops-nix key

Status: ready-for-agent

## Goal

Answer the question the whole design rests on, before any real key depends on
the answer: can OpenSSH actually use a private key that sops-nix materialized?

Use a throwaway key generated for this ticket. No real material.

## Why this is first

The foundation puts decrypted secrets on tmpfs at mode `0400`, reached through a
symlink under `~/.config/sops-nix/secrets`. The plan is to point `IdentityFile`
at that path rather than write plaintext into `~/.ssh/`. That is stated in
`docs/MIGRATION.md` as something to verify, not as a known fact, and OpenSSH is
notoriously strict about key files.

If it does not work, the alternatives — writing plaintext to `~/.ssh/`, or
loading via `ssh-agent` at login — are materially different designs, and it is
much cheaper to learn that now than halfway through migrating real keys.

## Work

1. Generate a throwaway keypair. Encrypt the private half to the `.sops.yaml`
   recipient and declare it as a secret.
2. Activate on the staging VM.
3. Establish, with evidence:
   - whether OpenSSH accepts the key through the symlink path;
   - whether mode `0400` satisfies its permission check;
   - whether it objects to the file living outside `~/.ssh/`;
   - whether the `sops-nix` user unit has materialized the key by the time a
     login shell would want it, or whether there is a startup ordering gap.
4. If it does not work, record what OpenSSH actually objected to and evaluate
   the alternatives against the "no plaintext on disk" baseline.

## Constraints

- The throwaway key is public test data by construction. Destroy it afterwards
  and do not register its public half anywhere.
- Do not weaken the tmpfs property to make the test pass. If plaintext on disk
  is the only thing that works, that is a finding to report, not a decision to
  make quietly.

## Acceptance

- A recorded answer, with the commands and their output.
- If the symlink approach works, the exact `IdentityFile` form that worked.
- If it does not, a comparison of the alternatives against baseline 2 in the
  spec.
