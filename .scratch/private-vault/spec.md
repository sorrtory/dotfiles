# Private vault

Status: design interview in progress; implementation not started.

## Settled requirements

- Use gocryptfs for the private vault rather than a LUKS image.
- Default to exposing the unlocked private vault at `~/Vault`; private Obsidian
  notes live in `~/Vault/Notes`, alongside other private files. Support other
  vault locations rather than hardcoding this one.
- The public-safe knowledge database lives at
  `~/Documents/Knowledge-Database` and does not require unlocking.
- Provide explicit unlock-and-open actions for Nautilus and Obsidian, plus
  an action to unmount the private vault.
- Super+N is intended to open private notes; Super+K is the proposed shortcut
  for the knowledge database, subject to checking existing bindings.
- The operator expects backups rather than synchronization between machines.
- Actual data and passwords stay outside the dotfiles repository.
- Provide a separate `vault init` action; ordinary opening does not initialize
  missing encrypted storage.
- Select restic for backups with Google Drive as the destination. Its rclone
  backend supplies Drive transport; gocryptfs itself is not a backup manager.
- Prefer gocryptfs from Nixpkgs, consistent with repository package policy.
- Do not maintain named-vault registrations. Select vaults by path, with
  `~/Vault` as the default; prompt for paths where needed. The relationship
  between encrypted storage and mount paths is still to be settled.
- Lock should close access gracefully when possible. There is no timeout or
  automatic escalation. If completion needs a potentially destructive action,
  explain the blockers and risk and obtain explicit confirmation first.
- Backups are a separate milestone covering the private vault, Archive and
  other user data. Restic with Google Drive remains the selected direction;
  backup implementation is outside this vault slice.

## Accepted interface and access policy

- Commands accept a mount-directory path and default to `~/Vault`; there is
  no persistent named-vault registry.
- Derive encrypted storage as a hidden sibling: `~/Vault` maps to
  `~/.Vault.encrypted`, and `~/Documents/Work` maps to
  `~/Documents/.Work.encrypted`. Allow explicit encrypted-path overrides for
  existing storage; their exact invocation is still to be specified.
- `vault open [path]` mounts and opens Nautilus; `vault notes [path]` mounts
  and opens `Notes/` in Obsidian; `vault lock [path]` closes access.
- Use a graphical password dialog for desktop actions and a hidden terminal
  prompt for terminal actions. Do not persist passwords. Reuse an existing
  verified mount without asking again.
- Lock attempts graceful application closure and clean unmounting, completing
  automatically when those succeed. Let application save/close dialogs remain
  interactive; do not impose a timer.
- If applications or active references prevent clean locking, identify known
  blockers and explain that forcing may lose unsaved edits or interrupt writes.
  Offer retry after manual closure, cancel, or explicitly confirmed force.
  Never automatically escalate based on elapsed time. Confirmation is per
  forced action, not blanket authorization from this design discussion.
- Cancelling leaves the vault unlocked and reports that state. Forced locking
  must verify process/mount cleanup and report failures honestly.
- Temporary mount/process bookkeeping under `$XDG_RUNTIME_DIR` is accepted;
  it is not a persistent vault registry, stores no passwords, and must be
  checked against the actual mount/process before use.
- Do not indiscriminately terminate processes using the vault. Track owned
  processes and recognize that unrelated applications may retain loaded text.
- During initialization, instruct the operator to preserve recovery material
  manually in KeePassXC, outside the filesystem vault. Do not log recovery
  material or write it into repository files.
- Create `Notes/` on the first successful `vault notes` invocation after
  mounting. Initialization alone creates a general-purpose encrypted filesystem.
- Invoke locking explicitly and arrange logout/shutdown cleanup. Do not lock
  automatically on screen lock or suspend.
- Do not inhibit logout or shutdown and do not add a vault-specific shutdown
  confirmation. Integrate ordinary session cleanup despite user lingering;
  interactive retry/cancel/force choices belong to explicit `vault lock`.
  Normal session shutdown may end processes without preserving unsaved edits.
  Abrupt power loss is not promised to have identical crash guarantees to ext4.

## Lock guarantee and verification constraints

- A lazy unmount alone does not revoke access through outstanding references.
- Pinned gocryptfs 2.6.1 handles SIGTERM by trying normal unmount, falling back
  to lazy unmount, and exiting. Forced teardown can interrupt pending writes.
- Successful locking must verify mount cleanup and termination of the owned
  decryption process. It cannot promise erasure of plaintext already read by
  applications or cached elsewhere.
- VM tests must establish actual Obsidian/window closure behaviour, daemon
  lifecycle, stale mount recovery and lock timing.

## Design tree

- Storage: gocryptfs selected.
  - Separate initialization and path-based selection selected; backing and
    mount directory relationship: pending.
  - Recovery material: pending. Backup implementation: separate milestone.
- Entry points: explicit mount-and-open selected.
  - Public commands and desktop actions: pending.
  - Password prompting and persistence: pending.
  - Repeated/concurrent launches, cancellation and existing mounts: pending.
- Access lifetime: pending.
  - Interactive locking: graceful automatic completion, no timer, explicit
    confirmation before risky force.
  - Logout/shutdown: ordinary session cleanup, no inhibitors or additional
    confirmation dialogs. Screen lock/suspend leave vaults mounted.
  - Screen lock, suspend and logout: pending.
- Obsidian integration: two separate vaults selected.
  - Existing-instance behaviour and first-time registration: pending verification.
- Repository integration and staging validation: pending design completion.

## Investigation findings

- `home.nix` currently declares `Documents/knowledge-database`, whereas the
  requested and existing path is `Documents/Knowledge-Database`. Align this
  declaration during implementation to avoid cloning a second directory.
- User lingering is enabled, so user-service shutdown cannot be assumed to
  coincide with graphical logout.
- Restic supports rclone repositories; rclone supports Google Drive. The
  encrypted working directory and a versioned backup repository serve distinct
  purposes.

## Interview process

Record answers here as decisions settle. Keep domain terminology in
`CONTEXT.md`; record durable ownership decisions in `docs/DECISIONS.md` when
settled. Confirm shared understanding before implementation, as requested by
the grilling skill.
