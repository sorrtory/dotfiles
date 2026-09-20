# 02 — Update the canonical platform narrative

Status: resolved
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

## Answer

- `CONTEXT.md`: retitled from "Dotfiles Migration" to "Dotfiles Context". Added
  **Current host** (Fedora, environment in normal use, not a narrowing of the
  project), **Supported host** (the three bootstrap branches; NixOS excluded),
  and **Staging evidence** (a result attributable to the machine it was measured
  on). **Staging VM** now says one exists only when the operator has provisioned
  it; **Core milestone** now names itself as the feature migration, distinct from
  the host cutover.
- `docs/DECISIONS.md` "Platform and ownership": one paragraph after the flake
  decision records Fedora as the current host with Home Manager established
  there, and states that the cross-distro design and the branches below are
  unchanged by it. The ownership split, the keyboard split, and "normal Home
  Manager activation must not invoke `sudo`" are untouched.
- `docs/DECISIONS.md` "Migration and review": host activation is now ordinary
  operator practice rather than a deferred step, while an agent still activates
  only after explicit approval. A staging VM is no longer a precondition for it.
- `docs/DECISIONS.md`: the `xclip` rationale now attributes the X11 session to
  the Ubuntu VM it was verified on rather than to "the staging VM".
- `docs/MIGRATION.md`: new `## Status` section separates the completed host
  cutover from the unfinished feature migration, and records that no
  fresh-machine bootstrap has run on Fedora. The method lost its
  "build without activating" / "activate on the staging VM" gate; a staging VM
  is now used when one is available and the check needs a disposable machine.
- `docs/MIGRATION.md`: the five "shipped on staging" slice records now name the
  Ubuntu staging VM explicitly, and the virtualization note says Fedora has
  command-flow tests only.

No date, distro version, or past result was rewritten as a Fedora result.

## Comments
