# 01 — Compile the backend from an encrypted egress inventory

Status: ready-for-agent

Blocked by: None (can start immediately)

## Goal

Replace `dotfiles.vpn.identity` and `secrets/wireguard/` with the two
encrypted files in ../spec.md, so the backend is compiled against one egress
chosen from an inventory instead of against the machine's single WireGuard
credential. Behaviour after this ticket is what it is today: same tunnel, same
proxy, same VPN command. Only the source changes.

## Work

1. Convert the six WireGuard configurations into sing-box `wireguard`
   endpoints inside `secrets/vpn/egresses.jsonc`, tagged
   `vdsina-nl-wg-<name>`, keeping `extra` as an ordinary name. Carry each
   file's notes over as `//` comments.
2. Write `secrets/vpn/policy.jsonc`: the default egress per hostname, and the
   egresses whose server has no IPv6.
3. Rewrite the generator. It reads both decrypted files, picks the active
   egress — saved choice first, then the machine's default — and emits a
   configuration containing only that egress, the existing inbounds, DNS
   detoured through it and `route.final` pointing at it. `endpoints` versus
   `outbounds` is decided by each entry's `type`; an unrecognised type is a
   hard failure at service start.
4. Delete the `local` bootstrap DNS server. Every endpoint is an IP literal,
   so nothing needs resolving before the tunnel exists.
5. Set `route.auto_detect_interface` on the backend, which ticket 03 depends
   on and which is harmless before it.
6. Remove the `dotfiles.vpn.identity` option and its enum. No Nix option names
   an egress; the default comes from the policy file keyed by hostname.
7. Keep the machine's own `wg-quick` configuration under `secrets/wireguard/`
   for now, because `vpn-up` still uses it until ticket 03 removes both. The
   laptop's credential is therefore encrypted twice for two slices, which is
   deliberate and temporary.

## Constraints

- No egress name may appear in `home.nix` or anywhere else in plaintext.
- Credentials are read only at runtime, as they are today: no key through
  Nix evaluation, argv, the environment, logs or the Nix store.
- `secrets/vpn/*.jsonc` must be whole-file ciphertext that `sops` edits as
  binary, so comments survive a round trip and the staged secret gate accepts
  the files.
- Do not add a protocol adapter layer, a per-egress schema of our own or a
  selector group. Entries are sing-box's own JSON.

## Documentation

Rewrite the `docs/DECISIONS.md` statements that each machine uses its own
WireGuard identity, that only that identity is decrypted, and that resolving a
WireGuard endpoint hostname is the sole host-DNS exception. Retire the **VPN
identity** term in `CONTEXT.md` and define **egress** and **active egress** in
its place. Update `docs/MIGRATION.md` §7 and its fresh-machine flow, which
still tells a new machine to set `dotfiles.vpn.identity`. Record the accepted
cost: every machine holds every credential, and one WireGuard peer must never
be used by two clients at once.

## Acceptance

- [ ] `sing-box check` validates `egresses.jsonc` on its own.
- [ ] The generated configuration passes the pinned checker and contains
      exactly one egress, with no unbound direct outbound.
- [ ] The local proxy, the VPN command and Vesktop behave as before on the
      host; TCP, UDP and DNS stay tunneled on staging.
- [ ] Fixtures cover: unknown entry type, a policy default naming a missing
      egress, an unparseable file, and a machine whose hostname has no default.
- [ ] `scripts/repo/check-secrets.sh` passes and no plaintext credential
      exists outside the runtime directory.
