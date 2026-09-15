# Split the KeePassXC vault

Separate a small, strongly protected recovery vault from a daily vault that
unlocks with a password plus a key file, and make KeePassXC the only password
store Firefox uses. See [spec.md](spec.md) for the decisions and the fixed list.

## Frontier

Ticket 01.

## Tickets

- [01: Write the vault rules in the recovery repository](issues/01-vault-rules-readme.md) — ready-for-agent.
- [02: Create the daily vault and move the data](issues/02-create-daily-vault.md) — ready-for-human; blocked by 01.
- [03: Deliver the daily key file through sops-nix](issues/03-key-file-delivery.md) — ready-for-agent; blocked by 02.
- [04: KeePassXC under Home Manager](issues/04-keepassxc-home-manager.md) — ready-for-agent; blocked by 03.
- [05: Firefox stores no passwords](issues/05-firefox-stores-no-passwords.md) — ready-for-agent; blocked by 04 and firefox-nix/02.
- [06: Record the split in canonical docs](issues/06-canonical-docs.md) — ready-for-agent; blocked by 03.

## Order

01 and 02 are operator work in the private repository and change nothing here.
03 and 04 can land before Firefox leaves the snap. 05 waits for the
Nix-managed Firefox profile.

## Context

- Came out of the Firefox-under-Nix discussion: two password stores drift, and
  an expensive unlock is why Firefox's store kept winning.
- `firefox-nix/01` needs KeePassXC's native messaging host; ticket 04 supplies
  it, because Home Manager's `programs.keepassxc` adds itself to
  `programs.firefox.nativeMessagingHosts`.
