# 03 — Enforce the public-safe `secrets/` invariant

Status: ready-for-agent
Blocked by: 01

## Goal

`docs/DECISIONS.md` states that "everything committed under `secrets/` must
already be public-safe." That is currently a promise, not a check. The
existing gate (`scripts/repo/check-secrets.sh`, gitleaks) scans for known
secret *shapes* anywhere in the diff; it would not notice a plaintext file
under `secrets/` whose contents match no rule — an unrecognized config format,
a base64 blob, a key type gitleaks has no rule for.

Invert the test for that one directory: under `secrets/`, a file is rejected
unless it is positively recognized as SOPS ciphertext.

## Work

1. Extend the staged scan so every staged file under `secrets/` must be SOPS
   ciphertext. Recognize it by structure — SOPS-encrypted files carry a `sops`
   metadata block naming the encryption method and the age recipients — not by
   file extension, which an operator can trivially get wrong.
2. Allow an explicit, narrow exception list for non-sensitive metadata, since
   `docs/DECISIONS.md` defines public-safe material as "SOPS ciphertext **or**
   non-sensitive metadata". `.gitkeep` and a `README.md` explaining the
   directory are the expected members. Keep the list short and explicit rather
   than pattern-based.
3. Keep this in the existing gate so the pre-commit hook picks it up with no
   separate invocation. Do not add a second entry point the operator has to
   remember.
4. Extend `tests/secret_scan_test.sh` following its existing structure:
   - plaintext under `secrets/` is rejected even when it matches no gitleaks
     rule;
   - valid SOPS ciphertext under `secrets/` is accepted;
   - a file that merely *mentions* `sops` is rejected, so recognition cannot
     be spoofed by a comment;
   - the same plaintext outside `secrets/` keeps its existing behavior, so the
     new rule is scoped and did not become a global tightening.

## Constraints

- Ciphertext must never be treated as an error. `docs/MIGRATION.md` §1 is
  explicit that the gate rejects plaintext "without treating ciphertext as an
  error", and this rule must not invert that for the rest of the tree.
- Keep the check reproducible and network-free, matching the pinned-gitleaks
  reasoning already recorded in `flake.nix`.

## Acceptance

- `tests/secret_scan_test.sh` passes with the new cases.
- Staging a plaintext file under `secrets/` fails the pre-commit hook with a
  message that names the offending path and says what was expected.
