# 00 — Grill the `vm` command

Type: grilling
Status: ready-for-human

## Goal

Run the Matt `/grill-with-docs` flow with the operator and turn the proposed
`vm` helper into a narrow, safe command contract before any implementation or
guest-specific architecture is accepted.

## Starting point

- The command is named `vm` and belongs in `scripts/bin/` as a global user
  tool exposed by Home Manager.
- The existing `virtualization` bootstrap phase remains responsible for the
  host stack. It must not create a guest during normal bootstrap.
- `/home/z/Downloads/create-ubuntu-vm.sh` is evidence and reusable code, not a
  specification. Its useful pieces include verified resumable image fetching,
  collision refusal, cloud-init, DHCP discovery, SSH checks and guest-agent
  checks.
- VM definitions, disks, snapshots, cached images and credentials remain
  machine-local data outside Git and the Nix store.
- `vm create` depends on `vm fetch`: if the required verified image is absent,
  creation fetches it through the same path automatically.

## Questions to grill

1. Is `vm` exclusively for repository-known disposable guests, or may it act
   on any libvirt domain? How does it prove that a destructive target belongs
   to it?
2. What is the minimum first surface beyond the settled `fetch` and `create`:
   `status`, `start`, `stop`, `restart`, `ssh`, `console`, `open`, `snapshot`
   and `remove`? Which commands do not earn their place?
3. Does `vm create` create one conventional staging guest, accept a guest
   profile such as `ubuntu`, or require an explicit domain name?
4. Is Ubuntu Server sufficient for bootstrap and service checks, while the
   existing Fedora Workstation guest remains the GNOME/Wayland target? Is an
   Ubuntu desktop guest also required?
5. Should reset mean restoring a named snapshot, rebuilding a writable overlay
   from a base, or neither? What exact word should the command use for each?
6. Are snapshots always taken with the guest shut down? Does the command own
   snapshot deletion, and is there a conventional `fresh` snapshot?
7. What confirmation is required for removal and snapshot restore? Should a
   non-interactive form require both `--yes` and an exact domain name?
8. Where do cached base images, writable disks and cloud-init seeds live, and
   which operations genuinely require `sudo` rather than libvirt/polkit access?
9. Is the cloud image pinned for reproducibility, refreshed explicitly, or
   followed through Ubuntu's `current` URL with a verified digest on each
   refresh?
10. Which initial guest packages and credentials preserve a meaningful fresh
    bootstrap test? In particular, should cloud-init avoid preinstalling tools
    that the repository's own bootstrap is supposed to establish?
11. Does the command consume the configured servers public key, use the SSH
    agent, accept a key option, or combine those paths? Is root SSH ever needed?
12. Is VirtIO-FS needed in the first Ubuntu milestone, or should it become a
    later effort after the basic command and lifecycle prove their boundary?
13. How should `vm` coexist with direct virt-manager edits without silently
    overwriting drift or claiming ownership it cannot prove?

## Required outcome

1. Record the operator's answer to every question above under `## Answer`.
2. Rewrite `spec.md` so it contains settled decisions rather than inherited
   proposals.
3. Narrow, replace or remove tickets 01–07 to match the accepted scope.
4. Preserve the image-fetching safety rules: fetch without unnecessary
   privilege, verify before installation, never leave a partial file looking
   complete, and use tiny fixtures in tests.
5. Make the next unblocked ticket mechanical enough for `/implement`.

## Constraints

- Do not implement the command during the grilling ticket.
- Do not copy guest disks, installer media, private keys or generated
  cloud-init secrets into the repository or Nix store.
- Do not broaden `vm` into a replacement for `virsh` or virt-manager merely
  because those tools expose more operations.
- Destructive behavior must default to refusal when ownership or the target is
  ambiguous.

## Answer

Pending the operator's Matt Pocock grilling session.
