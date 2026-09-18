# Reproducible installed VMs

Turn the host virtualization stack into reproducible installed Ubuntu, Puppy
and Windows guests with disposable overlays and a shared VirtIO-FS directory.
The ISO effort remains a prerequisite for guests that still need installer
media; it is not the VM lifecycle itself.

## Frontier

Ticket 01 is the first open, unblocked ticket and needs triage.

## Tickets

- [01: Choose the VM project boundary and host storage contract](issues/01-project-boundary.md) — needs-triage.
- [02: Provision Ubuntu from a pinned cloud image](issues/02-ubuntu-cloud-image.md) — needs-triage; blocked by 01.
- [03: Define the Puppy golden-image workflow](issues/03-puppy-golden-image.md) — needs-info; blocked by 01 and `vm-installation-media` 01.
- [04: Define the Windows golden-image workflow](issues/04-windows-golden-image.md) — needs-triage; blocked by 01.
- [05: Add VirtIO-FS shared-folder setup](issues/05-virtiofs-share.md) — needs-triage; blocked by 01.
- [06: Add lifecycle commands and verification](issues/06-lifecycle-and-verification.md) — needs-triage; blocked by 02, 03, 04 and 05.
- [07: Document the installed-VM workflow and retire the ISO-only ambiguity](issues/07-document-and-close.md) — needs-triage; blocked by 06.

## Context

- [`vm-installation-media`](../vm-installation-media/map.md) currently covers
  only a verified ISO under `/var/lib/libvirt/images`.
- Guest disks are mutable machine data and must not enter the repository,
  Nix store, or Home Manager activation.
- The staging VM can verify provisioning and guest control paths, but not
  host-GPU performance.
