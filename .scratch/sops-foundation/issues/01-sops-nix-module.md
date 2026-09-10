# 01 — Wire sops-nix into the flake and the user environment

Status: ready-for-agent

## Goal

Give the recovered age identity something that consumes it: a `sops-nix` Home
Manager module, configured with only the public recipient, that can decrypt
repository ciphertext into the activated user environment.

## Work

1. Add the `sops-nix` flake input with `inputs.nixpkgs.follows = "nixpkgs"`,
   like the `home-manager` input, and pass it into `homeConfigurations.z`
   alongside the existing modules. Prefer a release branch matching the
   existing `nixos-26.05` / `release-26.05` pins; sops-nix does not always
   publish one, so fall back to `master` and record which was used.
2. Add `.sops.yaml` at the repository root with one `creation_rules` entry
   covering `secrets/`, naming the single public recipient
   `age1rmcmjswz8e7fanjzegmug24euprves7p240kkedun2sn4qvqkekqqvkgew` under a
   YAML anchor so it is written once.
3. Add `modules/secrets.nix` importing the sops-nix Home Manager module and
   setting `sops.age.keyFile` to `~/.config/sops/age/keys.txt` — the exact
   path `03-secret-recovery` writes. Do not set `sops.age.generateKey`;
   the identity comes from recovery, never from activation.
4. Import `modules/secrets.nix` from `home.nix`.
5. Create `secrets/` with a `.gitkeep`, since Git will not carry an empty
   directory and ticket 03's invariant needs the path to exist.

## Constraints

- Declare no real secret. `sops.secrets` stays empty in this ticket; ticket 05
  adds and removes a canary.
- Activation must not require the identity to be present in order to *build*.
  A missing key file may fail activation, but `nix build` must not need it.
- Do not set any option that would make activation privileged.

## Acceptance

- `nix flake check` passes.
- `nix build .#homeConfigurations.z.activationPackage` succeeds on the host
  with no secret declared.
- `flake.lock` gains exactly the sops-nix node and its own inputs; the
  nixpkgs node does not move.
