{ config, lib, pkgs, ... }:

let
  # Obsidian needs only TCP, so the local HTTP proxy is enough and it stays out
  # of the VPN capture namespace. The flag scopes the proxy to this process,
  # never the session. Vaults and session state remain machine-local.
  obsidian = pkgs.obsidian.override {
    commandLineArgs = lib.optionalString config.dotfiles.localProxy.enable
      "--proxy-server=http://127.0.0.1:3128";
  };
in
{
  home.packages = [ obsidian ];

  # Its Electron's sandbox needs a user namespace on Ubuntu, or Obsidian aborts
  # at startup. Nixpkgs' Electron is shared with Vesktop, and so is the profile.
  dotfiles.apparmor.usernsAllowances."electron-${lib.versions.major pkgs.electron.version}" = {
    executable = "${pkgs.electron.unwrapped}/libexec/electron/electron";
    usedBy = [ obsidian ];
  };
}
