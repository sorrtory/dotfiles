{ config, sops-nix, ... }:

{
  imports = [ sops-nix.homeManagerModules.sops ];

  # The private identity is restored by the secret-recovery bootstrap phase,
  # which writes exactly this path. Stated explicitly rather than left to the
  # module default so the coupling between the two is visible from here.
  sops.age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";

  # sops.age.generateKey is deliberately left unset. Activation must never
  # mint an identity: an identity this repository's recipient does not match
  # would decrypt nothing, and silently generating one would hide a failed
  # recovery instead of surfacing it.

  # sops.secrets is intentionally empty. This slice establishes the mechanism;
  # the first real ciphertext arrives with the WireGuard migration.
}
