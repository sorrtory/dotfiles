# Software installation catalog

This is the human-readable source of truth for how software in the user
environment is delivered. It records evaluated legacy candidates as well as
tools required by retained configuration and scripts. Linked implementation
files remain authoritative for exact mechanics, and `flake.lock` remains
authoritative for Nix package versions.

| Software | Purpose | Installation | Definition |
| --- | --- | --- | --- |
| age | Encrypt and decrypt SOPS data | Planned Home Manager package for the SOPS foundation | Not implemented |
| Anime4K | MPV video shaders | Planned pinned local Nix package | Not implemented |
| APT repository helpers | Add third-party Debian repositories | Legacy-only host tooling; do not reproduce as a global user package | Not implemented |
| Audacity | Audio editor | Deferred to desktop application review | Not implemented |
| bat | Syntax-highlighting file viewer | Selected Home Manager global user tool | Not implemented; package ticket active |
| `bc` | Arithmetic used by retained Hyprland helpers | Deferred to the Hyprland migration | Not implemented |
| brightnessctl | Backlight control used by retained Hyprland configuration | Deferred to the Hyprland migration | Not implemented |
| Bun | JavaScript runtime referenced by legacy shell configuration | Deferred; projects own runtimes unless a global requirement is selected | Not implemented |
| libcanberra (`canberra-gtk-play`) | Desktop sound-event playback used by a retained volume helper | Host-integrated desktop dependency; deferred to the Hyprland migration | Not implemented |
| Chrome | Web browser | Legacy vendor-repository installer; deferred to desktop application review | Not implemented |
| cliphist | Wayland clipboard history used by Hyprland | Deferred to the Hyprland migration | Not implemented |
| curl | HTTP transfer tool | Host prerequisite for bootstrap; also selected as a Home Manager global user tool | [Host prerequisites](../scripts/bootstrap/01-host-deps.sh); user package not implemented |
| DBeaver | Database client | Legacy vendor-repository installer; deferred to desktop application review | Not implemented |
| dconf Editor (`dconf-editor`) | Graphical dconf editor | Deferred to the GNOME migration and desktop application review | Not implemented |
| dnsmasq | DNS service used by the VPN namespace | Explicit host prerequisite for the later VPN command | Not implemented |
| Docker | Container runtime | Explicit privileged host setup; excluded from normal Home Manager activation | Not implemented |
| Dunst | Notification daemon configured by the Hyprland environment | Deferred to the Hyprland migration | Not implemented |
| ExifTool | Media metadata inspector | Selected Home Manager global user tool | Not implemented; package ticket active |
| `fd` | Filesystem search tool | Selected Home Manager global user tool, replacing Ubuntu's `fdfind` command name | Not implemented; package ticket active |
| FFmpeg | Audio and video processing shared by scripts, `yt-dlp`, and MPV workflows | Selected Home Manager global user tool | Not implemented |
| Firefox | Web browser | Deferred to desktop application review; login and profile state remain machine-local | Not implemented |
| Flatpak | Host-level desktop application infrastructure | Host-owned; excluded from normal Home Manager activation | Not implemented |
| fnm | Node.js version manager referenced by retained shell configuration | Deferred to the Zsh and development-environment migrations | Not implemented |
| `fzf` | Interactive fuzzy finder | Selected Home Manager global user tool | Not implemented; package ticket active |
| GCC and G++ | C and C++ compilers | Planned Home Manager global development baseline | Not implemented |
| Git | Version control | Host prerequisite for bootstrap; later owned and configured by a Home Manager program module | [Host prerequisites](../scripts/bootstrap/01-host-deps.sh); program module not implemented |
| gitleaks | Repository secret scanner | Nix development-shell tool used by repository checks | [Flake](../flake.nix) |
| GNOME Extensions Manager (`gnome-shell-extension-manager`) | Manage GNOME Shell extensions | Deferred to the GNOME migration and desktop application review | Not implemented |
| GNOME Tweaks (`gnome-tweaks`) | Configure additional GNOME preferences | Deferred to the GNOME migration and desktop application review | Not implemented |
| GnuPG | OpenPGP tooling | Selected Home Manager global user tool | Not implemented; package ticket active |
| Go | Go compiler and tools | Planned Home Manager global development baseline; replaces the downloaded system toolchain | Not implemented |
| Gradia | Screenshot annotation | Legacy Flatpak; deferred to desktop application review | Not implemented |
| Home Manager | Build and activate the user environment | Provided by the flake profile; its bootstrap activation phase is planned during package migration | [Flake](../flake.nix) and [home profile](../home.nix) |
| `htop` | Interactive process viewer | Selected Home Manager global user tool | Not implemented; package ticket active |
| HTTPie | Human-oriented HTTP client | Selected Home Manager global user tool | Not implemented; package ticket active |
| Hyprland | Wayland compositor | Host-integrated desktop software; deferred to the Hyprland migration | Not implemented |
| Hypridle | Idle management for Hyprland | Deferred to the Hyprland migration | Not implemented |
| Hyprlock | Screen locker invoked by retained Hyprland configuration | Deferred to the Hyprland migration | Not implemented |
| Hyprpaper | Wallpaper utility for Hyprland | Deferred to the Hyprland migration | Not implemented |
| Hyprpolkitagent | Authentication agent used by Hyprland | Host-integrated desktop software; deferred to the Hyprland migration | Not implemented |
| hyprshot | Screenshot tool used by retained Hyprland configuration | Deferred to the Hyprland migration | Not implemented |
| ImageMagick | Image conversion and processing | Selected Home Manager global user tool | Not implemented; package ticket active |
| `iproute2` | Network namespace and interface commands | Explicit host prerequisite for the later VPN command | Not implemented |
| iptables | Packet filtering and network address translation used by the VPN command | Explicit host prerequisite for the later VPN command | Not implemented |
| JDK 21 | Java compiler and runtime | Planned Home Manager global development baseline; replaces separate default JDK and JRE packages | Not implemented |
| jq | JSON processor used by privileged networking scripts | Planned dependency of the later VPN/proxy work, not currently a global package | Not implemented |
| KeePassXC | Password, recovery-code, and private age-identity storage | Application and database remain outside declarative public dotfiles | Not implemented |
| Kitty | Terminal emulator | Deferred to desktop application and native-config review | Not implemented |
| lazygit | Terminal Git client integrated by retained Neovim configuration | Deferred to the Neovim migration | Not implemented |
| LibreOffice | Office suite | Deferred to desktop application review | Not implemented |
| LXD | System container manager used by the legacy proxy | Explicit privileged host setup; excluded from normal Home Manager activation | Not implemented |
| Make | Build automation | Planned Home Manager global development baseline | Not implemented |
| MPV | Media player | Planned Home Manager program package with native configuration | Not implemented |
| MPV scripts | MPV behavior extensions | Planned Nixpkgs packages where suitable and pinned local packages where unavailable | Not implemented |
| Nautilus | Graphical file manager launched by retained Hyprland configuration | Deferred to desktop application review | Not implemented |
| Neovim | Text editor | Planned Home Manager program package with native Lua configuration | Not implemented |
| NetworkManager applet | Desktop interface for the host-owned network manager | Host-integrated desktop software; deferred to desktop migration | Not implemented |
| Nix | User-environment package and build system | Multi-user installation through bootstrap | [Nix bootstrap phase](../scripts/bootstrap/02-nix.sh) |
| Node.js and pnpm | JavaScript runtime and package manager | Deferred; use project development environments unless a global requirement is selected | Not implemented |
| OBS Studio (`obs-studio`) | Recording and streaming | Deferred to desktop application review | Not implemented |
| Obsidian | Knowledge-base application | Legacy Snap; deferred to desktop application review; session state remains machine-local | Not implemented |
| Oh My Zsh and Zsh plugins | Interactive shell framework and extensions | Legacy network installer; planned replacement through the Zsh Home Manager module | Not implemented |
| OpenSSH client | SSH access used by Git and remote workflows | Host-owned prerequisite; keys and authentication remain machine-local | Not implemented by this repository |
| pipx | Isolated Python application installer | Legacy dependency of Python `tldr`; replaced for that use and otherwise deferred | Not implemented |
| PipeWire tools (`wpctl`) | Audio control used by retained Hyprland configuration | Host-integrated desktop software; deferred to the Hyprland migration | Not implemented |
| playerctl | Media-session control used by retained Hyprland configuration | Deferred to the Hyprland migration | Not implemented |
| `pkg-config` | Native build dependency discovery | Planned Home Manager global development baseline | Not implemented |
| Powerlevel10k | Zsh prompt theme | Legacy shell asset; deferred to the declarative Zsh migration | Not implemented |
| Python | Python runtime and development environment | Not selected as a global baseline; projects own required versions | Not implemented |
| qt6ct | Qt 6 appearance integration referenced by retained Hyprland configuration | Deferred to the Hyprland migration | Not implemented |
| ripgrep | Recursive text search | Selected Home Manager global user tool | Not implemented; package ticket active |
| Rust and Cargo | Rust compiler and package manager | Planned Home Manager global development baseline; replaces Rustup for the global default | Not implemented |
| screen | Terminal multiplexer | Legacy candidate expected to be removed in favor of tmux | Not implemented |
| Shadowsocks | Proxy used by the legacy LXD setup | Deferred with the explicit LXD proxy migration | Not implemented |
| Snap | Host-level desktop and container application infrastructure | Host-owned; excluded from normal Home Manager activation | Not implemented |
| socat | Socket relay used by a Hyprland helper | Deferred to the Hyprland migration | Not implemented |
| sops | Encrypted configuration editor | Planned Home Manager package for the SOPS foundation | Not implemented |
| Spotify | Music application | Legacy vendor-repository installer; deferred to desktop application review | Not implemented |
| `spotify-launcher` | Spotify launcher invoked by retained Hyprland configuration | Deferred to desktop application review; selection must be reconciled with the legacy Spotify package | Not implemented |
| Sublime Merge | Git client | Legacy vendor-repository installer; deferred to desktop application review | Not implemented |
| Sublime Text | Text editor | Legacy vendor-repository installer; deferred to desktop application review | Not implemented |
| tealdeer | `tldr` documentation client | Selected Home Manager global user tool, replacing the pipx-installed Python client | Not implemented; package ticket active |
| tmux | Terminal multiplexer | Planned Home Manager program package with native configuration and packaged plugins | Not implemented |
| tmuxinator | tmux project launcher referenced by shell configuration | Deferred to the tmux and Zsh migrations | Not implemented |
| Transmission | BitTorrent client and command-line tooling | Deferred to desktop application and retained-script review | Not implemented |
| `tree` | Directory tree viewer | Selected Home Manager global user tool | Not implemented; package ticket active |
| `util-linux` namespace tools | `unshare` and `nsenter` used by privileged networking scripts | Explicit host prerequisites for the later VPN command | Not implemented |
| uv | Python project and tool manager recognized by a legacy maintenance script | Deferred; projects own Python tooling unless a global requirement is selected | Not implemented |
| Vim | Text editor | Legacy candidate expected to be replaced by Neovim | Not implemented |
| Visual Studio Code | Code editor | Legacy vendor-repository installer; deferred to desktop application review | Not implemented |
| Waybar | Status bar used by the Hyprland environment | Deferred to the Hyprland migration | Not implemented |
| wget | HTTP and file download tool | Selected Home Manager global user tool | Not implemented; package ticket active |
| WireGuard tools (`wireguard-tools`) | WireGuard interface commands | Explicit host prerequisite for later WireGuard deployment and the VPN command | Not implemented |
| `wl-clipboard` | Wayland clipboard commands | Selected Home Manager global user tool | Not implemented; package ticket active |
| Wofi | Wayland application launcher | Deferred to the Hyprland migration | Not implemented |
| X clipboard tools | Optional `xclip` and `xsel` fallbacks in tmux | Expected to be replaced by `wl-clipboard` on Wayland | Not implemented |
| xdg-utils | Desktop opener used by a retained navigation script | Host-integrated utility; delivery will be reviewed with that script | Not implemented |
| Yazi | Terminal file manager | Legacy Snap; planned Home Manager program package with native TOML configuration | Not implemented |
| `yt-dlp` | Media downloader | Planned bootstrap phase using the official stable binary with explicit self-updates | Not implemented |
| Zen Browser | Web browser launched by retained Hyprland configuration | Deferred to desktop application review | Not implemented |
| zoxide | Directory-jumping tool initialized by retained shell configuration | Deferred to the Zsh migration | Not implemented |
| Zsh | Interactive shell | Planned Home Manager program package and declarative shell configuration | Not implemented |
