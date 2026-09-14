{ config, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/nvim";
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

  # .vimrc is repository material rather than a configuration this machine
  # uses: it is a self-contained drop-in the operator copies to remote servers
  # that have Vim and nothing else. Vim itself is deliberately not declared,
  # so this is a store copy rather than a live-editable symlink.
  home.file.".vimrc".source = ../../configs/vim/.vimrc;
}
