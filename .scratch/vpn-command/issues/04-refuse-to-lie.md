# 04 — Prevent untunneled Vesktop instance handoff

Status: ready-for-agent
Blocked by: 03

## Goal

A managed launch must not silently hand its request to an untunneled Vesktop.

## Work

1. Check actual Vesktop singleton behavior and process identity for the Nixpkgs
   wrapper and the existing native installation. Comparing only the wrapper's
   executable path is not sufficient evidence.
2. Before handoff, distinguish an instance already in capture from one outside.
   Refuse the latter with an actionable message and PID when reliably known.
   Never kill the user's instance or delete singleton/session files.
3. Verify cold start, already-tunneled reuse, untunneled refusal, URL handoff and
   concurrent launch requests. Where ownership cannot be established safely,
   fail clearly instead of pretending the launch is tunneled.
4. Keep the checks Vesktop-specific for now. Do not add generic Snap, Flatpak,
   Obsidian, Spotify or VS Code detection.

## Acceptance

- An existing native or Nixpkgs untunneled Vesktop causes a clear refusal.
- A running tunneled instance receives normal managed launches/URLs correctly.
- Actual app process namespaces substantiate results; a new window is not proof.
- No force-bypass flag or destructive singleton cleanup.
