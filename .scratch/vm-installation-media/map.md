# Host-managed VM installation media

Add an optional host bootstrap phase immediately after `virtualization` that
installs one pinned and verified ISO for virt-manager without involving Home
Manager. See [spec.md](spec.md).

## Frontier

Waiting for the artifact choice in ticket 01.

## Tickets

- [01: Add the verified VM-image bootstrap phase](issues/01-add-vm-image-phase.md) — needs-info.

## Context

- The Yandex `puppyrus` mirror does not carry current official Puppy Linux
  releases.
- No ISO has been downloaded.
- The Fedora documentation cutover is tracked separately in
  [`fedora-docs-refresh`](../fedora-docs-refresh/map.md).
