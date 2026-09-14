# 01 — Shrink what recovery downloads

Status: needs-triage

## Problem

Phase 03's `nix run` realises a 0.83 GiB closure for a single use: the full
KeePassXC GUI build for its CLI, and a Nix git next to the host git that
host-deps already requires. See ../spec.md.

## Directions to evaluate

- A KeePassXC build without the GUI, or another CLI able to read the
  attachment, if one exists in Nixpkgs.
- Use host git (already a host-deps requirement) instead of packaging git.
- Whether the closure should be collected after recovery succeeds.

## Acceptance

- Measured closure before and after, on a fresh VM.
- Recovery still verifies the identity exactly as today.
