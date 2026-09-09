# 08: Migrate Sublime Text installation, configuration, and plugins

**What to build:** Select a safe Sublime Text installation mechanism, then keep selected preferences, keybindings, and a declarative Package Control package list as native files under `configs/sublime-text/`, with a reproducible way to establish Package Control itself.

**Blocked by:** 06/Add the basic desktop applications.

**Status:** ready-for-agent

- [ ] Do not permit the pinned insecure OpenSSL 1.1 dependency globally; select a safe vendor or isolated alternative for Sublime Text.
- [ ] Track reviewed preferences, Linux keybindings, syntax-specific settings, and the Package Control installed-package list as native files.
- [ ] Do not copy downloaded `.sublime-package` archives, embedded Python libraries, sessions, caches, licenses, or the existing custom CA bundle.
- [ ] Determine and document a pinned, verifiable Package Control bootstrap rather than checking in opaque downloaded plugin archives.
- [ ] Use intentional `mkOutOfStoreSymlink` links from the Sublime Text program module.
- [ ] Verify the linked native configuration and plugin bootstrap on staging before operator review.
