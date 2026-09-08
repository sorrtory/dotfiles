# 04: Migrate FFmpeg and the stable yt-dlp exception

**What to build:** Make FFmpeg available as a shared global media tool and provide the official stable `yt-dlp` binary through an explicit, reversible bootstrap phase, so retained media workflows work without introducing a competing Nix-installed `yt-dlp`.

**Blocked by:** 02/Complete the standalone global CLI tools.

**Status:** ready-for-agent

- [ ] Home Manager installs FFmpeg as a global user tool because it serves shell media functions, personal scripts, `yt-dlp`, and MPV-related workflows.
- [ ] Home Manager owns the stable dependencies and user-session PATH required by the official `yt-dlp` binary but does not install a Nixpkgs `yt-dlp` package.
- [ ] The bootstrap phase installs the official stable binary in the user's local bin directory and supports explicit self-updates through `yt-dlp -U`.
- [ ] Phase status is read-only and network-free, installation is idempotent, and uninstallation removes only state owned by this phase.
- [ ] Bootstrap structure and interface tests cover the new phase, including partial and already-satisfied state where applicable.
- [ ] FFmpeg conversion and `yt-dlp` version checks pass on staging without performing a media download.
- [ ] The software installation catalog links FFmpeg and `yt-dlp` to their distinct installation definitions.
- [ ] No legacy installer removal or host activation occurs before operator review.
