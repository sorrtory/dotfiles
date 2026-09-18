# Spec: Host-managed VM installation media

Status: needs-info

## Why

The host virtualization stack is already an explicit bootstrap responsibility,
but virt-manager has no repository-managed source for the installation media
the operator wants to use. ISO acquisition should be repeatable and verified
without making large mutable files part of Home Manager, Git, or the Nix store.

## Decisions

- Add a host-owned bootstrap phase immediately after `virtualization`.
- Keep it optional rather than adding a large network download to every full
  bootstrap run.
- Use a distro-installed fetch tool. Do not depend on the Home Manager profile
  to download host data.
- Store system-libvirt installation media under a dedicated directory beneath
  `/var/lib/libvirt/images`, readable by libvirt and virt-manager but not made
  broadly user-writable.
- Pin the chosen ISO URL and SHA-256 digest. "Latest" is resolved during a
  reviewed repository change, never dynamically during bootstrap.
- Download to a user-owned temporary file, verify it, then use privilege only
  to create the destination directory and atomically install the verified ISO.
- There is no uninstall action that deletes downloaded media or VM data.

## Open question

The Yandex `puppyrus` tree is not a current mirror of the official Puppy Linux
collection. Its modern-looking ISO names belong to PuppyRus-related projects;
the latest release-name date found there is `ow-d12-240503.iso`. Current
official Puppy releases are published through the upstream Puppy collection
and its listed mirrors, not Yandex. The operator must select which meaning was
intended before an artifact can be pinned.

## Scope

In scope: the optional bootstrap phase, host fetch prerequisite, checksum and
atomic-install behavior, dispatcher ordering, tests, and operator documentation.

Out of scope: installing virtualization itself, creating a VM, downloading an
ISO while developing or testing the phase, and placing media in Git or Nix.

## Tickets

See [map.md](map.md).
