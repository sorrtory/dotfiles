# 04 — Define the Windows golden-image workflow

Status: needs-triage
Blocked by: 01

## Goal

Make the prepared Windows guest reproducible without pretending that Windows
installation and licensing can be fully owned by Nix.

## Work

- Document the one-time ISO installation and Windows update procedure.
- Install and verify VirtIO storage/network, QEMU guest agent, SPICE tools,
  WinFsp and VirtIO-FS support in the golden image.
- Decide whether this is a single personal guest or a sysprepped clone base.
- Create overlays and generated libvirt definitions without committing the
  Windows image or product keys.

## Acceptance

- The workflow states which steps are manual and which are scripted.
- Reset never deletes the golden image or stores licensing material.
- The resulting guest appears and starts through ordinary virt-manager.
