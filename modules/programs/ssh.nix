{ config, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/ssh";
in
{
  # Kept as a native config and live-editable: adding a host is a routine edit,
  # and the file is more readable in ssh's own format than in an option model.
  home.file.".ssh/config".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/config";

  # Public halves, carried for reference and for registering with a new host.
  home.file.".ssh/id_ed25519_github.pub".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/id_ed25519_github.pub";
  home.file.".ssh/id_ed25519_servers.pub".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/id_ed25519_servers.pub";
}
