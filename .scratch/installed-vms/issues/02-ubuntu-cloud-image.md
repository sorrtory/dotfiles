# 02 — Provision Ubuntu from a pinned cloud image

Status: needs-triage
Blocked by: 01

## Goal

Create an installed Ubuntu VM without reinstalling from an ISO on every
machine.

## Work

- Pin an official x86_64 cloud image URL and SHA-256 digest.
- Implement `vm fetch` to download and verify it outside Nix and preserve it
  as a read-only base. Make `vm create` invoke the same operation automatically
  when that base is absent, then create a qcow2 overlay for the named VM.
- Generate cloud-init with the staging user, qemu-guest-agent, networking and
  the shared-folder mount.
- Import the guest into system libvirt with generated machine-specific values.

## Acceptance

- `create ubuntu` yields a bootable installed guest and is idempotent.
- A second VM shares the verified base without sharing its writable state.
- `reset ubuntu` recreates only the overlay and cloud-init instance state.
