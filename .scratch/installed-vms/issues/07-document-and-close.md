# 07 — Document the installed-VM workflow and retire the ISO-only ambiguity

Status: needs-triage
Blocked by: 06

## Goal

Make the normal operator workflow clear and connect it to the existing host
virtualization and installation-media documentation.

## Work

- Document prerequisites, first-time golden-image steps, daily commands,
  storage locations, backup expectations and reset semantics.
- Clarify that ISO media is an input for image creation, not the installed VM
  itself.
- Update the README and canonical decision/migration docs only with decisions
  proven by the preceding tickets.
- Preserve the ISO effort's no-delete behavior and archive completed scratch
  coordination material only when the milestone is complete.
