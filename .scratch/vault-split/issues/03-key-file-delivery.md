# 03 — Deliver the daily key file through sops-nix

Status: ready-for-agent
Blocked by: 02

## Goal

Every machine that has recovered its age identity has the daily vault's key
file after activation, with no manual copy.

## Work

1. Encrypt `Daily.keyx` to `secrets/keepassxc/Daily.keyx` with
   `format = "binary"`, matching the SSH and WireGuard convention.
2. Declare it in `modules/secrets.nix` at mode `0600`, reached through the stable
   `~/.config/sops-nix/secrets` symlink.
3. Point KeePassXC at that symlink once when opening `Daily.kdbx`, and confirm
   it is remembered across restarts.

## Constraints

- The recovery vault's attachment stays the backup copy; the ciphertext is a
  delivery path, not the only copy.
- The key file is never written to persistent storage in plaintext.
- Machines without disk encryption are acceptable only because
  `~/.config/sops/age/keys.txt` already sits on that disk; note this in the
  secrets comment rather than hiding it.

## Acceptance

- After a reboot, the key file exists before the operator unlocks the vault,
  with no manual step.
- `gitleaks` and the public-safety checks pass with the new ciphertext.
- `tests/*.sh` still pass.
