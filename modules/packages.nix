{ claudeCode, codex, config, pkgs, ... }:

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

  home.packages = with pkgs; [
    # age, gh and keepassxc are also the secret-recovery app's closure. Plain
    # attributes from the same pin give identical store paths, so activation
    # reuses what recovery downloaded; an override here would fetch them twice.
    age

    bat
    cargo

    # clangd for Neovim, plus clang-format and clang-tidy. Deliberately not the
    # `clang` package: its wrapper ships cc, c++ and cpp, which collide with the
    # same names from gcc above and make the profile's default C compiler a
    # matter of which derivation won. The tools carry no compiler of their own
    # and overlap with nothing. clangd reads compile_commands.json, which CMake
    # writes with CMAKE_EXPORT_COMPILE_COMMANDS=ON.
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
    keepassxc

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
    pkg-config
    ripgrep
    rustc
    sops
    spotify
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

    # How the vault asks for a password when it is opened from a keybinding
    # rather than a terminal: gocryptfs runs it through -extpass and reads the
    # password from its stdout.
    zenity
  ];

  # Off by default outside NixOS, so a font in home.packages above would sit in
  # the profile unseen by fontconfig, and therefore by every non-Nix
  # application: the terminal, Nautilus, GTK apps in general. This is what
  # makes it discoverable system-wide instead.
  fonts.fontconfig.enable = true;

  home.sessionPath = [ "$HOME/.local/bin" ];

  # Desktop launchers and keybinding commands run in the systemd user manager's
  # environment, which never reads hm-session-vars.sh. Put the profile's bin
  # there too, ahead of the distro's directories, so a plain command name finds
  # the Nix program. A distro's Nix installer may already add it, but not every
  # login path does. Read at login.
  systemd.user.sessionVariables.PATH = "${config.home.profileDirectory}/bin\${PATH:+:}$PATH";
}
