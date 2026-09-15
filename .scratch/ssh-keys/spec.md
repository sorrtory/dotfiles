# Spec: SSH keys and configuration

Status: ready-for-agent

## Progress

Tickets 01–04 shipped in `376ef7b`; `66c7f9a` records the host-owned SSH-agent
decision. Rotation/removal remains ticket 05. Ticket 06 is intentionally a
new-machine normal-use gate owned by the operator, followed by explicit legacy
retirement and removal of this completed scratch effort.

## Why

`docs/MIGRATION.md` §6. SSH material was originally classified as machine-local
and left out of the migration entirely. That is reversed: private keys are
reproducible secrets, because a fresh machine should reach the same hosts and
produce the same signatures without re-registering a public key everywhere
first, and because a signing key cannot be regenerated — replacing it
invalidates every signature already made under it.

`docs/DECISIONS.md` records the risk that reversal accepts.

## Sequencing

WireGuard is §5 and comes first. It establishes the whole-file ciphertext
conventions and the privileged-deployment boundary; this slice reuses them
rather than inventing its own. Ticket 02 is the exception and can run at any
time, because it uses a throwaway key and answers a question that decides
whether the rest of the design is viable at all.

## Scope

In scope:

- Selected SSH private keys as whole-file SOPS ciphertext.
- `~/.ssh/config` and public keys, split between plain repository material and
  ciphertext. The repository is public, so host names, login names and ports are
  not credentials but still must not be published; see ticket 03.
- An explicit procedure for rotating and removing a key.

Out of scope:

- Server-side authorized_keys management. This slice provisions the client.
- The `gh` credential and other mutable sessions, which `CONTEXT.md` already
  classifies as machine-local and which recovery deliberately leaves alone.
- Migrating a key whose purpose nobody can state. That is a removal candidate,
  not a migration candidate.

## The reading constraint

The operator's private keys must not pass through an agent's context. Reading
one is itself the disclosure — there is no separate "leak" step afterwards, and
it cannot be undone once it lands in a transcript.

So the work is arranged to never require it:

- `sops --encrypt` takes a path and writes ciphertext; contents never reach
  stdout.
- Verification uses properties, not content: does it decrypt, is the recipient
  the one in `.sops.yaml`, is the mode right, does OpenSSH accept it.
- Where a round-trip must be proven, compare `sha256sum` of the original
  against the hash of `sops --decrypt` piped straight into `sha256sum`. That
  demonstrates the ciphertext is faithful without either party seeing the key.
- No `cat`, `head`, `grep`, or editor on a private key; no `set -x` in a script
  that handles one; no recursive grep rooted where one would be swept up.

Filenames, modes, and sizes are not sensitive and are the right level of detail
for planning.

## Behavior baseline

1. Normal Home Manager activation must not invoke `sudo` (working rule 7).
2. Decrypted private keys must not be written to disk in plaintext. The
   foundation materializes secrets on tmpfs; this slice must not give that up
   for convenience.
3. Existing SSH access must keep working throughout. A migration that locks the
   operator out of their own hosts has failed even if every file is in place.
4. `secrets/` stays public-safe, enforced by the existing gate.

## Definition of done

- Selected keys decrypt into a working SSH setup on the staging VM.
- `ssh -T` (or equivalent non-mutating check) succeeds against at least one real
  host using a migrated key.
- No plaintext private key on disk or in the Nix store, verified by scan.
- A documented, tested procedure for removing and rotating a key.
- Legacy SSH material retired only after the replacement survives normal use
  (working rule 10).
