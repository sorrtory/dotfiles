# Spec: archive compression, encryption and a configurable root

Status: ready-for-agent

## Why

`archive` moves a directory's contents into `~/Archive/<name>/<timestamp>/`.
Three things it cannot do have come up in use, and one thing it does badly was
found while measuring the others.

- **No compression.** An archive is a plain tree, so a directory that is being
  retired rather than consulted costs the same disk as when it was live.
- **No encryption.** Some retired material should not sit in cleartext under
  `~/Archive`, and the archive's file names are themselves revealing.
- **The root is hardcoded** in two places, `scripts/bin/archive.sh` and the
  activation in `modules/directories.nix`. Archiving to an external disk needs
  editing the script, and the two copies can drift.
- **`rsync` never renames.** Measured on this host: moving within one
  filesystem produced source inode 24600 and destination inode 24601 on the
  same device, so `archive ~/Downloads` rewrites every byte even though
  `~/Downloads` and `~/Archive` share a partition. On a large directory that is
  minutes of disk I/O for what `rename(2)` does instantly.

## User stories

1. As the operator, I want a directory's contents moved into a dated archive
   directory, so that the directory is cleared without deciding what to keep.
2. As the operator, I want to see what is about to move and how much of it
   there is before it moves, so that I never clear the wrong directory.
3. As the operator, I want the largest entries listed first, so that I can
   recognise the directory from the one line that matters.
4. As the operator, I want the archive named after the date and time alone, so
   that I can read the directory listing without decoding suffixes.
5. As the operator, I want two runs in one second to stay separate, so that one
   archive never silently absorbs another.
6. As the operator, I want the command to refuse when nobody answered, so that
   an unattended run archives nothing rather than something unintended.
7. As the operator, I want `--force`, so that a keybinding or script can
   archive without a question.
8. As the operator, I want the size reported on the move itself, so that a
   `--force` run in a log still says what it did.
9. As the operator, I want a same-filesystem archive to be instant, so that
   retiring a large directory is not a disk-bound operation.
10. As the operator, I want hard links preserved by a move, so that a
    deduplicated directory does not double in size when archived.
11. As the operator, I want `-z`, so that a directory I am retiring stops
    costing its full size on disk.
12. As the operator, I want `-e`, so that retired material that is sensitive is
    unreadable at rest.
13. As the operator, I want the file names inside an encrypted archive hidden
    too, so that the archive does not describe its own contents.
14. As the operator, I want to type an archive password twice, so that a typo
    cannot produce an archive nobody can ever open.
15. As the operator, I want the password never to appear in a pipe or in shell
    history, so that encrypting from a terminal leaves no copy behind.
16. As the operator, I want an archive verified before its source is deleted,
    so that a failed write never costs the originals.
17. As the operator, I want a failed verification to leave both the source and
    the archive in place, so that I decide what to discard.
18. As the operator, I want symlinks pointing inside the archived directory
    kept as symlinks, so that the archive does not store the same file twice.
19. As the operator, I want symlinks pointing outside it resolved into real
    files, so that an archive that travels to another machine still works.
20. As the operator, I want that resolution bounded, so that a stray symlink
    cannot pull my SSH keys, an unlocked vault or an external disk into an
    archive.
21. As the operator, I want out-of-tree symlinks named in the plan, so that I
    see what will be pulled in before agreeing to it.
22. As the operator, I want `--to`, so that I can archive to an external disk
    for one run without changing my configuration.
23. As the operator, I want the archive root set once in Home Manager, so that
    the command and activation cannot disagree about where archives live.
24. As the operator, I want progress while a long cross-device copy runs, so
    that I can tell it is working.
25. As the operator, I want the plan to say when the destination is on another
    filesystem, so that I know a copy is coming rather than a rename.
26. As the operator, I want the script to work when run directly from the
    repository, so that the tests and a non-Nix host both still exercise it.
27. As the operator, I want a clear failure naming the package when `7zz` is
    absent, so that a missing dependency is a sentence rather than a stack of
    `command not found`.

## Settled design

### Surface

```
archive [--force] [-z|--compress] [-e|--encrypt] [--to DIR] [DIRECTORY]
```

`-e` implies `-z`; there is no encrypted uncompressed archive. `DIRECTORY`
defaults to the current directory.

The **archive root** resolves `--to DIR`, then `$ARCHIVE_ROOT`, then
`$HOME/Archive`. The env var is what lets Home Manager set the root while the
bare script keeps a working default.

### Shared behaviour

Reject `/`, a source that contains the root, and a source inside the root. An
empty source exits 0 and creates nothing.

Measure once, before anything moves: item count, total size, the six largest
top-level entries, every symlink whose target is outside the source, and
whether the destination is on a different filesystem. Print that plan, then
read `y/N` from stdin, where end of input cancels. `--force` suppresses the
question only, never the password.

The destination is `<root>/<name>/<YYYY-MM-DD_HH-MM-SS>`, colliding to `-2`,
`-3` and so on. The source directory itself always survives; only its contents
move.

### Move path (default)

- **Same device**: `mv` each top-level entry. `rename(2)` is instant at any
  size, atomic per entry, and leaves inodes untouched so hard links survive.
- **Cross device**: `rsync -aH` *without* `--remove-source-files`, with
  `--info=progress2` when interactive. Then an `rsync -c --dry-run` pass to
  compare both sides. Only then is the source deleted.

The two-phase split is what makes cross-device verification mean anything:
`--remove-source-files` deletes as it goes, so a check afterwards would have
nothing left to compare against.

Any failure keeps everything and exits non-zero.

### Compress path (`-z`)

Build a hardlink mirror of the source with `cp -al`, then replace each
**qualifying** symlink in the mirror with a hardlink to its target. Archive the
mirror with `7zz a -snl`, then discard it. Hardlinks make the mirror nearly
free, and 7z discards hard links anyway, so nothing is lost by mirroring.

A symlink qualifies for resolution when its target is **a regular file**, **under
`$HOME`**, and **on the same device as `$HOME`**. Everything else stays a
symlink. The three conditions are load-bearing and none is redundant:

- *regular file* stops an out-of-tree directory symlink from being walked into.
- *under `$HOME`* keeps system paths out of personal archives.
- *same device as `$HOME`* excludes an unlocked private vault, an external disk
  and a network mount mechanically, without a name list that rots. On a
  single-partition host the device test alone would admit `/etc`, which is why
  the `$HOME` prefix is also checked.

The archive is `<root>/<name>/<timestamp>.7z`, written under a temporary name in
the destination directory and claimed with `ln`, which is atomic and refuses an
existing target. The temporary name is unlinked afterwards.

Interactive runs let 7z draw its own progress; `--force` passes `-bsp0`.

### Encryption (`-e`)

Read the password twice from `/dev/tty` and compare, then pipe it once into
`7zz a -p -mhe=on`. Reading from the terminal rather than stdin keeps the
piped-answer behaviour of the confirmation intact and keeps the password out of
pipes, scripts and shell history.

Verification is `7zz t -p"$password"`. An unencrypted archive is verified the
same way without a password.

Verification passing is what permits the source to be deleted. Verification
failing leaves the source and the archive both in place, prints both paths, and
exits non-zero.

### Nix wiring

- `modules/directories.nix` gains `dotfiles.archive.root`, defaulting to
  `~/Archive`. Its activation creates that directory instead of the hardcoded
  one.
- `modules/scripts.nix` adds `_7zz` to `runtimeInputs` and passes
  `runtimeEnv.ARCHIVE_ROOT` from the option. `writeShellApplication` supports
  `runtimeEnv`, so no wrapper is needed.
- Run directly, the script falls back to `$HOME/Archive` and takes `7zz` from
  the host. A missing `7zz` dies naming the package, the way `vault.sh` names
  `fuse3` when no FUSE helper is present.

## Measured evidence

Everything below was measured on this host against 7-Zip 26.02 and rsync 3.5.0.

- **`7zz a` merges into an existing archive.** A second run at the same path
  produced an archive containing a file from the first run that no longer
  existed in the source, with no warning. A name collision on the compressed
  path is therefore worse than on the move path, where it would only add files.
- **`7zz a` fails if the target file already exists as a 0-byte placeholder**,
  so the `mkdir` reservation used by the move path does not transfer. `ln` does.
- **Only `a` accepts a password on stdin.** `t`, `l` and `x` read a password
  from neither a pipe nor a terminal — on a tty `7zz t -p` does not prompt at
  all, it uses an empty password and exits 2. Reading an encrypted 7z back
  requires the password on argv.
- **`7zz a` prompts once, with no confirmation**, so a typo is only catchable
  before the password reaches 7z.
- **`7zz t` exits 2 for a wrong password and for genuine corruption**, with the
  same message, so the command cannot distinguish them.
- **Following symlinks blindly explodes.** A five-file tree containing
  `up.link -> ..` became 121 files and 163 folders, recursing 40 levels to
  `ELOOP`, and a link to `/etc/passwd` had its contents archived.
- **No archive format preserves hard links.** 7z and zip both turned a 2-link
  inode into two independent files.
- **zip cannot encrypt file names.** `unzip -l` listed every path of a `zip -e`
  archive without a password. zip also lost on size, 401016 bytes against 7z's
  200444 on duplicate content, because it cannot deduplicate across entries.
- **`/proc` here is mounted without `hidepid`**, so another process's `cmdline`
  is readable by an ordinary user.

## Risks and accepted costs

- **Compression loses hard links.** No format preserves them, which is why
  compression is opt-in and the default move path stays `mv`/`rsync -aH`.
- **`7zz t` puts the password in world-readable argv** for the seconds it runs.
  Accepted: the alternative is deleting originals against an archive that was
  never read back. The exposure window is bounded by one `t` invocation.
- **The vault is excluded by a device test, not by understanding.** A private
  vault mounted somewhere that shares `$HOME`'s device would not be caught.
  No such configuration exists today.
- **A cross-device archive needs room for both copies** until verification
  passes, because nothing is deleted until then.
- **`cp -al` needs the mirror on the source's filesystem** to be free. A
  qualifying target on another filesystem falls back to a real copy.

## Scope

In scope: `scripts/bin/archive.sh`, `modules/scripts.nix`,
`modules/directories.nix`, `tests/archive_test.sh`, the archive section of
`README.md`, a `docs/DECISIONS.md` entry recording the accepted costs above,
the archive vocabulary in `CONTEXT.md`, and `_7zz` in `modules/packages.nix` —
the profile has to be able to read back what the command writes, and that is
`7zz x`.

Out of scope:

- Extraction. `7zz x` is the documented way to open these archives; the command
  does not grow a counterpart.
- Pruning, rotation or retention of old archives.
- Backups. `docs/DECISIONS.md` already names Restic over rclone as the
  direction for backing up the archive, and this is not that.
- Any archive format other than 7z.
- A desktop or graphical entry point.
- Recovering an archive whose password was lost.

## Verification

The seam is the command's own interface, which is the seam
`tests/archive_test.sh` already uses: it runs the bare `scripts/bin/archive.sh`
with `HOME` pointed into a temporary tree. No new seam is introduced. Every
behaviour here — root resolution, the move/copy split, compression, encryption,
the symlink policy — is observable by running the command and inspecting the
tree it produces, so tests assert on outcomes rather than on internals.

Existing coverage to preserve: hidden files, symlinks, hard links, empty
directories, the source being emptied but kept, archives not merging, unsafe
sources refused, and a stubbed `rsync` failure leaving the source intact.

To add:

- A same-device move keeps inode numbers, proving `rename(2)` rather than a copy.
- A cross-device move, forced by pointing `--to` at a separate filesystem,
  deletes the source only after verification, and leaves it intact when the
  verification pass reports a difference.
- `--to` and `ARCHIVE_ROOT` each redirect the destination, with `--to` winning.
- `-z` produces a `.7z` whose extraction reproduces the tree.
- A `.7z` name collision in one second produces a `-2` archive rather than
  merging, asserted by extracting both and comparing contents.
- An in-tree symlink survives as a symlink; a qualifying out-of-tree symlink
  becomes a real file; a symlink to a directory, to a path outside `$HOME`, and
  a dangling one all stay symlinks and appear in the plan.
- `-e` round-trips with the right password, fails with the wrong one, and its
  listing is refused without one.
- Mismatched password entries abort before anything is written.
- A verification failure leaves both source and archive, and exits non-zero.

Tests needing `7zz` fail with a sentence naming the package when it is absent,
matching how `tests/vault_test.sh` reports a missing `script(1)`.

## Definition of done

- `archive`, `archive -z`, `archive -e` and `--to` all behave as described, and
  `nix build .#homeConfigurations.z.activationPackage` succeeds, which is what
  runs `shellcheck` over the script.
- `tests/archive_test.sh` covers the list above and passes.
- `dotfiles.archive.root` is the only place the root is written down.
- The `README.md` archive section documents the flags, the plan, the hard-link
  cost of compression and the password rules.
- `docs/DECISIONS.md` records the accepted costs.
- This scratch directory is removed in the completion commit.
