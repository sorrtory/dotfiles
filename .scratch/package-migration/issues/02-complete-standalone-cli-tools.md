# 02: Complete the standalone global CLI tools

**What to build:** Make the reviewed standalone command-line baseline available in every user session through Home Manager, without migrating shell aliases, configured programs, desktop applications, development toolchains, or host integration in the same slice.

**Blocked by:** 01/Create the software installation catalog.

**Status:** resolved

- [x] Home Manager installs `bat`, `curl`, ExifTool, `fd`, `fzf`, GnuPG, `htop`, HTTPie, ImageMagick, ripgrep, tealdeer, `tree`, `wget`, and `wl-clipboard` as global user tools.
- [x] Canonical commands including `bat`, `fd`, `gpg`, `http`, `magick`, `rg`, `tldr`, `wl-copy`, and `wl-paste` resolve from the generated Home Manager profile.
- [x] The host copy of `curl` remains an intentional bootstrap prerequisite while the Home Manager copy becomes the normal user-session command after activation.
- [x] Ubuntu-specific `batcat` and `fdfind` aliases are left for the later Zsh migration.
- [x] The software installation catalog links to the implemented Home Manager ownership for every package in this slice.
- [x] The ordered bootstrap flow activates the current Home Manager configuration after secret recovery without invoking `sudo`.
- [x] Repository tests, flake evaluation, a non-activating local build, staging activation, and representative command smoke checks pass.
- [x] No host activation, legacy installer retirement, or commit occurs before operator review.

## Answer

The standalone command-line baseline is declared in
[`modules/packages.nix`](../../../modules/packages.nix) and imported by the
Home Manager profile. `04-home-manager` provides idempotent bootstrap activation
after secret recovery. The generated profile was activated on the staging VM,
where every selected command resolved directly from its Nix store package.
