# SSH keys and configuration

Migrate selected operator SSH identities and configuration without exposing
private key contents or host-identifying metadata. See [spec.md](spec.md).

## Frontier

[05: Rotation and removal](issues/05-rotation-and-removal.md) is the remaining
agent task. Ticket 06 is the final operator gate on a fresh machine and stays
blocked until removal is proven.

## Tickets

- [01: Inventory and classify](issues/01-inventory-and-classify.md) — resolved; selected operator identities and the public/private configuration split shipped in `376ef7b`.
- [02: Verify the sops-nix key path](issues/02-verify-sops-key-usable.md) — resolved; mode-0600 runtime key and real GitHub authentication passed on staging in `376ef7b`.
- [03: SSH configuration](issues/03-ssh-configuration.md) — resolved; native public config includes the encrypted host-identifying fragment.
- [04: Encrypt selected keys](issues/04-encrypt-selected-keys.md) — resolved; two selected keys are whole-file ciphertext and runtime declarations.
- [05: Rotation and removal](issues/05-rotation-and-removal.md) — ready-for-agent.
- [06: New-machine normal use and legacy retirement](issues/06-verify-and-retire-legacy.md) — ready-for-human; blocked by 05.

## Completion boundary

The existing legacy keys remain untouched. After ticket 05, the operator will
activate the setup on the new machine, use the migrated identities normally and
decide when the old copies may be retired. Record that result in ticket 06,
fold any remaining durable facts into canonical documentation, and remove this
scratch directory only in the completion commit.
