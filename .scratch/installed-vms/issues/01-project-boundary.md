# 01 — Choose the VM project boundary and host storage contract

Status: needs-triage
Blocked by: 00

## Goal

Define the repository-owned interface for installed VMs before writing guest
provisioners.

## Work

1. Choose the project directory and command interface (`create`, `start`,
   `status`, `reset`, and `destroy` only where safe).
2. Select the host-owned base-image and overlay roots, with a configurable
   path but a safe default under the libvirt image storage boundary.
3. Define metadata for image URL, filename, digest, format, guest type and
   expected capacity.
4. Decide how generated libvirt XML receives names, UUIDs, MAC addresses,
   firmware, CPU/memory, disks, network and the shared filesystem.
5. Specify confirmation and refusal rules so reset cannot delete a base image,
   an unrelated domain, or an unrecognized overlay.

## Acceptance

- The contract distinguishes repository inputs, downloaded bases, overlays
  and mutable guest state.
- A clean host can identify what each command may read, create, modify and
  never remove.
- The Ubuntu workflow is narrow without preventing a later guest profile from
  using the same safe lifecycle.
