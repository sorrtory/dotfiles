{ config, lib, pkgs, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/nvim";

  theme = config.dotfiles.theme;
  colors = theme.forApp "neovim";

  # What configs/nvim/lua/theme.lua reads: the palette, whether to be
  # transparent, and which native colorscheme the theme declares, if any. A
  # theme that declares none is drawn from the colors instead.
  themeData = {
    name = theme.name;
    transparency = theme.transparency;
    colors = removeAttrs colors [ "alpha" "highlights" ];
    alpha = colors.alpha;
    highlights = colors.highlights or { };
  } // (theme.assets.neovim or { });
in
{
  # programs.neovim owns the package; the Lua tree stays native and
  # live-editable, and lazy.nvim keeps ownership of the plugins it already
  # pins in configs/nvim/lazy-lock.json. Nothing here declares a plugin, and
  # nothing translates Lua into an option model: the editor is reloaded with
  # `:source` far more often than the machine is rebuilt.
  #
  # The whole directory is one symlink rather than a file each, because
  # lazy.nvim writes lazy-lock.json back into it and the Lua tree grows new
  # files without a matching Nix edit.
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    # Home Manager writes its own generated init.lua into nvim/ by default,
    # which cannot coexist with owning the whole directory below. Sideloading
    # hands the same generated Lua to the wrapper instead of to a file, so the
    # escape hatch costs nothing: there is no generated configuration here to
    # lose, only the file it would have landed in.
    sideloadInitLua = true;
  };

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink configRoot;

  dotfiles.theme.liveFiles."${theme.dataDir}/nvim.lua" = pkgs.writeText "nvim-theme.lua"
    "return ${lib.generators.toLua { } themeData}\n";
  dotfiles.theme.apps.neovim = {
    label = "Neovim";
    apply = "restart";
  };

  # .vimrc is a self-contained drop-in: it configures the Vim in
  # modules/packages.nix and is also what the operator copies to remote servers
  # that have Vim and nothing else. It stays a store copy rather than a
  # live-editable symlink, because it is edited about as often as never.
  home.file.".vimrc".source = ../../configs/vim/.vimrc;
}
