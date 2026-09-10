# 01 — sing-box as an unprivileged local proxy service

Status: ready-for-agent

## Goal

Run `sing-box` as a systemd user service exposing SOCKS5 and HTTP on
`127.0.0.1:1080`, tunneling through a userspace WireGuard endpoint whose
profile arrives as whole-file SOPS ciphertext. This is the first real
ciphertext in `secrets/`, which `modules/secrets.nix` was built to carry.

## Work

1. Encrypt the selected wg-quick profiles from `~/Documents/secrets/wireguard/`
   to `secrets/wireguard/<device>.conf` using the `.sops.yaml` recipient.
   Encrypt whole-file, so the ciphertext is opaque and the endpoint address is
   not published in a public repository. Select deliberately: `desktop-old`,
   `desktop-win` and `phone` are candidates for omission rather than migration.
2. Declare each as a `sops.secrets` entry with `format = "binary"`, which
   sops-nix writes through verbatim.
3. Add `modules/programs/sing-box.nix` with an option selecting which profile
   this machine uses, defaulting to `desktop-ubuntu`. Per-device selection is
   a one-line change at bootstrap; nothing about the peer is transcribed into
   Nix.
4. Add the profile-to-config generator as shell using `jq`, under
   `scripts/bin/`, packaged with `writeShellApplication` per
   `docs/DECISIONS.md`. It reads a decrypted wg-quick `.conf` and writes a
   sing-box config, mapping:
   - `[Interface] Address` -> `endpoints[0].address` (list)
   - `[Interface] PrivateKey` -> `endpoints[0].private_key`
   - `[Interface] MTU` if present, else `1420` -> `endpoints[0].mtu`
   - `[Interface] DNS` -> one `dns.servers` entry per address, each with
     `detour` set to the endpoint tag, so resolution happens through the
     tunnel rather than on the host
   - `[Peer] Endpoint` -> `peers[0].address` and `peers[0].port`
   - `[Peer] PublicKey`, `PresharedKey`, `AllowedIPs` -> the matching fields
   - a fixed `persistent_keepalive_interval` of 25
   The endpoint must set `"system": false`. A single `mixed` inbound listens on
   `127.0.0.1` at the configured port. One `direct` outbound, and one route
   rule sending the inbound to the endpoint tag.
5. Define the service in `systemd.user.services`:
   - `Wants` and `After` = `sops-nix.service`, so the profile is decrypted
     before the generator runs
   - `RuntimeDirectory=sing-box` with `RuntimeDirectoryMode=0700`, and write
     the generated config there — never to `~/.config`, never to the store
   - `ExecStartPre` runs the generator, then `sing-box check -c` on its output
   - `ExecStart` runs `sing-box run -c` against the generated file
   - `Restart=on-failure`
6. Enable linger for the user, so the proxy survives logout and starts before
   graphical login. Do this in a `scripts/bootstrap/` phase, not in Home
   Manager activation: `loginctl enable-linger` is a polkit action
   (`org.freedesktop.login1.set-self-linger`), and activation must not
   become privileged.
7. Add a test under `tests/` running the generator against a fixture `.conf`
   holding a throwaway key, asserting the emitted config passes
   `sing-box check`. The fixture must not contain a real key.

## Constraints

- No private key or preshared key may reach the Nix store, a log, or
  `~/.config`. The only plaintext is the sops runtime path and the generated
  config in `RuntimeDirectory`.
- `nix build .#homeConfigurations.z.activationPackage` must succeed without
  the age identity present.
- Activation must not invoke `sudo` (`AGENTS.md` rule 7).
- The service must not create a TUN device, alter routing, alter
  `/etc/resolv.conf`, or listen on any address other than loopback.
- `sing-box` must come from the pinned nixpkgs. Do not add a flake input for
  it; 1.13.19 is present at the current pin.
- Use the WireGuard `endpoints` schema. The `wireguard` *outbound* was removed
  in 1.13.0 and errors out; most published examples still use it.

## Acceptance

- `nix flake check` passes; the activation package builds.
- On the staging VM: `curl --proxy socks5h://127.0.0.1:1080` and
  `--proxy http://127.0.0.1:1080` both return an exit IP different from the
  direct one.
- While running: zero WireGuard links, zero TUN links, unchanged default route
  and `/etc/resolv.conf`, and `tcp 127.0.0.1:1080` the only added listener.
- `systemctl --user restart sing-box` recovers without manual steps, and a
  reboot brings the service up with no interactive login.
- `tests/` covers the generator and passes.
