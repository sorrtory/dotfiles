# 02 — Update the canonical platform narrative

Status: ready-for-agent
Blocked by: 01

## Goal

Make the canonical project language and decisions say that Fedora is the
current host and Home Manager is already the normal user environment.

## Work

1. Update `CONTEXT.md` only where new or adjusted vocabulary is needed to
   distinguish the current host, supported hosts, and staging evidence.
2. Update `docs/DECISIONS.md` so the platform section records the Fedora
   cutover while retaining the cross-distribution design and host/user
   ownership boundary.
3. Update `docs/MIGRATION.md` to distinguish completed host cutover from the
   feature slices that remain unfinished. Remove instructions that exist only
   to postpone normal use of an environment now in use.
4. Preserve real safeguards: normal activation has no `sudo`, privileged work
   stays in bootstrap, mutable session state stays local, and destructive or
   unverified retirement still waits for evidence.

## Constraints

- Do not rewrite dates, distro versions, or results of past Ubuntu staging
  checks as Fedora results.
- Do not declare the whole migration complete unless the migration document's
  remaining slices independently support that conclusion.
- Preserve Fedora-, Ubuntu-, and NixOS-specific exceptions where they remain
  technically true.

## Acceptance

- No canonical document describes adoption of Home Manager on the main host as
  pending.
- Fedora is named as the current host without changing the project into a
  Fedora-only repository.
- Current state, target architecture, and historical evidence are visibly
  distinct.

## Comments
