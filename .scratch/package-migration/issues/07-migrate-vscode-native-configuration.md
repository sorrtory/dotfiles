# 07: Migrate VS Code native configuration

**What to build:** Keep selected VS Code user configuration as readable native JSONC files under `configs/vscode/` and expose them through intentional out-of-store links without importing mutable application state.

**Blocked by:** 06/Add the basic desktop applications.

**Status:** resolved

- [x] Review the two legacy settings and keybinding variants and preserve only the intentional current behavior.
- [x] Remove machine-local proxy values, temporary instruction paths, stale tool paths, and settings for unselected extensions unless deliberately retained.
- [x] Track native `settings.json`, `keybindings.json`, snippets when present, and a human-readable extension inventory.
- [x] Do not track credentials, Settings Sync state, global/workspace storage, history, caches, logs, or authentication sessions.
- [x] Use intentional `mkOutOfStoreSymlink` links from the VS Code program module.
- [x] Verify links and JSONC loading on staging before operator review.

## Answer

The newer live settings and keybindings were reviewed against both legacy backup variants and migrated as strict JSON under `configs/vscode/`. Machine-local proxies, temporary instruction paths, the stale LLDB path, the Flutter SDK path, and settings for absent extensions were excluded. The current extension IDs are retained as a version-independent inventory; Home Manager does not install extensions or manage their session state in this slice.

The VS Code module links `settings.json` and `keybindings.json` with `mkOutOfStoreSymlink`. Staging activation completed without privilege escalation, both live links resolved to the repository files, their content matched byte-for-byte, and both files passed JSON parsing. Mutable VS Code storage remained machine-local.
