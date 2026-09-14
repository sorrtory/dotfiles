# 04 — Prevent untunneled Vesktop instance handoff

Status: resolved
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

## Comments — Implementation

The managed launcher (`modules/programs/vpnized-apps/vesktop.sh`) scans the
user's own processes for a Vesktop main process: argv[1] ends in
`/opt/Vesktop/resources/app.asar` and no `--type=` argument, since Electron
helpers carry one and sandboxed children have their own network namespaces by
design. If its `ns/net` is not the same file as capture's holder (compared
with bash `-ef`, no extra tools), or capture is not running, the launcher
refuses with the PID and never calls `vpn`. It kills nothing and touches no
singleton or session file; there is no bypass flag.

The previous exe-path comparison could never match Nix's wrapped Electron.
The native `/opt/Vesktop` case is out of scope: machines are bootstrapped
fresh. `tests/vesktop_launcher_test.sh` covers cold start with arguments,
ignored helpers and unrelated Electron apps, reuse inside capture, refusal
outside it, and refusal while capture is down. Real process argv and handoff
are verified on staging with ticket 05.

## Answer

Verified on staging: with the raw package's Vesktop running outside capture,
the managed `vesktop` exits non-zero with "Vesktop is already running outside
the VPN (PID N)" and starts no capture; with the tunneled instance running,
`vesktop discord://…` and `xdg-open discord://…` hand off to it and no second
main process appears. The first implementation matched argv[1], which never
matches because Chromium rewrites its cmdline into one space-joined string;
the check now matches the joined command line (13dab7d), and the test uses
both shapes.
