# 05 — Add VirtIO-FS shared-folder setup

Status: needs-triage
Blocked by: 01

## Goal

Expose one dedicated host directory to the installed guests using VirtIO-FS.

## Work

- Keep `virtiofsd` and SELinux labeling as host responsibilities.
- Generate the libvirt memory backing and filesystem device required by
  VirtIO-FS.
- Document mounting in the Ubuntu guest.
- Make the share path explicit and never point it at the repository root,
  home directory, secrets, or VM disk directory.

## Acceptance

- Ubuntu can mount the share at its documented path.
- A missing or inaccessible share fails clearly without weakening SELinux.
