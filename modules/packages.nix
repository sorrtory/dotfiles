{ claudeCode, codex, config, pkgs, unstablePkgs, ... }:

let
  # Toolchains that install and update themselves under $HOME rather than
  # through Nix: juliaup manages the Julia versions it puts in .juliaup/bin,
  # and the Flutter SDK is a git checkout whose bin/ carries both `flutter`
  # and the `dart` it bundles, so Dart needs no directory of its own. Named
  # literally because no derivation here produces them.
  selfManagedToolchainPaths = [
    "${config.home.homeDirectory}/.local/share/flutter/bin"
    "${config.home.homeDirectory}/.juliaup/bin"
  ];
in

{
  dotfiles.localProxy.wrappedPrograms = [
    {
      name = "claude";
      package = claudeCode;
    }
    {
      name = "codex";
      package = codex;
    }
  ];

  home.packages = [
    # The one package here from the unstable pin. Its extractors track the
    # sites they scrape, so the months the stable channel trails upstream by
    # are sites that no longer download rather than a version number. It is a
    # plain package, not a proxy-wrapped program: it takes `--proxy`, so the
    # download aliases in the Zsh module pass one. See docs/DECISIONS.md.
    unstablePkgs.gallery-dl
  ] ++ (with pkgs; [
    # 7-Zip upstream rather than the p7zip fork, which trails it by years. The
    # archive command writes .7z and needs it at runtime; it is here as well
    # because opening an archive again is `7zz x`, and a command that creates
    # something the profile cannot read back is not finished. See
    # docs/DECISIONS.md.
    _7zz

    # age, gh and keepassxc are also the secret-recovery app's closure. Plain
    # attributes from the same pin give identical store paths, so activation
    # reuses what recovery downloaded; an override here would fetch them twice.
    age

    # Also a runtime input of `download`, which reaches it only through
    # `download file`. Here as well so `aria2c` works on its own, for a
    # torrent, a metalink or a resumed partial file. Same pin, same store path.
    aria2

    bat
    cargo

    # clangd for Neovim, plus clang-format and clang-tidy. The package carries
    # no compiler of its own and overlaps with nothing, which is what lets it
    # sit here while the `clang++` that compiles against the host's own
    # libraries comes from the native-toolchain bootstrap phase. clangd reads
    # compile_commands.json, which CMake writes with
    # CMAKE_EXPORT_COMPILE_COMMANDS=ON.
    clang-tools

    cmake
    curl
    exiftool
    fd
    ffmpeg
    fzf
    gcc
    gdb
    gh
    gnumake
    go
    gnupg

    # Screenshot annotation, opened by <Shift>F11 (see the GNOME module).
    gradia

    htop
    httpie
    imagemagick
    jdk21
    jq
    keepassxc

    lazygit

    # Patches Meslo with the glyphs Neovim's completion menu, lualine, neo-tree
    # and Yazi's file-type icons all assume are present in whatever font the
    # terminal actually uses. Meslo specifically because configs/vscode
    # names "MesloLGS Nerd Font Mono" as its terminal font. Installing the
    # family only makes it available; nothing here selects it as a terminal
    # font (see docs/SOFTWARE.md).
    nerd-fonts.meslo-lg

    # CMake's default generator in most projects that ship a CMakePresets.json.
    # A preset naming Ninja fails outright without it rather than falling back
    # to the Make beside it.
    ninja

    # Global rather than per-project because mason installs ten of Neovim's
    # language servers as npm packages, and they need Node at runtime, not
    # only to install. Without it the editor looks subtly broken rather than
    # obviously broken. See docs/SOFTWARE.md for the selection this settles.
    nodejs

    obs-studio


    qbittorrent
    # pkg-config is deliberately absent: the Nixpkgs binary searches only its
    # own store path, so first on PATH it hides the host's .pc files and a
    # build against system GTK fails at pkg_check_modules with the development
    # package installed. The host's own pkg-config comes from the
    # native-toolchain phase; a Nix development shell brings its own, with a
    # store-only search path that no longer leaks into it.

    ripgrep
    rustc

    # For bash-language-server, which Neovim's bashls runs and which reports
    # diagnostics only when shellcheck is on PATH, and for checking scripts by
    # hand before writeShellApplication rejects them at build time.
    shellcheck

    sops
    tree
    uv

    # Plain Vim beside Neovim, for the times the Lua configuration is the thing
    # that is broken and for muscle memory that predates it. It reads the
    # .vimrc the Neovim module installs.
    vim

    wget
    wireguard-tools
    wl-clipboard

    # The X11 half of the same job. Both the tmux copy-mode chain and Yazi's
    # clipboard plugin pick their tool by session type, so an X session — the
    # staging VM is one — needs this to copy at all.
    xclip

    yq

    # How the vault asks for a password when it is opened from a keybinding
    # rather than a terminal: gocryptfs runs it through -extpass and reads the
    # password from its stdout.
    zenity
  ]);

  # Off by default outside NixOS, so a font in home.packages above would sit in
  # the profile unseen by fontconfig, and therefore by every non-Nix
  # application: the terminal, Nautilus, GTK apps in general. This is what
  # makes it discoverable system-wide instead.
  fonts.fontconfig.enable = true;

  home.sessionPath = [ "$HOME/.local/bin" ] ++ selfManagedToolchainPaths;

  # Desktop launchers and keybinding commands run in the systemd user manager's
  # environment, which never reads hm-session-vars.sh. Put the profile's bin
  # there too, ahead of the distro's directories, so a plain command name finds
  # the Nix program. A distro's Nix installer may already add it, but not every
  # login path does. Read at login.
  #
  # The toolchain directories are repeated here for the same reason: Android
  # Studio is started from the desktop, not from a shell, so home.sessionPath
  # alone leaves its Flutter and Dart plugins unable to find the SDK. They go
  # after the profile so a Nix-provided command still wins.
  systemd.user.sessionVariables.PATH =
    builtins.concatStringsSep ":" (
      [ "${config.home.profileDirectory}/bin" ] ++ selfManagedToolchainPaths
    )
    + "\${PATH:+:}$PATH";
}
