# 02: Give Vesktop and its theme separate owners

Status: resolved
Blocked by: None (can start immediately)

**What to build:** Keep Vesktop's captured command, desktop links and palette
behavior intact while moving its app integration out of shared VPN code and
its stylesheet registration into the theme layer.

- [ ] The existing enable option still routes the command, desktop entry and
      `discord://` links through the VPN launcher; an untunneled running
      instance is still refused.
- [ ] Settings remain live-editable, first-launch state is seeded only once,
      and the exact Electron user-namespace allowance is preserved.
- [ ] The same fixed stylesheet path follows palette switches, and theme
      status still reports whether Vesktop has enabled it.
- [ ] Staging confirms the launcher and theme behavior before any separately
      approved daily-host activation.

## Answer

Vesktop packaging now lives in `modules/programs/vesktop.nix`, while stylesheet registration lives in `modules/theme/vesktop.nix`. Staging built and activated the generation, exposed the VPN command and desktop entry, installed the fixed-path stylesheet, and passed the existing launcher check.
