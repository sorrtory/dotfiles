# 03 — `vault init` creates encrypted storage

Status: resolved

Blocked by: None (can start immediately)

## Goal

The operator can create a private vault's encrypted storage from the terminal,
once, deliberately, and is told to preserve its recovery material by hand. This
ticket establishes the command itself and the rule that maps a mount directory
to its storage; ticket 04 makes the vault usable.

## Work

1. Create the `vault` command as an ordinary Bash source under the personal
   script directory, packaged with `writeShellApplication` and exposed as a
   global user tool, as the decision log requires of operator commands.
2. Implement the path rule: a command takes a mount-directory path and defaults
   to `~/Vault`; the encrypted storage is the hidden sibling of that directory
   (`~/Vault` becomes `~/.Vault.encrypted`, `~/Documents/Work` becomes
   `~/Documents/.Work.encrypted`). There is no registry of named vaults.
3. Settle and implement the one interface question the spec leaves open: how an
   invocation names existing encrypted storage that does not follow the sibling
   rule. Record the chosen form in the spec as a decision, not only in code.
4. Implement `vault init [path]`: refuse when storage or a non-empty mount
   directory already exists, prompt for the new password twice without echo,
   and create the gocryptfs filesystem.
5. On success, instruct the operator to store the recovery material in
   KeePassXC, outside any filesystem vault, and stop there.
6. Check the FUSE helper before doing anything, and fail with a message naming
   what the host is missing. The Nixpkgs build carries no store path for it: it
   resolves `fusermount3` against `/usr/sbin:/usr/bin:/sbin:/bin` and NixOS's
   `/run/wrappers/bin/fusermount3`, so the setuid helper is always host-owned.
   Never introduce sudo.
7. Cover the path rule, the refusals and the prerequisite failure with a test
   beside the other repository tests.

## Constraints

- Recovery material is never written to a log, a repository file, a shell
  history entry or the Nix store, and never echoed anywhere it can be captured.
- Passwords are never persisted and never passed as command arguments.
- Initialization creates a general-purpose encrypted filesystem and nothing
  else: no `Notes/`, no application layout.
- The setuid FUSE helper cannot come from Nixpkgs, because a store path is
  never setuid-root. This is the exception to the package policy, not an
  oversight, and the check exists to say so out loud when a host lacks it.
- The command is not a backup tool. Backups are a separate milestone.

## Acceptance

- `vault init` on a fresh path creates storage at the derived hidden sibling
  and prints the recovery instruction.
- A second `vault init` on the same path refuses without touching the storage.
- A host without FUSE produces the named error, not a stack of gocryptfs noise.
- The secret scan, evaluation and the repository tests pass.

## Answer

Done. `scripts/bin/vault.sh` is packaged as `vault` through `modules/scripts.nix`
beside `archive`, with `gocryptfs` from Nixpkgs as a runtime input.

Settled here:

- **`--storage DIR`** names existing storage that does not follow the sibling
  rule, accepted alongside the mount directory and in `--storage=DIR` form.
  Recorded in the spec.
- **`init` requires a terminal.** Found by running the real command rather than
  the stub: without a terminal gocryptfs creates the filesystem, prints
  "Not running on a terminal, suppressing master key display", and the only
  recovery material there will ever be is gone. It now refuses before creating
  anything. On a pty it prompts twice and prints the key once, as intended.
- **The FUSE helper is host-owned.** The Nixpkgs binary holds no store path for
  it and searches `/run/wrappers/bin`, `/usr/bin`, `/bin`, `/usr/sbin`,
  `/sbin`, so the command checks first and names the `fuse3` package.
  `VAULT_FUSERMOUNT` covers a helper kept somewhere unusual.

Verified on the host: real `gocryptfs -init` through the packaged command
creates the hidden sibling at mode 700 and leaves the vault unmounted; the same
call without a terminal refuses and creates nothing; `tests/vault_test.sh`
covers the path rule, both `--storage` forms, both refusals, the missing-helper
error and that no file the command writes contains the master key. All 21
repository tests and `nix flake check` pass. No activation anywhere.

Not done here: mounting, which is ticket 04.

## Amendment

The operator replaced the path-with-a-default interface: `vault init` now takes
a **name** and creates the vault in the working directory, and no command
defaults to `~/Vault`. There is no global vault. `--storage` is unchanged, and
the hidden-sibling rule still derives the ciphertext directory from the vault
directory. `~/Vault` survives only as a convention the GNOME module writes down
once, so `<Super>n` knows where to look.
