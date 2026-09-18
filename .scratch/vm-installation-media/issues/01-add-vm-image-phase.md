# 01 — Add the verified VM-image bootstrap phase

Status: needs-info

## Goal

Make the selected Puppy-family ISO available to system virt-manager through an
explicit, idempotent, host-owned bootstrap phase immediately after
`virtualization`.

## Needed information

Choose whether the requested artifact is:

- the newest suitable x86_64 ISO actually present in Yandex's PuppyRus archive;
  or
- a current official Puppy Linux release from an upstream-listed mirror other
  than Yandex.

## Work

1. Pin the selected URL, filename, size, and SHA-256 digest in the phase.
2. Ensure the host prerequisites provide the selected fetch command.
3. Insert the optional phase directly after `virtualization`, renumbering later
   phase files and their tests without changing their behavior.
4. Download without privilege to a temporary file, verify the digest, then
   atomically install it under a dedicated `/var/lib/libvirt/images` ISO
   directory with root ownership and world-readable file mode.
5. Make `status` read-only and successful only for the exact verified artifact.
6. Refuse `uninstall`; bootstrap must never remove VM media or VM data.
7. Add command-flow tests that use a tiny fixture instead of the real ISO.
8. Document the optional phase, storage boundary, selected Puppy variant, and
   explicit update process.

## Constraints

- Do not discover "latest" dynamically during bootstrap.
- Do not download the real ISO while implementing or testing.
- Do not rely on Home Manager's `wget` or put the ISO in the Nix store.
- Never replace a different existing destination before the new download has
  passed verification.

## Acceptance

- `bootstrap.sh install vm-images` installs the pinned verified fixture in
  tests and is a no-op on a repeat run.
- `bootstrap.sh status vm-images` uses no privilege and detects absence or
  corruption.
- Interrupted or failed downloads do not leave a destination file that looks
  complete.
- The phase is ordered immediately after `virtualization` but remains optional
  during a default full bootstrap.
- No real ISO was downloaded during development.

## Comments
