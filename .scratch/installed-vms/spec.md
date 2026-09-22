# Spec: `vm` command for installed guests

Status: needs-info

## Why

The `virtualization` bootstrap phase installs the host virtualization stack,
but routine guest creation and lifecycle work still requires long `virsh` and
`virt-install` commands. The operator wants one global user command named
`vm` for that work, while every resulting domain remains ordinary machine-local
libvirt state and continues to open normally in virt-manager.

An existing `create-ubuntu-vm.sh` is useful implementation evidence: it
downloads and verifies an Ubuntu cloud image, creates a disk and NoCloud seed,
defines the guest, waits for cloud-init, discovers its address and verifies
SSH and the guest agent. It is not yet the specification. It currently mixes
provisioning with an interactive SSH session, runs wholesale under `sudo`,
uses a 20 GiB disk despite the staging record requiring at least 30 GiB, and
does not define the wider lifecycle or destructive-operation contract.

The command surface, ownership markers, snapshot semantics and first supported
guest must be settled with the operator through the Matt flow before this spec
becomes authoritative. See ticket 00.

## Current direction, pending grilling

- Expose one executable named `vm` from `scripts/bin/` through Home Manager.
- Keep the existing `virtualization` phase responsible only for host packages,
  services, access and the default network. A normal bootstrap must not create
  or download a guest.
- Use the host distro's `virsh`, `virt-install`, QEMU and libvirt rather than
  installing a parallel Nix virtualization stack.
- Start with the smallest useful guest workflow and leave room for additional
  guest definitions without turning `vm` into a generic libvirt replacement.
- Provide an explicit `fetch` operation for downloading and verifying the base
  images used by repository-known guests. `create` depends on that operation:
  when its required image is absent, it performs the same verified fetch
  automatically.
- Treat `start`, `stop`, inspection and opening virt-manager separately from
  destructive operations such as reset, snapshot restore and removal.
- Call rebooting `restart`; do not use the ambiguous name `reload` unless the
  grilling gives it one precise meaning.

## Decisions

- Keep KVM, QEMU, libvirt, virt-manager, `virtiofsd`, SELinux policy and
  privileged storage host-owned, as established by the virtualization
  decision.
- Keep VM definitions, provisioning scripts, cloud-init/autounattend inputs,
  image URLs and digests in this repository. Keep guest disks and installer
  media outside Git and the Nix store.
- Prefer a pinned Ubuntu cloud image plus a generated qcow2 overlay.
- Never boot the downloaded base directly. Each named VM gets its own
  copy-on-write overlay, and reset removes only that overlay after an explicit
  confirmation.
- Generate UUIDs, MAC addresses and absolute disk paths at creation time rather
  than committing raw `dumpxml` output. Define the resulting domain through
  libvirt so it remains ordinary virt-manager state.
- Standardize the optional shared directory on VirtIO-FS. The host creates
  the dedicated share and applies the required SELinux context; guests mount
  or expose it using their native VirtIO-FS support.
- `vm` owns explicit, verified fetching of the cloud images or installation
  media its guest definitions require. Large downloads remain outside normal
  bootstrap, Git and the Nix store.

These are inherited proposals from the earlier installed-VM effort, not final
decisions. Ticket 00 may keep, narrow or remove them before implementation.

## Scope

In scope: an explicit VM project layout, pinned Ubuntu image metadata, base
image acquisition, qcow2 overlay creation, generated libvirt definitions,
cloud-init first boot, VirtIO-FS host setup, lifecycle commands, tests with
small fixtures, and operator documentation.

Out of scope for the current implementation: Puppy, Windows support,
operator-prepared golden-image management, replacing Fedora's virtualization
stack, putting guest disks in Nix or Git, importing the operator's existing
personal guest state, and proving GPU acceleration on the staging VM. Windows
is a possible later improvement whose known requirements are preserved below;
it has no active ticket in this milestone.

## Dependencies

- `virtualization` bootstrap phase from the core migration.
- Ticket 00's `/grill-with-docs` session with the operator.

## Initial guest target

- Ubuntu: official cloud image, cloud-init, qemu-guest-agent, and a fresh
  overlay per VM.

## Deferred Windows profile

Windows may become a later `vm` guest profile, but the need is not established
enough to assign or implement it now. If promoted later, retain these
requirements:

- Prepare and update the Windows qcow2 manually where unattended installation
  is not worth owning. Record which steps are manual and which `vm` automates.
- Install and verify VirtIO storage and networking, the QEMU guest agent,
  SPICE tools, WinFsp and VirtIO-FS support in the prepared base.
- Decide explicitly whether the result is one personal guest or a cloneable,
  sysprepped base. Do not assume a personal installation can be cloned.
- Keep the base image, writable overlays, product keys and activation state
  outside Git and the Nix store. Never put licensing material in generated
  configuration or command output.
- Never boot or modify the prepared base during ordinary use. A named guest
  receives its own writable overlay and generated machine-local UUID, MAC and
  libvirt definition.
- Any future reset or remove operation must prove ownership of its target and
  must never delete the prepared base or unrelated storage.
- The resulting guest must remain an ordinary libvirt domain that opens and
  starts through virt-manager; `vm` must not create a parallel state system.

Promoting this section requires a new grilling/specification effort. It does
not block the Ubuntu command and should not quietly grow an implementation
ticket inside this milestone.

## Tickets

See [map.md](map.md).
