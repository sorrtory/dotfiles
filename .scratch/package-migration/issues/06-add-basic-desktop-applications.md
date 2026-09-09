# 06: Add the basic desktop applications

**What to build:** Install the selected basic graphical applications—OBS Studio, Obsidian, Spotify, and VS Code—from the pinned Nixpkgs input without restoring their legacy vendor repositories or Snap installations. Keep Sublime Text in its own slice because its pinned Nix package currently depends on insecure OpenSSL 1.1.

**Blocked by:** 05/Install Docker as explicit host setup.

**Status:** resolved

- [x] Nixpkgs supplies OBS Studio, Obsidian, Spotify, and VS Code from the repository's pinned input.
- [x] Unfree-package permission is restricted to the explicitly selected applications rather than enabled globally.
- [x] VS Code is owned by a dedicated program module that can receive native configuration later.
- [x] OBS Studio, Obsidian, and Spotify remain package-only declarations in the global package module.
- [x] The software catalog updates only these selected application rows.
- [x] The Home Manager profile builds and activates on staging, and representative version or executable checks pass without importing application session state.
- [x] No legacy vendor repository, Snap state, login state, or application profile is removed before operator review.

## Comments

- The first staging build exhausted the VM's former 15 GiB root filesystem. After expansion to 25 GiB, the same profile built and activated successfully.

## Answer

OBS Studio, Obsidian, and Spotify now come from the global Home Manager package module. VS Code is enabled through its own program module, ready for the separate native-configuration slice. Unfree permission is limited to Obsidian, Spotify, and VS Code.

After the staging root filesystem was expanded to 25 GiB, the complete profile built and activated without privilege escalation. The installed profile exposes all four executables and desktop entries; checks reported OBS Studio 32.1.2, Obsidian 1.13.4, Spotify 1.2.90.451, and VS Code 1.119.0. No legacy installation or application state was removed.
