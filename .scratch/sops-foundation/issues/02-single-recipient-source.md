# 02 — Make `.sops.yaml` the only place the recipient is written

Status: ready-for-agent
Blocked by: 01

## Goal

The public recipient currently appears as a literal in two shell files, and
ticket 01 adds a third in `.sops.yaml`. Encryption reads `.sops.yaml`; the
verification in recovery reads its own copy. If those ever disagree, recovery
would accept an identity that cannot decrypt the repository's ciphertext, and
the mismatch would surface only at decryption time. Collapse them to one.

Current copies:

- `scripts/repo/recover-age-identity.sh:193`
- `scripts/bootstrap/03-secret-recovery.sh:16`
- `.sops.yaml` (added by ticket 01)

Test fixtures in `tests/bootstrap_secret_recovery_test.sh` and
`tests/recover_age_identity_test.sh` also carry the literal. Those are
fixtures asserting a specific value and may keep it, but prefer deriving it
where the test is asserting "matches the repository" rather than "matches this
exact string".

## Work

1. `scripts/bootstrap/03-secret-recovery.sh` runs from a repository checkout,
   so it can read `.sops.yaml` relative to the existing `REPO_ROOT`. Extract
   the recipient with a small helper rather than a YAML parser — an
   `age1[0-9a-z]{58}` match is unambiguous here and adds no dependency. Fail
   loudly if zero or more than one distinct recipient is found; silently
   picking the first would defeat the point.
2. `scripts/repo/recover-age-identity.sh` is different: it is packaged into
   the Nix store by `packages/recover-age-identity.nix` via
   `builtins.readFile`, so at runtime it has no repository next to it and
   cannot read `.sops.yaml` from disk. Inject the value at build time instead
   — have `recover-age-identity.nix` read `.sops.yaml`, extract the recipient
   in Nix, and pass it to the script, which then requires it rather than
   defaulting to a literal. A missing value must be a hard error, never an
   empty string that compares equal to nothing.
3. Update the header comment in `.sops.yaml`. It currently ends by noting that
   the recovery scripts still carry their own copies and are being consolidated
   onto this file; once this ticket lands, that sentence is stale and must go.
4. Keep the failure messages as specific as they are now. The existing
   "does not match the configured age recipient" wording is good; do not
   replace it with a generic error.

## Constraints

- Only the public recipient may pass through Nix. The private identity must
  not enter the store, an environment variable, or a command argument.
- Do not add a YAML parser dependency to the recovery closure. Its runtime
  inputs are deliberately small.

## Acceptance

- `grep -rn 'age1rmcmjsw' --include='*.sh' --include='*.nix' .` matches only
  test fixtures.
- `tests/recover_age_identity_test.sh` and
  `tests/bootstrap_secret_recovery_test.sh` pass.
- A deliberately edited `.sops.yaml` recipient makes recovery reject the
  KeePassXC attachment, proving the two are actually coupled. Add this as a
  test case.
