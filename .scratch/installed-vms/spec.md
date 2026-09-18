# Spec: Reproducible installed VMs

Status: needs-triage

## Why

The `vm-installation-media` effort solves how a verified ISO reaches
virt-manager, but an ISO is only an installation input. The operator wants
installed Ubuntu, Puppy and Windows guests that can be recreated, reset and
opened normally in virt-manager without committing multi-gigabyte disks or
putting libvirt under Home Manager.

## Decisions

- Keep KVM, QEMU, libvirt, virt-manager, `virtiofsd`, SELinux policy and
  privileged storage host-owned, as established by the virtualization
  decision.
- Keep VM definitions, provisioning scripts, cloud-init/autounattend inputs,
  image URLs and digests in this repository. Keep guest disks and installer
  media outside Git and the Nix store.
- Prefer a pinned Ubuntu cloud image plus a generated qcow2 overlay. Puppy and
  Windows use a prepared, operator-created golden image until their guest
  installation can be made unattended and verified.
- Never boot a golden base directly. Each named VM gets its own copy-on-write
  overlay, and reset removes only that overlay after an explicit confirmation.
- Generate UUIDs, MAC addresses and absolute disk paths at creation time rather
  than committing raw `dumpxml` output. Define the resulting domain through
  libvirt so it remains ordinary virt-manager state.
- Standardize the optional shared directory on VirtIO-FS. The host creates
  the dedicated share and applies the required SELinux context; guests mount
  or expose it using their native VirtIO-FS support.
- ISO acquisition remains optional and separate. Ubuntu cloud-image creation
  need not download an ISO; Puppy and Windows may depend on the verified media
  ticket when their golden images are rebuilt.

## Scope

In scope: an explicit VM project layout, pinned image/media metadata, base
image acquisition, qcow2 overlay creation, generated libvirt definitions,
cloud-init or unattended first boot where supported, VirtIO-FS host setup,
start/status/reset commands, tests with small fixtures, and operator
documentation.

Out of scope: replacing Fedora's virtualization stack, putting guest disks in
Nix or Git, unattended Windows licensing/activation, importing the operator's
existing personal guest state, and proving GPU acceleration on the staging VM.

## Dependencies

- `virtualization` bootstrap phase from the core migration.
- [`vm-installation-media`](../vm-installation-media/map.md) for rebuilding
  Puppy or Windows golden images from pinned installer media; Ubuntu's cloud
  image path can proceed independently.

## Guest targets

- Ubuntu: official cloud image, cloud-init, qemu-guest-agent, and a fresh
  overlay per VM.
- Puppy: one manually installed and configured golden qcow2, then overlays;
  the exact Puppy-family artifact must be selected in the media effort.
- Windows: one manually installed and updated golden qcow2 with VirtIO
  storage/network, guest agent, SPICE/VirtIO-FS tooling, and sysprep only if
  cloning becomes a requirement.

## Tickets

See [map.md](map.md).
