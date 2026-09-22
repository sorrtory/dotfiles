# `vm` command for installed guests

Provide one global user command named `vm` for creating and managing
machine-local libvirt guests. The exact command surface and initial guest scope
remain deliberately open until the operator grills the proposal.

## Frontier

Ticket 00 is the first open, unblocked ticket and needs the operator.

## Tickets

- [00: Grill the `vm` command](issues/00-grill-vm-command.md) — ready-for-human.
- [01: Choose the VM project boundary and host storage contract](issues/01-project-boundary.md) — needs-triage; blocked by 00.
- [02: Provision Ubuntu from a pinned cloud image](issues/02-ubuntu-cloud-image.md) — needs-triage; blocked by 01.
- [05: Add VirtIO-FS shared-folder setup](issues/05-virtiofs-share.md) — needs-triage; blocked by 01.
- [06: Add lifecycle commands and verification](issues/06-lifecycle-and-verification.md) — needs-triage; blocked by 02 and 05.
- [07: Document the installed-VM workflow and retire the ISO-only ambiguity](issues/07-document-and-close.md) — needs-triage; blocked by 06.

## Context

- Follow the repository's Matt flow: `/grill-with-docs` must settle the
  proposal before `/implement` begins.
- The intended front door is `vm`, not an Ubuntu-specific command and not an
  extension of the bootstrap dispatcher.
- `/home/z/Downloads/create-ubuntu-vm.sh` is candidate implementation evidence,
  not an accepted behavior baseline or a repository dependency.
- `vm` must provide a verified fetch operation for required images without
  putting them in Git or the Nix store. `create` uses that same operation when
  its image is absent.
- Windows remains a possible later profile. Its golden-image, licensing,
  overlay and removal-safety requirements are preserved in `spec.md`, but it
  has no active ticket and does not block Ubuntu.
- Guest disks are mutable machine data and must not enter the repository,
  Nix store, or Home Manager activation.
- The staging VM can verify provisioning and guest control paths, but not
  host-GPU performance.
