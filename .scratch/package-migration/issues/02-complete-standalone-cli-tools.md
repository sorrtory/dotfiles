# 02: Complete the standalone global CLI tools

**What to build:** Make the reviewed standalone command-line baseline available in every user session through Home Manager, without migrating shell aliases, configured programs, desktop applications, development toolchains, or host integration in the same slice.

**Blocked by:** 01/Create the software installation catalog.

**Status:** ready-for-agent

- [ ] Home Manager installs `bat`, `curl`, ExifTool, `fd`, `fzf`, GnuPG, `htop`, HTTPie, ImageMagick, ripgrep, tealdeer, `tree`, `wget`, and `wl-clipboard` as global user tools.
- [ ] Canonical commands including `bat`, `fd`, `gpg`, `http`, `magick`, `rg`, `tldr`, `wl-copy`, and `wl-paste` resolve from the generated Home Manager profile.
- [ ] The host copy of `curl` remains an intentional bootstrap prerequisite while the Home Manager copy becomes the normal user-session command after activation.
- [ ] Ubuntu-specific `batcat` and `fdfind` aliases are left for the later Zsh migration.
- [ ] The software installation catalog links to the implemented Home Manager ownership for every package in this slice.
- [ ] Repository tests, flake evaluation, a non-activating local build, staging activation, and representative command smoke checks pass.
- [ ] No host activation, legacy installer retirement, or commit occurs before operator review.
