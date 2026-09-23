{ config, lib, pkgs, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/vscode";

  theme = config.dotfiles.theme;
  colors = theme.forApp "vscode";

  # The theme extensions a palette may name. A palette carries only the
  # publisher-qualified id, because a palette file is plain data and never
  # sees `pkgs`; this is where an id becomes a package, the way
  # configs/nvim resolves a colorscheme name to a lazy.nvim plugin.
  nativeExtensions = {
    "jdinhlife.gruvbox" = pkgs.vscode-extensions.jdinhlife.gruvbox;
    "zhuangtongfa.material-theme" = pkgs.vscode-extensions.zhuangtongfa.material-theme;
  };

  native = theme.assets.vscode or null;

  nativePackage =
    if native == null then null
    else nativeExtensions.${native.extension}
      or (throw "modules/programs/vscode: theme \"${theme.name}\" names extension \"${native.extension}\", which is not in nativeExtensions");

  # VS Code's own color-customization keys, as an app override rather than a
  # role: `dotfiles.theme.overrides.vscode.colorCustomizations`, the same
  # escape hatch `highlights` is for Neovim. They are merged into the theme
  # the local extension contributes, which is the one place that can hold
  # them without rewriting the operator's live settings.json.
  colorCustomizations = colors.colorCustomizations or { };
  customizationsJson = pkgs.writeText "vscode-color-customizations.json"
    (builtins.toJSON colorCustomizations);

  # A theme the palette draws itself, for a palette with no native extension.
  generatedTheme = pkgs.writeText "dotfiles-color-theme.json"
    (import ../theme/vscode-theme.nix { inherit lib colors; });

  extensionPublisher = "dotfiles";
  extensionName = "dotfiles-theme";
  extensionId = "${extensionPublisher}.${extensionName}";

  manifest = pkgs.writeText "package.json" (builtins.toJSON {
    name = extensionName;
    displayName = "Dotfiles theme";
    description = "The color theme declared in home.nix; see modules/theme.";
    publisher = extensionPublisher;
    version = "1.0.0";
    engines.vscode = "^1.70.0";
    categories = [ "Themes" ];
    contributes.themes = [{
      label = "Dotfiles";
      uiTheme = "vs-dark";
      path = "./themes/dotfiles-color-theme.json";
    }];
  });

  # One local extension contributing exactly one theme, always called
  # "Dotfiles". Its body is either the native theme the palette names, taken
  # from that extension's own `contributes.themes` rather than from a file
  # name guessed here, or the generated one. Either way the name is rewritten,
  # so configs/vscode/settings.json never has to change with the theme.
  dotfilesTheme = pkgs.runCommand "vscode-extension-${extensionId}"
    {
      # The version and the three vscodeExt* attributes are what Nixpkgs'
      # vscode-utils reads to write the extensions.json entry Home Manager
      # hands the editor; without them activation fails to evaluate.
      version = "1.0.0";
      nativeBuildInputs = [ pkgs.jq ];
      passthru = {
        vscodeExtUniqueId = extensionId;
        vscodeExtPublisher = extensionPublisher;
        vscodeExtName = extensionName;
      };
      meta.description = "The Dotfiles VS Code color theme, generated from ${theme.name}";
    }
    ''
      dir="$out/share/vscode/extensions/${extensionId}"
      mkdir -p "$dir/themes"

      ${if nativePackage == null then ''
        cp ${generatedTheme} "$dir/themes/dotfiles-color-theme.json"
      '' else ''
        src=${nativePackage}/share/vscode/extensions/${native.extension}
        path=$(jq -r --arg label ${lib.escapeShellArg native.theme} \
          '.contributes.themes[] | select(.label == $label) | .path' "$src/package.json")
        if [[ -z $path || $path == null ]]; then
          echo "modules/programs/vscode: ${native.extension} contributes no theme called ${native.theme}" >&2
          jq -r '.contributes.themes[].label' "$src/package.json" >&2
          exit 1
        fi
        cp "$src/$path" "$dir/themes/dotfiles-color-theme.json"
      ''}

      # The name is what VS Code lists and what settings.json selects; the
      # customizations are merged last so an override always wins.
      jq --slurpfile extra ${customizationsJson} \
        '.name = "Dotfiles" | .colors = ((.colors // {}) + $extra[0])' \
        "$dir/themes/dotfiles-color-theme.json" > theme.json
      mv theme.json "$dir/themes/dotfiles-color-theme.json"

      cp ${manifest} "$dir/package.json"
    '';
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    # The default profile only, so mutableExtensionsDir stays on: Home
    # Manager links these three in and leaves everything installed by hand
    # in place. The two upstream theme extensions are declared because the
    # Dotfiles theme is built out of them, and because the operator can still
    # pick them directly.
    profiles.default.extensions =
      [ dotfilesTheme ] ++ lib.attrValues nativeExtensions;
  };

  # VS Code reads a theme at startup and re-reads it on Reload Window, never
  # on a file change, so this is an ordinary store extension rather than one
  # of dotfiles.theme.liveFiles.
  dotfiles.theme.apps.vscode = {
    label = "VS Code";
    apply = "restart";
    restartNote = "Reload Window";
  };

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/settings.json";

  xdg.configFile."Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/keybindings.json";

  # VS Code bundles its own Electron, whose sandbox needs a user namespace on
  # Ubuntu, or the editor aborts at startup. Its network uses the local HTTP
  # proxy from settings.json rather than the VPN capture namespace.
  dotfiles.apparmor.usernsAllowances.vscode = {
    executable = "${config.programs.vscode.package}/lib/vscode/code";
    usedBy = [ config.programs.vscode.package ];
  };
}
