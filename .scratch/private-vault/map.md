# Private vault

Give the operator an encrypted collection of private notes and personal files
that unlocks explicitly, opens in Nautilus or Obsidian, and locks without ever
claiming more than it can verify. See [spec.md](spec.md) for the settled
requirements and the accepted interface.

## Frontier

Ticket 05, with 02 open alongside it. 01 is claimed and waiting only on its VM
check. 07 is partly done: the graphical prompt and `<Super>n` landed with 04
and 06, leaving the desktop unmount action and visible failure reporting.

## Tickets

- [01: The knowledge database at its real path, on its own key](issues/01-knowledge-database-path.md) — claimed; host work done, VM check outstanding.
- [02: Prototype the gocryptfs and Obsidian lifecycle on the VM](issues/02-lifecycle-prototype.md) — ready-for-agent; prototype.
- [03: `vault init` creates encrypted storage](issues/03-vault-init.md) — resolved.
- [04: `vault open` unlocks the vault and shows it](issues/04-vault-open.md) — resolved.
- [05: `vault lock` closes access and proves it](issues/05-vault-lock.md) — ready-for-agent; blocked by 02 and 04.
- [06: `vault notes` opens the private notes in Obsidian](issues/06-vault-notes.md) — resolved ahead of 02; Obsidian's existing-instance behaviour is still unverified.
- [07: The vault from the desktop, with no terminal](issues/07-desktop-actions.md) — ready-for-agent; blocked by 05 and 06.
- [08: The vault closes at logout and shutdown](issues/08-session-cleanup.md) — ready-for-agent; blocked by 05.
- [09: Record the private vault in canonical documentation](issues/09-canonical-docs.md) — ready-for-agent; blocked by 01, 05, 06, 07 and 08.

## Order

01 is prefactoring and changes nothing about the vault: the declared clone path
for the knowledge database is wrong today, and both Obsidian collections are
distinguished from 06 onwards. 02 is throwaway VM work whose answers the lock
design needs, so it is worth starting early even though only 05 and 06 wait on
it. 03 and 04 are split because initialization is deliberately separate from
opening; together they are the first slice the operator can use. 05 and 06 are
independent of each other and both extend the mounted vault. 07 makes the whole
thing reachable from the session, and 08 ends it cleanly.

## Context

- The operator replaced the vault model partway through: no default vault, no
  global one. `init` takes a name and builds it in the working directory;
  `open` and `notes` take a path. `~/Vault` is now only a convention, written
  down once in the GNOME module for `<Super>n`. Vault data arrives by hand for
  now, and by restic later.
- Resolved by [04](issues/04-vault-open.md), and 02 should not re-derive these:
  - Nautilus holding the vault is the blocked-unmount case, caused by the very
    application `vault open` launches. Observed, not predicted.
  - `fusermount3 -uz` detached a mount while the daemon kept serving an
    outstanding reference; only SIGTERM ended it. A lock that lazily unmounts
    and reports success would be lying.
  - gocryptfs daemonizes as `.gocryptfs-wrapped -fg -notifypid=PID -- STORAGE
    MOUNT`, which is how the owning process is found from `/proc`.
  - The password never passes through the command: gocryptfs prompts. The
    graphical prompt in 07 is `-extpass`, not password handling in the script.
- Resolved by [03](issues/03-vault-init.md):
  - `--storage DIR` is how existing storage outside the sibling rule is named.
  - `vault init` refuses without a terminal. gocryptfs suppresses the master
    key when it is not talking to one, so a headless init would create storage
    with no recovery material at all. Only running the real binary showed this;
    a stub cannot.
  - `VAULT_FUSERMOUNT` overrides the helper search for an unusual host.
  - Testing the command needs a pty, so `tests/vault_test.sh` uses `script(1)`
    for the success cases and a stub gocryptfs for the path rule.

- The spec's "Design tree" is older than its "Accepted interface and access
  policy" section and still marks settled things pending. The accepted section
  wins. What is genuinely open is the invocation for an explicit encrypted-path
  override (settled by 03) and the Obsidian and lock behaviour (observed by 02).
- Nixpkgs carries gocryptfs 2.6.1, the version the spec's lock analysis assumes,
  so the package policy's "prefer Nixpkgs" applies with no local package.
- `home.nix` declares `Documents/knowledge-database` while the requested and
  existing path is `Documents/Knowledge-Database`. Left alone, activation clones
  a second directory. This is the spec's own investigation finding.
- The FUSE helper is host-owned and has to be. Checked on 2026-09-16: the
  Nixpkgs gocryptfs binary holds no store path for it, resolving `fusermount3`
  against `/usr/sbin:/usr/bin:/sbin:/bin` and NixOS's
  `/run/wrappers/bin/fusermount3`. This host's `/usr/bin/fusermount3` is setuid
  root from Ubuntu's `fuse3`. A store path is never setuid-root, so Nixpkgs
  cannot supply it; NixOS uses `security.wrappers` for the same reason. Ubuntu,
  Fedora and NixOS all satisfy this by default, so 03 makes it a check with a
  clear error, not a bootstrap dependency.
- User lingering is enabled, so user services do not stop at graphical logout.
  08 cannot use them as the signal.
- Backups are out of scope. Restic with Google Drive through its rclone backend
  remains the selected direction, as a separate milestone covering the vault,
  the archive and other user data.
- Staging: 01, 06 and 07 need the Ubuntu GNOME VM, and settings a session only
  reads at login need a real re-login there before they can be judged. The VMs
  are shared with other efforts and `rsync --delete` mirrors a whole tree, so
  take staging in turns.
