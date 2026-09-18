# 06 — Add lifecycle commands and verification

Status: needs-triage
Blocked by: 02, 03, 04, 05

## Goal

Provide a small, safe command surface for installed VM creation and daily
management.

## Work

- Add `create`, `start`, `status`, `reset` and read-only inspection commands.
- Use fixtures for image downloads and generated XML tests; never download a
  real ISO or guest disk in repository tests.
- Verify domain existence, disk backing chains, guest-agent reachability and
  shared-folder behavior where the guest supports an objective check.
- Run the completed flow on the local staging VM, recording the GPU limitation.

## Acceptance

- Repeating create is a no-op or reports the existing correct state.
- Reset requires an explicit target and cannot remove bases or unrelated VMs.
- All three guest targets can be represented by the lifecycle interface, with
  unsupported guest operations reported rather than guessed.
