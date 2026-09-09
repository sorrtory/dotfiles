# 07: Migrate VS Code native configuration

**What to build:** Keep selected VS Code user configuration as readable native JSONC files under `configs/vscode/` and expose them through intentional out-of-store links without importing mutable application state.

**Blocked by:** 06/Add the basic desktop applications.

**Status:** ready-for-agent

- [ ] Review the two legacy settings and keybinding variants and preserve only the intentional current behavior.
- [ ] Remove machine-local proxy values, temporary instruction paths, stale tool paths, and settings for unselected extensions unless deliberately retained.
- [ ] Track native `settings.json`, `keybindings.json`, snippets when present, and a human-readable extension inventory.
- [ ] Do not track credentials, Settings Sync state, global/workspace storage, history, caches, logs, or authentication sessions.
- [ ] Use intentional `mkOutOfStoreSymlink` links from the VS Code program module.
- [ ] Verify links and JSONC loading on staging before operator review.
