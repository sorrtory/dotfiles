# Spec: SOPS/age foundation

Status: ready-for-agent

## Why

`docs/MIGRATION.md` §2 has two halves. The first — secret recovery — is done:
`03-secret-recovery` restores a verified private age identity to
`~/.config/sops/age/keys.txt`. The second half never landed:

> Configure sops-nix with only the public recipient and establish the
> public-safe `secrets/` invariant before migrating ciphertext.

Today the flake has no `sops-nix` input, there is no `modules/secrets.nix`, no
`.sops.yaml`, and no `secrets/` directory. The recovered identity is therefore
consumed by nothing, and §5 (WireGuard) has no place to put ciphertext and no
mechanism to decrypt it. This slice closes that gap and nothing more.

## Scope

Establish the foundation, not the first secret. Real ciphertext arrives with
the WireGuard slice; this slice proves the mechanism with a throwaway canary
that does not survive the slice.

In scope:

- `sops-nix` as a flake input and a Home Manager module.
- `.sops.yaml` as the single source of truth for the public age recipient.
- The public-safe `secrets/` invariant, mechanically enforced.
- `sops` as a global user tool, and the documentation that describes all of it.

Out of scope:

- Any real secret, WireGuard config, or legacy ciphertext migration (§5).
- Host-side deployment to `/etc/wireguard/` (§5, explicitly privileged).
- Changing how the identity is recovered or verified (already shipped).

## Behavior baseline

The slice must not regress these:

1. Normal Home Manager activation never invokes `sudo`
   (`docs/DECISIONS.md`, "Platform and ownership").
2. Only the public recipient appears in repository configuration
   (`docs/DECISIONS.md`, "Secrets and authentication").
3. `03-secret-recovery` keeps verifying the restored identity against the
   repository's configured recipient. Moving where that recipient is stored
   must not weaken the check.
4. The staged secret gate keeps passing on ciphertext and keeps failing on
   plaintext.

## Definition of done

- `nix flake check` and `nix build .#homeConfigurations.z.activationPackage`
  succeed on the host.
- Every `tests/*.sh` passes.
- A canary secret decrypts into the activated environment on the staging VM
  under a normal `bootstrap.sh install home-manager`, with no `sudo` prompt,
  and is removed before the slice is presented.
- The recipient literal appears exactly once outside test fixtures.
- `docs/SOFTWARE.md`, `docs/DECISIONS.md`, and `AGENTS.md` describe the
  result without duplicating the contract.

## Open decisions

Recorded from operator review, 2026-09-10:

- The public recipient's single source of truth is `.sops.yaml`, because it is
  the file `sops` itself reads during encryption, so it cannot drift from the
  recipient that ciphertext is actually written to. Consumers derive it from
  there rather than restating it.
