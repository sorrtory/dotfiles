# 04 — Verify the documentation cutover

Status: resolved
Blocked by: 03

## Goal

Prove that the documentation tells one accurate story after the Fedora cutover.

## Work

1. Repeat the audit queries from ticket 01 and review every remaining match in
   context.
2. Check links among README, canonical documents, software catalog, and staging
   guide.
3. Run the repository's documentation-facing and general public-interface
   tests appropriate to documentation-only changes.
4. Confirm the diff contains no implementation, invented Fedora staging result,
   or accidental rewrite of unrelated user changes.
5. Append commands and results under `## Answer`, then identify the durable
   facts that should remain in canonical docs when this scratch effort is
   removed.

## Constraints

- The working tree may contain unrelated operator changes. Do not fold them
  into this milestone or revert them.
- Passing text searches is not enough; remaining Ubuntu, activation, and
  migration language must be reviewed semantically.

## Acceptance

- Canonical and operational documents agree on the current Fedora baseline.
- Ubuntu-specific history and guidance are preserved and correctly labelled.
- Home Manager is described as established without weakening the host-owned
  system boundary.

## Answer

Run on the Fedora host, 2026-09-20.

**Audit queries repeated.** No match remains:

```
$ grep -rn -iE 'selected Ubuntu|current migration host|being migrated|192\.168\.122\.(214|242)|Lubuntu|desktop-ubuntu' \
    --include='*.md' AGENTS.md CONTEXT.md README.md docs/
(no output)
```

Every surviving Ubuntu mention was read in context and kept deliberately: the
AppArmor/`userns` guidance (`README.md`, `docs/SOFTWARE.md`,
`docs/VESKTOP-APPARMOR.md`, `docs/DECISIONS.md`, `docs/MIGRATION.md`), the
`fdfind` and Ubuntu Dock rows, and the dated verification records. The Fedora VM
confirms the first group is distro-specific rather than stale: its `apparmor`
status line reads `unprivileged user namespaces are not restricted; no profiles
needed`.

**Links.** A script resolved every relative Markdown link and anchor across
`AGENTS.md`, `CONTEXT.md`, `README.md` and `docs/**`. It found one stale anchor,
`docs/DECISIONS.md -> STAGING.md#virtualization-verification`, which was
repointed to `#historical-ubuntu-verification`. All links now resolve.

**Tests.** `nix flake check` — all checks passed. `tests/*.sh` — 25 of 27 pass.
The two failures are environmental and pre-existing, unreachable from a
documentation change: `bootstrap_docker_test.sh` needs superuser privileges, and
`vault_test.sh` needs `script(1)` from util-linux.

**Diff.** `git diff --stat` touches only `.md` files. The untracked `result`
symlink in the working tree was left alone.

### Durable facts to keep after this scratch directory is removed

1. Fedora is the current host; Home Manager is installed and in daily use there.
   Recorded in `docs/DECISIONS.md` "Platform and ownership", `CONTEXT.md`
   ("Current host"), `AGENTS.md` and `README.md`.
2. The repository stays cross-distribution. Fedora being current changes no
   ownership boundary: the host owns privileged integration and activation still
   never calls `sudo`.
3. Host activation is ordinary operator practice, but an agent still activates
   only after explicit approval.
4. The host cutover is complete; the feature migration is not, and no
   fresh-machine bootstrap has run on Fedora. Recorded in `docs/MIGRATION.md`
   "Status".
5. Ubuntu verification records are dated and attributed. Nothing measured on
   Ubuntu may be restated as a Fedora result.
6. The staging VM is `fedora` at `z@192.168.122.21`, Fedora 44 Workstation on
   GNOME/Wayland. `host-deps` and `nix` are verified there; `secret-recovery`
   onward is not. It replaced `silverblue43`, a Silverblue VM that could not
   bootstrap because `common/packages.sh` maps `ID=fedora` to `dnf`, absent from
   an rpm-ostree image, and `02-nix` installs Nix from an RPM onto a read-only
   `/`. Supporting rpm-ostree is unstarted work, recorded in `docs/STAGING.md`.

## Comments
