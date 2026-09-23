# Decision Log

## Platform and ownership

Use Nix flakes, Home Manager, sops-nix, and age on generic Linux. Do not introduce chezmoi.

The current host is Fedora, and Home Manager is the established user environment
there: it is installed, activated, and used daily. That is a fact about the
operator's machine, not a narrowing of the project. The repository stays
cross-distribution, and the bootstrap keeps its Debian/Ubuntu, Fedora, and Arch
branches. Nothing below changes because the current host changed.

The host environment owns the kernel, hardware integration, display manager, NetworkManager, PipeWire, distro-coupled services, privileged networking prerequisites, and other low-level integration. The user environment owns user packages, development tools, shell and application configuration, personal scripts, GNOME preferences, and reproducible user secrets. The keyboard is split the same way: the user environment owns GNOME's input sources and XKB options, while the console and GDM keymap in `/etc/default/keyboard` stay host-owned.

Normal Home Manager activation must not invoke `sudo`. Root-owned files and system integration use explicit bootstrap or deployment actions.

The `host-deps` phase also guarantees a CA bundle at one of the four paths
Nix's own profile script probes, because Nix only exports `NIX_SSL_CERT_FILE`
when it finds one, and without it every Nixpkgs-built curl and git rejects TLS
with `unable to get local issuer certificate`. Fedora 44's release media ships a
`ca-certificates` too old to own `/etc/ssl/certs/ca-certificates.crt`, so a
machine installed from it has a working trust store at a path Nix does not look
at: `dnf`, `gh` and the distro's own `git` all succeed while the flake's `git`
cannot clone. The phase declares a short list of host packages that must be current rather
than merely present, and refreshes those. A whole-system upgrade in the phase
was implemented and then rejected on evidence: it is hostage to every enabled
repository, and on a fresh Fedora 44 Workstation `dnf upgrade` fails outright on
Cisco's `openh264` mirror, which carries nothing this repository needs. That
leaves the machine unbootstrapped, while refreshing the declared packages
succeeds in about 15 seconds on the same network. When a package must be
current, it joins that list; the phase does not grow another probe per package,
and when to upgrade the whole host stays the operator's decision.

On Arch the phase installs a missing package but never runs `-Sy`, because a
partial upgrade is how an Arch host breaks. A stale package there needs a full
`pacman -Syu`, and the check says so rather than guessing.

## Repository organization

Consolidate active configs, selected personal scripts, and public-safe SOPS material in this repository. Do not merge legacy repository histories.

- `modules/desktops/` owns GNOME and Hyprland concerns.
- `modules/programs/` owns application-specific configuration and the corresponding package.
- `modules/packages.nix` owns standalone global user tools.
- `configs/` holds readable native configs that should remain live-editable.
- `packages/` is reserved for software missing or inconvenient in Nixpkgs.
- `scripts/bin/` holds selected user-facing script sources.
- `scripts/repo/` holds repository-maintenance shell commands that are not installed into the user environment.
- `secrets/` may contain only public-safe secret material.

Create files only when their responsibility is migrated. Do not pre-create the project map.

## Package policy

Use the legacy `install.sh` and `install.conf` as the package baseline, not as an unconditional package list. Prefer Nixpkgs, then ecosystem package sets, before writing local packages.

A program module owns the package it configures. Standalone tools belong in `modules/packages.nix`; avoid declaring the same package in both places.

Where a Nixpkgs package is overridden because of a defect that is someone else's to fix — a patch, a version pinned forward or back, a missing build input — the override gets an entry in [WORKAROUNDS.md](WORKAROUNDS.md) alongside its comment, recording the packaged version the defect was observed in and the date it was last confirmed, and the entry is deleted in the same commit as the override. This log records what the repository has settled on; a workaround is the opposite of that, a thing carried until it can go, and the two do not belong on the same page. Overrides that encode our own integration rather than a defect, such as a proxy flag, are decisions and stay here. The distinction that matters is whether anything outside the repository has to change before the override can be dropped.

The initial global development baseline is Go through `pkgs.go`, Rust and Cargo, JDK 21, GCC/G++, Make, and `pkg-config`. JDK 21 includes the Java runtime, so a separate JRE is unnecessary. `pkg-config` has since left it for the host, for the reason given below. The exact versions are pinned by `flake.lock`; project development shells override them only when a project needs another version or dependency set.

CMake, Ninja, GDB and `clang-tools` joined that baseline later. Ninja rather than Make alone, because a project shipping a `CMakePresets.json` that names the Ninja generator fails outright instead of falling back to the Make beside it. `clang-tools` carries no compiler of its own; it supplies the `clangd` the editor was otherwise missing for C and C++, reading the `compile_commands.json` CMake writes.

Clang is a host package rather than a Nix one, installed by the `native-toolchain` bootstrap phase, and that is a deliberate reversal of the obvious choice. Two things settled it.

The first is mechanical. Nixpkgs' `clang` wrapper cannot share a profile with `gcc` at all: the two put twenty of the same names in `bin` — `cc`, `c++`, `cpp`, and every binutils name from `ar` and `as` through `ld`, `nm` and `strip` — and Home Manager's `buildEnv` fails on the conflicting paths rather than choosing between them. `lib.lowPrio` is not the escape hatch it looks like, because that check never consults a priority. A derivation linking only `clang` and `clang++` out of the wrapper does build and does install beside GCC, so this was never the real obstacle.

The second is what actually decides it. The consumer asking for Clang wants it to link the host's own libraries. Flutter's Linux desktop target hardcodes `CC=clang` and `CXX=clang++` in `build_linux.dart`, then compiles against GTK 3, so the compiler, the GTK development headers and the C library underneath them all have to agree. On a non-NixOS host the only set that agrees is the distro's, which is working rule 8 restated: the host owns low-level system integration. A Nix Clang reading `/usr/include` and linking `/usr/lib64` is the one combination to avoid, and installing a Nix Clang globally is how a build drifts into it by accident. The phase's status check is therefore a real compile: it builds a small GTK program with the host compiler in the operator's ordinary `PATH` and rejects the result if the binary carries `/nix/store`, which is what a Nix linker answering for the host compiler looks like.

Nothing is given up for projects that need a particular Clang. A Nix development shell prepends its own `bin` to `PATH`, verifiably shadowing a host compiler of the same name, and this repository's pin carries LLVM 12 through 23, so pinning one is a line in a shell rather than a change to the machine. The rule that keeps it safe is that such a shell owns the whole build environment, libraries included, rather than a compiler alone. direnv, below, is what enters it without being asked.

`pkg-config` moves to the host with Clang, and leaves `modules/packages.nix`. The Nixpkgs binary searches only its own store path — its `pc_path` is its own prefix — so while it sat first on `PATH` it could not see `/usr/lib64/pkgconfig/gtk+-3.0.pc`, and a GTK build failed at `pkg_check_modules` with the development package installed. Setting `PKG_CONFIG_PATH` globally would have fixed that one build while quietly letting every Nix development shell fall back to host libraries when it was missing one; removing the package instead leaves each side with the search path it should have, because a shell that needs `pkg-config` already brings it.

Android Studio is unaffected by all of this, despite being the program the question came from. The NDK ships its own Clang under `toolchains/llvm/prebuilt`, and `android.toolchain.cmake` sets `CMAKE_CXX_COMPILER` to that absolute path, so an Android build never consults `PATH` for a compiler and cannot be broken by what the profile does or does not provide.

Per-project toolchains need something to activate them, and that is direnv with `nix-direnv`. The global baseline above is deliberately shallow — Python is not in it at all, because projects own the versions they need — but a project development shell that has to be entered by hand is one the operator is free to forget. direnv hooks the shell prompt, walks up for an `.envrc`, and applies the difference that file makes to the environment, reversing it on the way out. `nix-direnv` is what makes that usable with flakes: it caches the evaluated shell instead of re-evaluating on every entry, and plants a GC root so `nix-collect-garbage` does not delete a toolchain that belongs to no profile. Authorization is per file and by hash, so a cloned repository's `.envrc` does nothing until it is allowed; this is a real boundary, because an `.envrc` is arbitrary shell that would otherwise run on `cd`. The mechanism is shell-only and stays that way: a desktop launcher has no prompt to hook, which is why anything a GUI program needs on `PATH` still belongs in `systemd.user.sessionVariables`.

Do not design around `cargo install` or `go install`. Prefer a Nix package or a project development environment.

The user environment has one base, the `nixos-26.05` pin, and one escape hatch beside it: the `nixpkgs-unstable` input, read through `unstablePkgs`. It is not a second base. A module keeps taking its packages from `pkgs` and names `unstablePkgs.<name>` only for the specific package stable cannot serve, so the set of packages ahead of the release is exactly the set someone wrote down. Three qualify today, for the two shapes the reason takes: sing-box needs the namespace support absent from the stable pin, a capability that is simply not there, while `gallery-dl` and `spotdl` need to be current, because their value decays between releases — the first tracks the sites it scrapes, the second resolves Spotify tracks through YouTube, and a stale copy of either fails on sites that have moved on. Anything taken from here owes a paragraph below saying which of those it is; "newer is better" is not a reason, since the release pin is the thing being traded away. A single input also means one lock entry moving on `nix flake update`, rather than several branch pins drifting apart.

Codex and Claude Code come from the independently pinned
`sadjow/codex-cli-nix` and `sadjow/claude-code-nix` flakes rather than stable
Nixpkgs or the aggregate `llm-agents.nix` package set. These focused providers
track the tools' fast release cycles and package the vendors' native binaries,
so installing Codex does not compile its large Rust workspace locally. Each
provider keeps its own tested Nixpkgs input instead of following this
repository's stable pin. Authentication remains machine-local mutable session
state. Their optional Cachix caches are not declared here because multi-user
Nix treats substituters and public keys as restricted host-owned settings; the
native packages already avoid source compilation without those caches.
Both commands opt into the local-proxy module's reusable wrapped-program list.
It exposes small launchers that always set the sing-box HTTP proxy at
`127.0.0.1:3128`; localhost remains exempt so local MCP servers and callbacks
do not make a needless proxy round trip. Other command-line tools can opt in by
declaring a name and package in the same list. This is an application
preference, not a network boundary: child processes inherit it, but software
can ignore proxy environment variables.

The official stable `yt-dlp` binary is an intentional exception: bootstrap installs the verified standalone Linux release under `~/.local/bin`, and `yt-dlp -U` performs explicit updates. Home Manager owns FFmpeg and PATH, but does not install a competing `yt-dlp` package.

`gallery-dl` deliberately does not repeat that pattern, despite looking like the same case. It advertises `-U`, but the updater only resolves a binary when the build sets its own variant marker, which a packaged install never does, and upstream stopped attaching assets to stable releases at v1.32.0: every `gallery-dl.bin` from v1.32.x is a 404, and no release has ever carried a checksums file, only detached GPG signatures. The two things the `yt-dlp` exception rests on — a verified official binary and a working `-U` — therefore do not exist here, and only the unsigned nightly builds in `gdl-org/builds` remain. Stable distribution is now PyPI and distro packages, which is what Nixpkgs packages, so working rule 3 applies unchanged.

It comes from the unstable pin rather than the stable one because its extractors track the sites they scrape: releases land roughly weekly, and the stable channel sat eleven of them behind at the time of writing. A stale extractor is not a cosmetic lag but a site that no longer downloads.

No downloader is a wrapped program of the local proxy, because none needs to be. The wrapper exists for Codex and Claude Code, which have no proxy flag or setting at all and read only the standard environment variables, so the sole lever is the environment they are started in. Every downloader here takes a proxy argument instead, which is the smaller tool: `download` reads `PROXY` and translates it into each backend's own spelling — `--proxy` for yt-dlp, gallery-dl and spotdl, `--all-proxy` for aria2c. `PROXY` is defined once by the local-proxy module, from the same binding the wrappers use, so a command cannot drift from the endpoint the service actually listens on. It is deliberately not `HTTP_PROXY` or `ALL_PROXY`: nothing reads `PROXY` implicitly, so naming it in the session tunnels nothing that did not ask. spotdl is the one backend whose flag is not enough: `--proxy` covers only its audio download, while its Spotify and YouTube Music lookups read the environment, and both are region-blocked on a direct connection. So `download` puts `PROXY` into spotdl's own environment as `HTTP(S)_PROXY`, scoped to that one process, and `modules/scripts.nix` patches spotapi — the Spotify scraper spotDL uses by default, whose TLS client ignored the environment entirely — to honour it.


Fetching and converting are two commands, `download` and `convert-to`, and no aliases at all. An alias exists only in an interactive Zsh, which leaves it unavailable to a script, a desktop launcher or a non-interactive `ssh`, and a family of them copies the format into every name. One argument carries that instead: a type downloads in the source's own format, an extension asks for that format, and the same argument picks the backend, so no URL is ever matched against a table of supported sites — yt-dlp covers on the order of 1800 and gallery-dl hundreds, and any such table is wrong the week it is written. Spotify is the one exception the URL has to be read for, because nothing else can fetch it. Spotify has no untouched audio source — spotDL finds a matching provider and encodes its output — so its URLs and `saved` query require an explicit audio extension rather than the bare `audio` type. Everything after the type reaches the backend verbatim, so `download` owns no destination flag: each backend already has one, and `-o` means four incompatible things across them.

The two commands never call each other. A downloader asked for a format is better at producing it than a later re-encode, because it still holds the source streams, chapters and metadata; `convert-to` is for files already on disk. Only images need our own converter, because gallery-dl has no image post-processor at all and upstream's documented answer is to drive ImageMagick through `--exec`.

Neither command removes anything the operator already had. `download` converts images into a sibling temporary file and claims the final name without replacement, keeping the downloaded source when that name already exists or conversion fails. It removes only what it created during the same run, and only after a conversion that both exited zero and wrote a non-empty file; it also skips any source holding more than one frame, because ImageMagick exits zero while exploding an animated WebP or AVIF into numbered files. `convert-to` works out every output before encoding starts and refuses the whole batch if one exists, so a collision costs a second rather than the length of the run, and refuses two inputs that would claim the same output whatever `--force` says, since one result would be lost either way. When `--force` does overwrite, a failed encode leaves the previous file alone rather than cleaning up what it did not create. All of this fixes a real defect in the legacy `convert-to-mp4`, which overwrote an existing `clip.mp4` silently and only after the transcode had finished. The one exception is explicit: `convert-to -R` (`--replace`) lets the output take the input's place, rewriting a same-format file in place or deleting a different-format original, because re-tagging an mp3 or converting a library otherwise leaves a `.converted` copy or a stale original behind by hand. The original is removed only after its replacement is installed and non-empty, keeps its file mode, and a failed or empty encode leaves it untouched; `-R` still respects collisions with files other than the input. The spelling is `-R` because everything else starting with a dash reaches ffmpeg, where `-r` and `-i` already mean frame rate and input.
The per-run opt-outs differ between the backends, which is why `PROXY=` is the single bypass rather than a flag anyone has to remember. `yt-dlp --proxy ""` is documented to mean a direct connection and does, and `aria2c --all-proxy ""` overrides a previous proxy the same way. `gallery-dl --proxy ""` does not: it treats an empty value as unset and falls back to the environment, so an empty `PROXY` has to add `-o proxy-env=false`, the option that stops it reading proxy variables at all. `NO_PROXY` works for a single host in all of them. They also propagate to the FFmpeg they spawn when the variables are set rather than the flag, since FFmpeg reads `http_proxy` and `https_proxy` itself; all of this was verified against a local probe proxy.

Two more findings are recorded here because they contradict what the flags look like they do. `yt-dlp --remux-video` fails outright when the target container does not support the codec rather than falling back to re-encoding, so `download mp4` always uses `--recode-video`, which is a no-op when the source already fits; `convert-to mp4` may remux only because it reads the codecs with `ffprobe` first. And `gallery-dl --proxy ""` is not a direct connection, as above.

Docker is host integration rather than a Home Manager package. Its bootstrap phase uses Docker's official stable convenience installer, previews the installer's package plan, invokes it with explicit privilege, and adds the invoking user to the `docker` group. Membership in that group grants root-level privileges and is therefore a deliberate operator choice. Its explicitly requested uninstall is a full reset: it removes the current user from the group, purges known Docker packages, removes Docker repository configuration, and deletes `/var/lib/docker` and `/var/lib/containerd`, including all local images, containers, volumes, and containerd state.

Sublime Text is a selected evaluation application even though both plugin hosts of build 4200, the Python 3.3 and 3.8 ones, link OpenSSL 1.1. That OpenSSL comes from Sublime's own tarball, which ships `libssl.so.1.1` and `libcrypto.so.1.1`, rather than from Nixpkgs. Nixpkgs marks `openssl_1_1` insecure and Hydra builds no insecure package, so the permitted-insecure exception it needed compiled OpenSSL 1.1 from source on every pin bump. The vendor copy is the same end-of-life runtime Sublime's official build runs, one patch release older (1.1.1v), so the exposure is unchanged, but Nix no longer flags it: this paragraph is the only record of the exception. Its compiled-in certificate directory is a sublimehq build prefix that exists on no machine, so the wrapper sets `SSL_CERT_FILE` to the Nixpkgs CA bundle unless the environment already names one. Two alternatives do not work. A host package cannot supply it, because neither Fedora 44 nor Ubuntu 26.04 ships OpenSSL 1.1 and the binary's rpath would not find a host copy without `LD_LIBRARY_PATH`. The unstable package drops OpenSSL 1.1 by deleting the 3.3 host, but Nixpkgs marks that build broken, and ignoring the mark leaves the 3.8 host unable to load its libraries, so no plugin runs at all. Once a stable build of 4205 or later lands, whose plugin host links OpenSSL 3, the override goes and the package comes straight from Nixpkgs. Native settings remain live-linked, and a hash-pinned Package Control archive bootstraps the declarative plugin list. Continued use beyond evaluation requires a Sublime Text license.

Anime4K comes from Nixpkgs `anime4k` rather than the pinned local package once expected, because Nixpkgs carries it and working rule 3 prefers that. The package lays every shader flat where the legacy checkout nested them, so the `input.conf` bindings name the file directly; re-nesting them in a derivation would invent a layout matching nothing upstream. Existing tmux and MPV ecosystem packages should not be repackaged locally, and a script is not carried at all when the player already does its job: `show_filename` was a whole pinned package for one `show-text ${filename}` binding, which is now a line of `input.conf`. Where Nixpkgs offers a better-maintained script under a legacy name it is preferred over reproducing the legacy one, and any key binding the swap would move is restored in `input.conf`; `reload` is the worked example, gaining automatic reload on a stalled cache while keeping `Shift+R`. The OSC went the same way: `uosc` replaces the legacy vanilla-OSC fork, retiring a local package, because a maintained Nixpkgs script that draws thumbfast previews natively is worth an appearance change the operator chose deliberately. The reverse case is `thumbfast`, where the Nixpkgs pin trails upstream by the commit that stops the thumbnailer subprocess from being spawned with a stripped environment on Linux; its source is overridden to upstream head rather than the package being reproduced locally. `mpv-cut` is a retained legacy script whose custom licence Nixpkgs marks unfree, so it is named in the unfree predicate alongside the desktop applications.

GPU drivers must come from this closure rather than from the distro. A Nix program's Vulkan and EGL loaders read the distro's ICD and vendor manifests but cannot open the driver libraries those name, because they live in the distro's library path; every manifest is skipped and no device is found. Verified on the staging VM and this host, where the loader passed over each Ubuntu ICD in turn.

The drivers themselves are a Nixpkgs `buildEnv` in `packages/gpu-drivers.nix`, and the consumer points at it through its own wrapper: five environment variables naming the ICD directory, the DRI and VA-API driver paths, the VDPAU path, and the EGL vendor manifest. That needs no privilege at all, which is the whole reason to prefer it — Home Manager's `targets.genericLinux.gpu` collects the same packages but delivers them through a root-owned `/run/opengl-driver` symlink and warns at every activation until someone creates it. A per-program wrapper is also honest about scope, but its scope is now narrower than the GPU's consumers: VS Code, Obsidian, Spotify and AyuGram are Nix-built too and fall outside it. The wrapper stays the first thing tried on a new machine because it needs no root. If MPV cannot reach the GPU through it, or those desktop applications need acceleration, switch to the system-wide module — `targets.genericLinux.gpu.enable = true` plus its `sudo` setup, which the `nix-gpu` bootstrap phase runs — rather than extending the wrapper. The README's "GPU-accelerated programs" section is the operator's checklist for that decision. The rest of `targets.genericLinux` is enabled, because its session integration is what lets GNOME find Nix-installed extensions and desktop entries through `XDG_DATA_DIRS`. That decision has now been taken: WezTerm, a Nix-built terminal, cannot open a window at all without drivers (EGL fails to load, and its Software front end fails the same way), so the GPU module is enabled and `/run/opengl-driver` is the route for every Nix program. MPV's wrapper is kept as well, since it costs nothing where the system link already exists. `LD_LIBRARY_PATH` is deliberately not set: the manifests carry absolute store paths, and it would leak into every subprocess, including the one thumbfast spawns.

A proprietary Nvidia driver would not work this way, because its userspace must match the running kernel module exactly. No machine here needs one.

MPV is what surfaced all of this, and it also showed the second half of the problem: `vo=gpu-next` named alone gives mpv nothing to fall back to, so a machine it cannot reach plays audio with no picture rather than degrading. Video output is therefore a list ending in software `x11`, and `gpu-api` is `auto`, which still prefers Vulkan where it exists.

The `fedora-amd-gpu` bootstrap phase is a separate concern from the Nix GPU
wrapper above: it installs the distro-level Mesa VA-API driver stack that
native (non-Nix) system programs and the kernel itself use, not the
Nix-built closure `gpu-drivers.nix` hands to MPV and friends. It exists
because of a specific AMD Phoenix APU (Ryzen 7640HS / Radeon 760M) VA-API
hardware-decode bug reproduced on this machine, and it self-gates on
Fedora plus a detected AMD GPU so it is safe to leave in the default
bootstrap run on any other host. DNF and RPM Fusion are pinned to Yandex
mirrors, matching the operator's own network across machines; that pin is
intentionally hardcoded rather than configurable, since no other host in
this repo needs a different mirror today.

The virtualization stack is host-owned: KVM comes from the host kernel, and
QEMU, libvirt, virt-manager, virt-install and UEFI firmware come from distro packages.
Keeping the GUI with the host stack avoids introducing a second libvirt/QEMU
installation through Home Manager. The privileged `virtualization` bootstrap
phase is part of the default flow on supported systemd-based x86_64
Debian/Ubuntu, Fedora and Arch hosts; NixOS requires host configuration instead.
It preserves the existing libvirt daemon layout, enables local sockets and boot
services, and starts the default network with autostart. Existing VM and network
definitions remain machine-local. It uses the distro's libvirt group and polkit
policy; membership grants privileged VM management. There is no destructive
uninstall action. Verification coverage is recorded in
[STAGING.md](STAGING.md#historical-ubuntu-verification).

## Configuration policy

Keep a readable native config when translating it to Nix would reduce clarity. Use `mkOutOfStoreSymlink` intentionally when immediate editability is valuable.

Home Manager owns Zsh, Neovim, tmux, MPV, Yazi, Git, and the intentional GNOME dconf settings: the Shell extension list, custom launchers and keybindings, input sources, Ubuntu Dock and appearance. Keys a GNOME component manages at runtime, such as the Mutter tiling keys Tiling Assistant overrides, are not declared, and neither are machine-specific ones such as the dock's preferred monitor. GNOME tools and extensions come from Nixpkgs rather than the distro, because the target machines span Ubuntu, Fedora and possibly NixOS. A distro's own session-mode extensions, such as Ubuntu Dock, stay distro-provided and are not listed. Migration may preserve selected native configuration first and translate it later.

`dotfiles.theme.name` selects one repository-owned palette of semantic roles
and sixteen ANSI colors. Applications translate those colors into their native
formats. A palette may override colors for one app, and an operator override in
`home.nix` wins over it. Stable theme names in application preferences keep a
switch to `home-manager switch`; `dotfiles.theme.transparency` independently
turns surface alpha on or off. The three dark palettes are gruvbox,
autumn-leaves and onedark. Stylix is not used because it would compete with
Rewaita's GNOME ownership and the native editor themes and would not preserve
the per-app override model.

Rewaita consumes the selected palette for GTK 3, GTK 4/libadwaita, GNOME Shell
and Firefox. Gruvbox starts from Rewaita's Gruvbox Medium colors, with GNOME's
orange accent and Yaru's warty-brown icon variant preserving the earlier
desktop look. Home Manager installs the User Themes extension and `adw-gtk3`,
seeds Rewaita's mutable preferences only when absent, and applies the selected
generated palette at activation and GNOME login. Rewaita owns generated GTK
and Shell CSS in native paths; its Fine Tune settings remain mutable. The
native package avoids a system-wide Flatpak write grant to GTK configuration.

Nixpkgs 26.05 and the repository's unstable pin both carry Rewaita 1.1.1,
which predates the command-line theme selector and Firefox generation described
by the current guide. A small local override pins upstream 1.1.7 until Nixpkgs
catches up. It also corrects the native build's broad data path: upstream relies
on Flatpak remapping `XDG_DATA_HOME`, so outside the sandbox it writes generic
`~/.local/share/prefs.json`, `light/`, `dark/` and `wallpapers/`; the package
keeps those beneath `~/.local/share/rewaita/` instead. Firefox profile and login
state remain machine-local. Only its two required `user.js` switches are
declarative; Rewaita writes the generated `chrome/rewaitaChrome.css` beside the
profile at login.

The Zsh module owns the shell package, generated startup files, Oh My Zsh,
shell plugins, history policy, and zoxide integration. It preserves the small
safe alias baseline and local proxy toggles. Neovim owns the single default
editor selection through its Home Manager module.
Runtime managers, media conversion, and integrations for deferred programs stay
with their respective future slices. The `vpn-up` and `vpn-down` commands,
beside `proxy-on` and `proxy-off`, remain whole-host controls; the application
VPN command does not replace them. `vpn-up` explicitly generates a
credential-free TUN config from the user backend's resolver and starts a
supervised root sing-box unit through host-labeled `/usr/bin/env`. `vpn-down`
stops that unit and removes its runtime config. The user backend keeps its
WireGuard identity and binds upstream sockets to the physical interface, so
whole-host capture does not start a second client or hand the peer to
`wg-quick`. Normal Home Manager activation never invokes sudo. The custom
tmux and file-navigation helpers, unused Powerlevel10k setup, and zsh-lazyload
setup are retired rather than reproduced. The host package supplies a stable
login-shell path, and the explicit `login-shell` bootstrap phase selects it;
normal Home Manager activation never changes the account shell.
Because Debian-family `/etc/zsh/zprofile` does not source `/etc/profile`, the
Zsh module loads the multi-user Nix profile script itself; otherwise the
selected login shell would start without the user environment on `PATH` or
`NIX_PROFILES`.
The phase's explicit uninstall selects the stable host Bash rather than trying
to infer historical account state.

Plugin ownership is decided per program rather than by rule. Nix owns tmux's three plugins and Yazi's one: all four are packaged, both sets are small and stable, and each program's own manager would otherwise cost a network fetch and a manual first run on every fresh machine. `lazy.nvim` and mason keep Neovim's plugins, because `lazy-lock.json` already pins them and moving them into Nix would trade live editing for a reproducibility an editor does not need that badly. These are two judgments about two specific plugin sets, not a general rule; the next program with plugins gets asked the same question again. What Neovim's choice costs is a first run that downloads about a gigabyte while the editor is being used, so the `nvim-plugins` bootstrap phase does it once, in advance: it drives lazy.nvim to the revisions `lazy-lock.json` pins, mason to the union of its two `ensure_installed` lists, and nvim-treesitter to its parser list, reading all three out of the editor's own plugin specs rather than keeping a second copy. It moves when that download happens and changes nothing about who owns it. Activation was rejected for it, because activation runs on every switch and a network fetch that size, with no timeout and no retry, does not belong there. The phase drives mason-tool-installer rather than mason-lspconfig because mason-lspconfig deliberately skips `ensure_installed` when Neovim is headless, and it asks for no updates: bringing a machine up to the declared set is the phase's job, while updating what is already installed stays the operator's. nvim-treesitter's `main` branch is the Neovim 0.12 implementation; unlike its frozen 0.11-era `master`, it delegates highlighting to Neovim and requires the `tree-sitter` CLI to build parsers, so the Neovim wrapper supplies that program-specific dependency.

The tmux plugins are linked under their upstream repository names rather than their Nixpkgs attribute names, reproducing the layout TPM created. That is what makes `prefix + Ctrl+d` work: the binding names resurrect's own `save.sh` beneath that path, and it failed on the legacy host only because nothing ever created the directory it named.

Where a retained plugin manager assumes something is already on `PATH`, Nix supplies it. That is why Node is a global user tool rather than a per-project one: mason installs ten of Neovim's language servers as npm packages, and they need Node to run, not only to install. Without it those servers fail to start and the editor looks subtly broken rather than obviously broken. The `fnm` shim the legacy `init.lua` carried is deleted rather than migrated, because a Nix-provided Node has no shell-dependent `PATH` to lose in a GUI or session launch.

Two toolchains are the deliberate exception to that, and they show what the
`fnm` shim got wrong rather than excusing it. `juliaup` and the Flutter SDK are
self-updating installations under `$HOME`, so Nix does not own the versions
they manage; their `bin` directories are named literally in `modules/packages.nix`.
The cost is that a directory on `PATH` is only as good as the launch path that
sets it, which is why they are declared twice: `home.sessionPath` for shells,
and `systemd.user.sessionVariables.PATH` for the desktop. Android Studio is the
consumer that makes the second one necessary — it is started from a launcher,
never a shell, and its Flutter and Dart plugins look for the SDK on the `PATH`
they inherit. Dart gets no entry of its own because the `dart` it would use
ships inside Flutter's `bin`. Being an `environment.d` file, the desktop half
is read at login, so a fresh install of either toolchain is visible to GUI
programs only after the next one.

Two Home Manager modules generate the very file a native configuration must occupy, and they are resolved differently. `programs.neovim` writes its generated `init.lua` into the directory this repository links whole, so `sideloadInitLua` hands that Lua to the wrapper instead of to a file; nothing is lost, because this configuration generates none. `programs.tmux` generates `tmux.conf` with no comparable hatch, so the tmux module declares the package with `home.packages` and links the plugins itself, keeping ownership of the package it configures without also owning a file the operator edits.

"Copy" in a file manager is three operations, and Yazi's own keymap gives two of them away cheaply while hiding the third. The path is `c c`, a preset. The file itself and the file's contents are not the same thing: one belongs on the system clipboard as `text/uri-list`, which is what makes a GUI application paste an attachment instead of a path string, and the other is text for an editor or a chat window. They get `y` and `Ctrl+y`, with `Alt+Shift+Y` for the same contents behind each file's path in a code fence. `y` runs `yank` before the clipboard plugin, so Yazi's own `p` keeps working; nothing is taken away by the override. The legacy `Alt+y` is retired rather than aliased, because three similar keys for three different operations is the point.

`!` opens a real `$SHELL` in the hovered directory, which Yazi's `;` and `:` are not: those are command-input boxes for a single command, with no history, aliases or job control. Both stay bound; they are a different tool, not a worse one.

This is also why `xclip` is now declared next to `wl-clipboard`. Both the tmux copy chain and Yazi's clipboard plugin choose their tool by session type, so an X11 session without it copies nothing — and the Ubuntu staging VM it was verified on ran X11, which would otherwise have left the feature unverifiable. `xsel` stays undeclared: it is only the third branch of the tmux chain, which reaches `xclip` first.

Git is the one program whose configuration is Nix-ified rather than kept native, and the reasoning inverts the tmux and Yazi cases. The file is eleven lines, the operator does not edit it in place, and `git config --global` writes to it, which a read-only store symlink would break rather than preserve.

That choice forces a migration step: Git ignores `~/.config/git/config` entirely whenever `~/.gitconfig` exists — not per key, the whole file, as `git config --list --show-origin` confirms. Home Manager writes the XDG path, so a leftover `~/.gitconfig` would leave the module silently inert. Activation moves it to `~/.gitconfig.pre-home-manager` rather than deleting it, and only when it is a real file, so an already-migrated home is untouched.

The legacy file carried delta and `merge.conflictStyle = zdiff3` commented out. That was intent never finished wiring up, so it is enabled rather than dropped. Home Manager binds delta through `pager.blame/diff/log/show` rather than a blanket `core.pager`, which is narrower than the commented block asked for and leaves everything else paging normally.

VS Code's `settings.json` and `keybindings.json` are linked out of store, but the operator rarely edits them by hand: VS Code's settings UI and Settings Sync write them. Both write through the link rather than replacing it, because VS Code writes a symlinked file in place instead of by temp-file rename; the check is `canWriteFileAtomic` in both the host's 1.121 and the pinned 1.119. So Settings Sync carries settings, keybindings and extensions between machines, and Git records what it wrote whenever the operator commits. Keys that differ per machine go in `settingsSync.ignoredSettings` so Sync cannot write them into the shared file. `http.proxy` is the exception that proves the rule: it is committed, because the local proxy answers on `127.0.0.1:3128` on every machine, and ignored by Sync so a machine without that proxy never receives it. `extensions.list` is an inventory regenerated with `code --list-extensions`, not an installer.

GNOME and Hyprland concerns remain separate. GNOME should use `dconf.settings` where practical; Hyprland may remain native and live-linked if that is clearer.

GNOME application shortcuts use Nixpkgs' Run or Raise extension to activate
matching windows directly, including switching workspaces and restoring
minimized windows. Repeated presses cycle through matching windows without
minimizing them. This replaces command-only launchers that can leave an
“application is ready” notification. The module's existing launcher table
generates the extension's native configuration because launch paths depend on
Home Manager values; the same keys are removed from media-key registrations.
Gradia's screenshot remains a media-key action. Obsidian matches both app
identity and the vault-name title suffix, keeping the knowledge database and
private Notes separate. Notes uses `always-run` to retain the existing vault
command's unlock check even if an Obsidian window survived a forced lock;
other app commands run only when no window matches. AyuGram still launches
through its VPN wrapper.

## Bootstrap policy

This section is the single source of truth for the bootstrap phase
contract. The
[`check-bootstrap-phases.sh`](../scripts/repo/check-bootstrap-phases.sh)
validator is its executable enforcement; other documentation links here rather
than restating the contract.

`scripts/bootstrap.sh` dispatches the ordered phases of the fresh-machine flow. Executable phase files live directly under `scripts/bootstrap/`, use contiguous two-digit `NN-name.sh` prefixes beginning at `01`, and run in lexical order. Renumber phases when inserting or reordering them. The numeric prefix controls order but is omitted from the logical name accepted by the dispatcher. Every executable phase belongs to the default flow; optional operations live outside that set.

A phase supports three commands:

- `status`: read-only and network-free; reports whether the required state is satisfied and includes a version when meaningful.
- `install`: skips successfully when the phase is already satisfied; otherwise it asks no configuration questions, performs only that phase's setup, and may prompt for authentication required to establish that state, including privilege, GitHub, or vault authentication.
- `uninstall`: available only for phases that own safely removable state; it refuses to continue when that state is already fully absent and otherwise removes all recognized complete or partial phase state while preserving unrelated configuration. Ensure-only phases report that they do not support uninstall.

The dispatcher exposes `status`, `install`, and `uninstall`. With no names, `status` inspects every phase and `install` ensures every phase in order. Aggregate status returns 0 when every selected phase is satisfied, 1 when at least one is unsatisfied, and 2 when at least one phase could not be inspected; it still inspects every selected phase. Installation stops at the first failure; rerunning checks earlier phases, skips those already satisfied, and resumes from the first unsatisfied phase. Explicit names preserve caller order. `uninstall` always requires one or more explicit phase names and never defaults to the complete flow.

Each phase enables `set -euo pipefail`, sources `scripts/bootstrap/common/phase.sh`, defines exactly one `check()` and `install()`, and ends with exactly one `phase_main "$@"` entrypoint. A reversible phase additionally defines exactly one `is_uninstalled()` and `uninstall()`; these functions must be provided as a pair. Strict mode makes a failed mutation stop immediately; the common entrypoint verifies this prerequisite at runtime. `check()` returns 0 when satisfied, 1 when unsatisfied, and a value greater than 1 when checking itself fails. The common command contract applies that result before installation and verifies the postcondition afterward. `is_uninstalled()` succeeds only when no recognized complete or partial phase state remains; the common contract similarly guards and verifies supported uninstallation.

Shared implementation lives under `scripts/bootstrap/common/` and is excluded from phase discovery. `phase.sh` owns the phase command contract, `output.sh` prefixes human-facing output with the logical phase name, `packages.sh` owns host package-manager adapters, and `sops-config.sh` reads the configured age recipient back out of `.sops.yaml`. That last one is also used outside the phases, by the recovery app under `scripts/repo/`: it lives here anyway because a phase may only source from `common/`, so the alternative would have a phase reaching into `scripts/repo/` instead, which crosses the sharper boundary. The packaged recovery app has no repository beside it, so its build copies `sops-config.sh` and `.sops.yaml` into the store by content and points the script at them; that keeps one implementation of the lookup rather than a second copy of the recipient. `require_commands` only validates; the explicitly mutating `ensure_commands` installs missing same-named packages through APT, DNF, or Pacman and fails clearly on unsupported hosts. Phase files use the common output helpers rather than calling `printf` directly.

The initial numbered flow starts with the ensure-only `host-deps` phase, installs Nix, runs `03-secret-recovery`, and then uses `04-home-manager` to activate the complete secret-bearing profile without privilege. `05-yt-dlp` installs the verified user-owned release binary, and the deliberately privileged `06-docker` phase establishes host Docker integration with an explicit full-reset uninstall. `scripts/bootstrap/02-host-deps.sh` is the authoritative inventory of commands required by later phases; documentation describes that responsibility without duplicating its changing contents. The Home Manager phase records a fingerprint of the flake source it activated, allowing its read-only status check to detect repository changes without evaluating Nix or using the network. Migrate the LXD proxy as its own ticketed Bash task.

Nautilus's built-in console action is not a default-terminal interface: upstream
hard-codes GNOME Console's D-Bus identity, and Fedora patches that identity to
Ptyxis. The generic `xdg-terminals.list` preference therefore remains useful
for GLib callers but cannot redirect Nautilus. Nautilus-Python menu providers
only add further items beside the built-in one, so WezTerm replaces Ptyxis on
the session bus instead: Home Manager installs a user D-Bus service file for
`org.gnome.Ptyxis` that starts `wezterm-console`, which opens WezTerm in the
requested folder. The user service directory takes precedence over the host's,
so no host file is modified and nothing needs root. This deliberately replaces
Ptyxis for every D-Bus caller, including its DBusActivatable desktop entry.

## Secrets and authentication

SOPS holds reproducible machine secrets. The recovery vault is the operator's main KeePassXC database; it holds passwords, recovery codes, human/root credentials, and an attachment containing the private age identity. OS or application keyrings hold mutable sessions such as GitHub CLI, Codex, OAuth, and browser logins.

The recovery repository is a fresh private repository containing only the encrypted KeePassXC database and non-sensitive documentation. It must not reuse the legacy secrets repository or its history. GitHub browser authentication and `gh repo clone` make this repository available during recovery; the resulting GitHub CLI credential remains mutable session state and should use a system credential store when available.

Recovery deliberately depends on no browser of its own, so bootstrap never installs one. GitHub CLI authentication uses the OAuth device flow: `gh` runs with its prompts disabled, prints the one-time code and URL, and waits while the operator approves on whatever device they choose. The wizard neither asks where a browser is nor guesses. The resulting token is only `gh`'s own session. Git's everyday access to GitHub is the SSH key, but that key is itself a SOPS secret, so it cannot exist before recovery. Recovery therefore skips gh's "Authenticate Git" setup, which would write a `~/.gitconfig` that Home Manager later moves aside, and passes `gh auth git-credential` to the one clone and pull that need it. A pre-set `GH_TOKEN` satisfies the same step unattended. Adding a browser to the recovery closure was rejected because it would download the browser on every fresh machine before Home Manager, including hosts that already have one, without removing any manual step.

The public dotfiles flake exposes a small recovery app whose runtime closure supplies GitHub CLI, KeePassXC CLI, and age after Nix installation but before Home Manager activation. The `secret-recovery` bootstrap phase invokes this app; callers still use the single bootstrap interface rather than running it separately. This avoids a separate secretless Home Manager profile. Its closure is not a one-off cost: git is already in the Home Manager closure, and the operator uses KeePassXC, GitHub CLI and age too, so `modules/packages.nix` declares them and both sides take plain, unoverridden Nixpkgs attributes, whose identical store paths activation reuses. A slimmer recovery-only build was rejected because it would be the one download used exactly once. The app obtains the recovery vault, lets KeePassXC prompt directly for its password, and extracts the age identity attachment without using arguments, environment variables, the clipboard, or logged standard output.

The recovery vault entry is addressed by its `keepassxc-cli` path, which starts at the root group and never includes the root group's own name. That path is case-sensitive and must be complete; a bare entry title is searched at every depth instead. `RECOVERY_ENTRY` overrides the default for a vault organized differently, and a failed export prints the `keepassxc-cli ls -R -f` command that lists the real paths.

`.sops.yaml` is the single source of truth for the public age recipient. It holds the recipient once, and the secret-recovery phase and the recovery app read it back from there rather than restating it. The reason to prefer it over any other location is that `sops` reads it when encrypting, so the recipient recorded there is by construction the one ciphertext is written to; a separate copy could disagree with it, and recovery would then verify an identity against a key nothing was encrypted to.

The sops-nix Home Manager module consumes that recovered identity and never generates one. Activation minting its own identity would produce a key this repository's recipient does not match, decrypting nothing while hiding a failed recovery behind an apparently successful activation.

The restored private age identity lives outside Git at `~/.config/sops/age/keys.txt`. Recovery refuses to overwrite an existing identity, writes a mode-`0600` temporary file, verifies its derived public recipient against repository configuration, and moves it into place atomically. Prefer an additional offline recovery copy. Only the public recipient belongs in repository configuration.

Decrypted secrets are materialized at mode `0400` under `/run/user/$UID/secrets.d`, which is tmpfs, and reached through a stable symlink directory at `~/.config/sops-nix/secrets`. A user-level systemd unit recreates them, so nothing plaintext is written to disk and nothing survives a reboot on its own.

Undeclaring a secret does not remove the copy already on the machine. sops-nix gates its whole configuration on a non-empty secret set, so removing the last secret makes the module inert rather than making it clean up, and the previously decrypted file and the runtime copy of the age identity both remain until the runtime directory is cleared. Removing or rotating a secret is therefore an explicit action, not a consequence of editing the module.

SSH private keys are reproducible secrets rather than machine-local state, reversing the earlier position recorded for the OpenSSH client. The reason is continuity: a fresh machine should reach the same hosts and produce the same signatures without first re-registering a public key everywhere, and a signing key in particular is not regenerable, since replacing it invalidates every signature already made under it.

The risk this accepts is that one reproduced key reaches every host it is authorized for, so compromising a single machine compromises all of them, and revoking it means replacing the public key everywhere at once. Per-machine keys would contain that blast radius and were considered and not selected. The mitigation is selection rather than isolation: migrate only keys that identify the operator, and treat a key that identifies one machine as a candidate for removal instead.

SSH private keys are whole-file SOPS ciphertext under `secrets/ssh/`, materialized on tmpfs and reached by absolute `IdentityFile` paths, so no plaintext key is written into `~/.ssh`. OpenSSH accepts a key from that location at mode `0600`; this was verified rather than assumed.

The SSH agent stays host-owned. The desktop session already provides one and sets `SSH_AUTH_SOCK`; adding a Home Manager agent would contend with it over which one a login session actually points at. The agent holds unlocked keys, which is the mutable session state `CONTEXT.md` keeps machine-local, so this is the same boundary rather than an exception to it. Because the keys no longer live in `~/.ssh`, where a keyring agent would find them by convention, `AddKeysToAgent yes` is what loads them, at the cost of one passphrase prompt per session.

A migrated key that carries its own passphrase still needs that passphrase on a new machine, and it is not in this repository — SOPS reproduces the key file, not the ability to use it. The passphrase belongs in the recovery vault alongside the age identity. `AddKeysToAgent yes` keeps this to one prompt per session.

The host-identifying half of `~/.ssh/config` is ciphertext for a different reason than the keys are: it is not a credential, but this repository is public, and host names, login names and ports together are a target list that published history would make permanent. The operator-independent half stays readable in `configs/ssh/config` and pulls the rest in through `Include`.

WireGuard configurations are whole-file SOPS ciphertext decrypted to a user-owned path, with no privileged deployment step. The legacy `wg-quick` path accepted that user-owned config directly, so `/etc/wireguard/` was unnecessary. Its ciphertext remains during migration until the replacement is proven under normal use.

The legacy WireGuard files are per-device identities. Each configuration names its legacy identity explicitly with `dotfiles.vpn.identity`, which has no default; the flake's `staging` configuration differs from `z` in that choice, and the home-manager phase remembers which configuration a machine activated. The legacy secondary `extra` configuration remains decrypted during migration. The native egress inventory changes the credential boundary deliberately: its one encrypted file contains the daily-host and staging peers, so either machine decrypts both and compromise of either exposes both. This accepts the shared-inventory exposure required for selectable egresses; it does not include the phone or other device identities. Encrypted policy assigns each WireGuard peer to exactly one hostname, and the runtime compiler excludes peers owned by other hosts while loading shared outbounds such as VLESS. A peer is never used by both machines at once. Adding identities to the inventory increases this blast radius and requires an explicit migration decision.

Secrets are named after the file they come from, so `wg-quick` takes the interface name from the basename and brings up the identity's name, such as `laptop`, and `extra`. A generic `wg0` would make the interface name identical across machines, which pays off only once something shared refers to an interface by name; nothing does, and renaming the one that needs it is a line of configuration when something eventually does. Until then the generic name costs a lookup every time someone reads a path and has to ask which device it means.

Starting the whole-host TUN needs `CAP_NET_ADMIN`. It is an explicit runtime action rather than machine setup; bootstrap and normal Home Manager activation do not start it. The root process is supervised by host systemd and reads only the credential-free generated config. `wireguard-tools` remains in the user package set for the retained legacy path until that path is retired.

Normal Home Manager activation does not create host network interfaces. It owns the unprivileged sing-box user service, whose userspace WireGuard endpoint needs no host interface. The application VPN command creates a TUN inside a rootless network namespace. The installed whole-host command explicitly starts a root supervised TUN at runtime. User namespaces widen what an unprivileged process can reach in the kernel, which is why Ubuntu restricts them; the application VPN decisions below record how that is handled.

Everything committed under `secrets/` must already be public-safe, and the staged secret gate enforces that mechanically rather than trusting the convention. Under that directory the test is inverted: elsewhere a file is rejected when it looks like a secret, but here it is rejected unless it is positively recognized as encrypted, because the likeliest way a key arrives is in a form no detection rule matches. Recognition asks `sops` itself, since marker strings can appear in a plaintext file's comments and prove nothing. Note the residual limit: SOPS permits partially encrypted documents, so this establishes that a file is a SOPS document rather than that every value in it is encrypted. Never copy a legacy secrets tree or expose plaintext through Nix expressions, logs, patches, or the Nix store.

## Private vault

The operator's private notes and personal files live in a gocryptfs filesystem
rather than a LUKS image, because it is per-file encryption over an ordinary
directory: it mounts without root, backs up file by file, and needs no fixed
size decided in advance.

A vault is named by the directory it mounts on. There is no registry, no daemon
watching one, and no default vault: a command acts on the path it is given, or
on `./Vault` in the working directory when it is given none. The ciphertext is
the hidden sibling of that directory, so `Vault` is stored in
`.Vault.encrypted`; `--storage` names storage that does not follow the rule.
`~/Vault` is only the convention the desktop uses, declared once as
`dotfiles.desktopVault` and read by both the `<Super>n` binding and the Lock
Vault entry. It is not a default the command knows about: a keybinding has
nowhere to type a path, so it has to carry one, and naming it once beats the
same literal in two modules. It says nothing about the vault's contents, since
`Notes/` is created by `vault notes` inside whichever vault it is given.

Unlocking is always explicit. Nothing mounts a vault at login or during
activation, and the vault's contents are the operator's data: activation never
creates one. Initialization is separate from opening and requires a terminal,
because gocryptfs shows the master key once and only to a terminal, and a vault
created without the operator seeing it has no recovery path. The master key is
never written to a file, a log or this repository; it belongs in KeePassXC,
beside the recovery vault's other material.

The password never passes through the repository's own code. gocryptfs asks for
it: on the terminal when there is one, and through a dialog given to `-extpass`
when the command came from a keybinding. A terminal always wins when there is
one. No password is stored anywhere, including keyrings.

Locking ends access and says so only when it can prove it: the kernel must show
no mount and the gocryptfs process must be gone. It cannot promise anything
about plaintext an application has already read, and it says so rather than
implying otherwise. A lazy unmount alone is not a lock — measured, not assumed:
after `fusermount3 -uz` the daemon keeps serving a descriptor opened before it,
and only SIGTERM ends that. So forcing does both. Blockers are found in `/proc`
and named; forcing is confirmed per attempt, never on a timer, and the question
is asked on the terminal or in a dialog depending on where the operator is.

Shutdown needs nothing from this repository: systemd sends SIGTERM and gocryptfs
unmounts and exits. Logout does, because `KillUserProcesses` defaults to `no`,
lingering is enabled, and a daemon started from a launcher sits in the user
manager's `app.slice` where no session stop reaches it. A user unit bound to
`graphical-session.target` closes the vaults at logout; it is a oneshot that
remains after exit, so nothing runs while the session is up and only its
`ExecStop` acts. Screen lock and suspend leave vaults mounted, and nothing
inhibits logout or shutdown.

gocryptfs comes from Nixpkgs. Its FUSE helper cannot: a store path is never
setuid-root, so the setuid `fusermount3` is host-owned everywhere except NixOS,
which supplies it through `security.wrappers`. The commands check for it first
and name the `fuse3` package when a host has none. A pristine Ubuntu 26.04
install already has it, so it is a check rather than a bootstrap dependency.

Backups are a separate milestone. Restic with Google Drive through its rclone
backend is the selected direction, covering the vault, the archive and other
user data. An encrypted working directory and a versioned backup repository
serve different purposes, and gocryptfs is not a backup manager.

## Archive command

The archive command moves by `rename(2)` within a filesystem and copies across
one. rsync never renames — measured, source inode 24600 against destination
24601 on one device — so the original rsync-always implementation rewrote every
byte to archive a directory onto the same partition. Across filesystems it
first renames the selected top-level entries into a sibling holding directory,
copies without `--remove-source-files`, compares both sides with `rsync -c
--dry-run`, and deletes only once they match. Freezing the names before copying
means a file created in the live directory during the run remains there for the
next archive instead of being deleted without ever reaching this one. Deleting
as rsync goes would leave the verification pass with nothing to compare
against, and the cost is needing room for both copies until it finishes.

`--keep` copies instead of moving, and the mechanism differs per case because
the three available ones are not interchangeable. Within a filesystem it is `cp
-a --reflink=auto`: on btrfs, which is what `/home` is here, that shares extents
with the source and diverges on write, so a 64 MiB tree clones in hundredths of
a second and occupies nothing until something changes; on ext4 or xfs the same
flag degrades to a real copy, so no filesystem test is needed in the script.
It is one `cp` for the whole tree rather than one per entry, because
`--preserve=links` only relates the files of a single invocation and copying
entry by entry would turn a hard-linked pair into two independent files. Across
filesystems it reuses the move path's `rsync -aH` and its `rsync -c --dry-run`
comparison unchanged. `mv` is what `--keep` can never use, which is the whole
point of the flag.

Nothing is frozen on a kept run and nothing is verified on a kept
same-filesystem copy. Both exist to make a deletion honest — the holding
directory so that a file arriving mid-run is not deleted without being archived,
the checksum pass so that originals are never removed against an archive nobody
read back. A run that removes nothing needs neither, and verifying a reflink
clone would re-read every byte the reflink was created to avoid. The accepted
cost is that an entry arriving mid-run may be included in a kept archive, and
that a kept archive's completeness rests on `cp` and `rsync` exit statuses
rather than on a comparison; the source is still present to compare against.

`--keep` is deliberately not a backup and is documented as not being one. It
produces a full copy under a dated path with no versioning, deduplication,
pruning or scheduling, which is the shape this repository already rejected in
favour of Restic over rclone. The flag exists for a snapshot before a risky
change. Naming it `--keep` rather than `--preserve` avoids the false friend:
in `cp`, `rsync` and `tar` that word means attribute preservation, so
`--preserve` would read as a statement about mtimes rather than about the
originals.

The staging mirror is now built only when a symlink actually qualifies for
resolution, which is what makes `--keep` usable on a directory that is its own
mount. The mirror must sit on the source's filesystem for `cp -al` to link into
it, and it is placed beside the source; a frozen tree is already there, but a
kept one on its own mount is not. Falling back to a real copy in that case would
write the whole tree out next to the mount — in cleartext, when the mount is an
unlocked gocryptfs vault — so the run is refused by naming the offending link
instead. With no link to resolve, the common case, the archive is read straight
from the tree, which also removes the `cp -al` pass from every ordinary `-z`
run. Measured: `7zz a -snl` over `dir/.` stores the same entries at the archive
root as it did over the mirror, symlinks included.

Compression is a flag, never the default, because no archive format preserves
hard links: 7z and zip both turn a two-link inode into two independent files. A
move preserves them, so the faithful behaviour stays the one you get without
asking.

7z is the only archive format, for encrypted and unencrypted alike. zip cannot
encrypt file names at all — its central directory is structural, and `unzip -l`
lists every path of a `zip -e` archive without a password — so the encrypted
path had to be 7z regardless, and a second format would mean two flag sets
where `-snl` and `-y` mean the same thing and forgetting either silently
changes what was archived. zip also loses on size, 401016 bytes against 200444
on duplicate content, having no solid block to deduplicate across entries.

Encrypted archives are verified with the password on the `7zz` command line,
which `/proc` exposes to any local process for as long as `t` runs. This is
accepted rather than preferred. Only `7zz a` will take a password on stdin;
`t`, `l` and `x` read one from neither a pipe nor a terminal, so there is no
mechanism that both reads an archive back and keeps the password off argv. The
alternative was deleting originals against an archive nothing had ever opened.
`7zz t` reports a wrong password and a damaged archive identically, so the
command does not claim to tell them apart.

The password is asked for twice and compared. 7-Zip prompts once with no
confirmation of its own, and an archive made with a mistyped password is
byte-for-byte as valid as a correct one, so nothing downstream can catch it and
the source would already be gone. `ARCHIVE_ASKPASS` names a command that prints
the password, following `VAULT_ASKPASS`; the password itself never goes in the
environment, which `/proc` exposes for a whole run and every child inherits.

A symlink is resolved into a real file only when its target is a regular file,
under `$HOME`, and on `$HOME`'s device. Each condition rules out a different
failure: following a directory symlink recurses — a five-file tree containing
`up.link -> ..` became 121 files and 163 folders before hitting `ELOOP` — a
target outside `$HOME` is not the operator's data, and a target on another
device is a mount, which is what excludes an unlocked private vault, a
removable disk and a network share without a name list that would rot. Links
inside the archived tree stay links, because their target is archived too.
Since 7z can only follow every symlink or none, the policy is applied after the
same holding rename by archiving a `cp -al` hardlink mirror in which qualifying
links have been replaced; the mirror costs almost nothing beside the held
source.

The archive name is claimed with `ln`, not by letting `7zz` write the final
path. `7zz a` merges into an archive that already exists without reporting it,
so a lost race would silently blend two unrelated archives. A sibling
`.reserve` directory claims the name before the plan is shown; the archive is
built under a private temporary name and hard-linked into the reserved final
name. Thus the destination the operator approves is the one the run uses.

`dotfiles.archive.root` is the one place the root is *configured*, reaching the
command as `ARCHIVE_ROOT` through a `:=` default rather than
`writeShellApplication`'s `runtimeEnv`, which would export unconditionally and
beat a caller who set it. Substituting it into the script text instead would
have left the bare script — which is how the tests invoke it — carrying a store
path or a broken placeholder. The literal `~/Archive` therefore appears twice,
in the module's default and in the script's own fallback: the duplication is
what buys a script that still runs with no Nix around it, and the two are only
ever read when nothing else has set the root.

## Scripts and privileged networking

The VPN decisions in this section describe the installed one-identity
backend and application capture. The [selectable egress spec](../.scratch/vpn-egress/spec.md)
defines the remaining concurrent-route migration. The app module split and
whole-host TUN passed Fedora staging and were activated on the daily host on
2026-09-23 with operator approval. The backend binds upstream sockets to the
detected physical interface, and the root TUN forwards only to its loopback
SOCKS listener. Daily-host proxy, application capture and one complete whole-host TUN cycle
passed, including backend loss and recovery. The encrypted legacy profile
stays available until network-change and suspend checks precede retirement.
The backend credentials now come from whole-file encrypted native inventory
and hostname policy, activated on the daily host after separate approval. Its
installed compiler loads only the selected peer for each machine. The staged
concurrent compiler loads that host's assigned WireGuard peer plus the shared
VLESS outbound; the daily host still awaits a separately approved cutover.

Source scripts may keep `.sh`; Home Manager may expose commands without the suffix. The VPN command and the proxy configuration generator are selected for the core milestone. Other utilities are additional candidates, and browser userscripts belong in the separate `monkeys` repository.

A command the operator runs keeps its Bash source under `scripts/bin/`; the VPN
command is `scripts/bin/vpn.sh`. Helpers only a module calls live beside that
module, so they are never exposed as user tools: the backend's configuration
generator sits in `modules/programs/sing-box/`, and namespace entry and capture
configuration in `modules/programs/vpnized-apps/`. A helper reaches its module
by store path, so keeping it off `PATH` costs nothing and keeps the installed
command set to what the operator actually types. Both kinds are packaged
with `writeShellApplication` from the separate source. The VPN command takes no
runtime inputs and reaches its helpers by absolute path, because the program it
launches must be found on, and inherit, the caller's own `PATH`. Payload
commands run as the invoking user with no capabilities.

Use one sing-box backend per machine for both the local SOCKS/HTTP proxy and
the VPN command. The command places one program in a rootless network namespace
owned by capture: a second, credential-free sing-box process started on demand,
whose TUN forwards TCP and UDP to the backend's local SOCKS endpoint, so there is
still one WireGuard peer connection. A proxy setting alone does not capture UDP,
which is why Discord voice needs the namespace; other programs keep ordinary
host networking. This replaced both the proposed separate kernel-WireGuard
backend and the legacy root-run veth/NAT launcher.

Tunneled programs lose connectivity rather than fall back to the host
connection. Each launch is a systemd scope bound to capture: a backend restart
keeps capture's namespace and restores traffic in place, a capture failure stops
the programs using it, and the last program's exit stops capture and removes its
runtime. Electron moves its main process into a systemd scope of its own, so the
namespace-entry helper, which outlives the program under the same PID, forwards
the stop itself. Scopes use `--job-mode=replace` and capture has no start limit,
because a launch right after the last exit otherwise collides with capture's
queued stop.

Namespace TUN support needs sing-box 1.14, taken from a `nixos-unstable` input
used only for sing-box so the rest of the environment keeps its release pin.
The initial local proxy ran 1.13.19 with no TUN or host route/resolver changes.

A VPNized application is installed by the module and reached only through the
VPN command. `dotfiles.vpnizedApps.vesktop.enable` replaces Vesktop's command,
desktop entry and `discord://` handler with a launcher. Electron hands a second
launch, links included, to the instance already running, and a running process
cannot move into another namespace, so the launcher refuses when Vesktop's main
process runs outside capture rather than let a link silently leave the tunnel.
This is routing, not a sandbox: running the package's raw executable bypasses
it. Vesktop runs without a tray, so closing the window ends the process and
capture's cleanup applies. Its settings are a live-editable file in
`configs/vesktop/`; activation seeds `state.json` once, because the first-launch
tour would reset those settings and can write an autostart entry outside the VPN.

On Ubuntu's restricted unprivileged user namespaces, capture's sing-box and
every Nix-built Electron each need an exact-path AppArmor `userns` allowance:
Vesktop's, and also VS Code's and Obsidian's. Those two start nowhere without it,
VPN or not. Modules register the executables with `modules/apparmor.nix`, which
generates one profile per executable and checks each is really used by the
declared package. The explicit `apparmor` bootstrap phase installs them with
sudo, and activation only warns when the installed ones no longer match.
[VESKTOP-APPARMOR.md](VESKTOP-APPARMOR.md) records the security trade-off.
Other Electron and Chromium programs abort, under the VPN command or not, until
they receive the same treatment.

`dotfiles.vpnizedApps.ayugram.enable` follows the same launcher-replacement
shape for AyuGram, needed because Telegram calls use UDP that a plain proxy
setting cannot capture. AyuGram is a single native Qt binary, not Electron, so
it needs no AppArmor `userns` allowance and no `usedBy` registration. Its
already-running check also differs from Vesktop's: Electron's main process is
identified by a fixed path substring in its own packaging
(`/opt/Vesktop/resources/app.asar`), but AyuGram's binary lives at a Nix store
path that changes on every rebuild, so its launcher compares each candidate
process's resolved `/proc/PID/exe` against this build's own binary path
instead.

VS Code and Obsidian are not VPNized applications. They need no UDP, so each
uses the local HTTP proxy through its own per-process setting, `http.proxy` or
`--proxy-server`, never a session-wide proxy variable.

Each machine uses its own WireGuard peer identity. Never share `extra` between
simultaneously connected machines, or run another `wg-quick` client concurrently
with sing-box using the same identity: independent clients make the server's
peer endpoint roam between them. The staged whole-host TUN forwards through
sing-box and does not start another WireGuard client.

Generate the proxy configuration at service start from whole-file SOPS
ciphertext, into a private user runtime directory. Validate it before starting
sing-box and keep keys out of arguments, environment variables, diagnostics,
and the Nix store. Application DNS goes through the tunnel; resolving a
WireGuard endpoint hostname is the sole host-DNS bootstrap exception. Capture
copies only resolver addresses from that configuration, and each tunneled
program gets a private resolver file in its own mount namespace, never the
host's. With no
profile DNS, use 1.1.1.1 through the tunnel. The explicit `user-linger` bootstrap
phase enables startup before login; Home Manager activation stays unprivileged.
Linger is shared by user services, so that ensure-only phase does not disable
it on uninstall.

## Migration and review

Legacy sources are evidence, not specifications. Select a behavior baseline, then deliberately retain, improve, replace, or remove each migration candidate. Prefer small coherent slices and do not combine unrelated relocation, package-manager, configuration-language, and behavior changes.

Use the Matt flow per slice: `/grill-with-docs` then `/implement` for small work; add `/to-spec` and `/to-tickets` for substantial work.

The working repository on the current host is authoritative. Activating a generation there is now ordinary operator practice rather than a deferred step, but it stays a decision the operator makes: an agent evaluates and builds freely and activates only after explicit approval. A staging VM, when one exists, is disposable and may be activated after a successful build; it is not a precondition for host activation.

The documented staging credential is intentionally public test data, not a secret. It must never be reused by a trusted machine or service.

Every resulting configuration receives operator review before commit. Subjective behavior also requires normal-use review. Automated review supplements these checks rather than replacing them.

Run a local mechanical secret scan on every staged change. Do not publish the repository before the dedicated public-safety gate passes.

Keep `.scratch/` only while coordination is active. Fold durable knowledge into canonical documentation and remove completed scratch material; Git history remains the record.
