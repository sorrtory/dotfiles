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

  # SSH material. Private keys stay on tmpfs at the mode OpenSSH demands, and
  # configs/ssh/config points IdentityFile at them rather than having plaintext
  # written back into ~/.ssh. The host-identifying half of that config is a
  # secret for a different reason: it names real infrastructure, and this
  # repository is public.
  sops.secrets = {
    id_ed25519_github = {
      sopsFile = ../secrets/ssh/id_ed25519_github;
      format = "binary";
      mode = "0600";
    };
    id_ed25519_servers = {
      sopsFile = ../secrets/ssh/id_ed25519_servers;
      format = "binary";
      mode = "0600";
    };
    ssh_config_servers = {
      sopsFile = ../secrets/ssh/ssh_config_servers;
      format = "binary";
      mode = "0600";
    };

    # Only this machine's WireGuard identity is decrypted here. All six device
    # configurations are kept as ciphertext so any machine can recover its own,
    # but materializing the phone's and the desktops' keys on a laptop would
    # let one compromised machine impersonate every device on the network.
    #
    # Named after the file they come from, so a path says what it is without a
    # lookup. wg-quick takes the interface name from the basename, so these
    # bring up e.g. `laptop` and `extra` rather than wg0 and wg1. A generic name
    # would only pay off once something shared between machines refers to an
    # interface by name, and nothing does; when something does, renaming the
    # one that needs it is a line here.
    #
    # The identity's file is this machine's own tunnel, for the whole-host
    # vpn-up function; sing-box decrypts the same identity separately. extra
    # is shared across machines by legacy use, never by the sing-box backend.
    "wireguard/${config.dotfiles.vpn.identity}.conf" = {
      sopsFile = ../secrets/wireguard + "/${config.dotfiles.vpn.identity}.conf";
      format = "binary";
      mode = "0600";
    };

    "wireguard/extra.conf" = {
      sopsFile = ../secrets/wireguard/extra.conf;
      format = "binary";
      mode = "0600";
    };
  };
}
