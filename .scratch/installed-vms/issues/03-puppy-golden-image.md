# 03 — Define the Puppy golden-image workflow

Status: needs-info
Blocked by: 01

External dependency: `vm-installation-media` 01.

## Goal

Make Puppy reproducible from one deliberately prepared golden image while
acknowledging that Puppy is not a cloud-init-first distribution.

## Needed information

- The exact Puppy/PuppyRus distribution and ISO selected by the media effort.
- Whether the target is one personal Puppy guest or cloneable Puppy servers.

## Work

- Document the one-time ISO installation and guest configuration procedure.
- Capture the resulting qcow2 as a read-only golden base outside Git.
- Create named overlays and generate the matching libvirt definition.
- Verify reset returns to the golden state without touching the base.
