{ config, pkgs, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/mpv";

  # The one script Nixpkgs does not carry. It is load-bearing rather than
  # optional; see the package for why.
  localScripts = [ (pkgs.callPackage ../../packages/mpv-fuzzydir.nix { }) ];

  # Drivers for the GPU path. mpv is the only program here that needs one, so
  # it carries them in its own wrapper rather than the machine carrying them
  # globally: the alternative, Home Manager's `targets.genericLinux.gpu`, wants
  # a root-owned /run/opengl-driver symlink and nags at every activation until
  # it exists. These variables are the whole mechanism, and they cost nothing
  # when a machine's own drivers already work. LD_LIBRARY_PATH is deliberately
  # not among them: the manifests carry absolute store paths, so it is not
  # needed, and it would leak into every subprocess mpv spawns.
  gpuDrivers = pkgs.callPackage ../../packages/gpu-drivers.nix { };

  # Nixpkgs pins thumbfast one commit behind upstream, and that commit is the
  # one that matters on Linux: before it, thumbfast spawned its thumbnailer
  # with `env = "PATH=..."`, discarding every other variable, which is exactly
  # the environment a Wayland or X11 subprocess needs. Upstream now strips the
  # environment only on darwin. The legacy checkout was already on this commit,
  # so taking the Nixpkgs pin unchanged would have been a regression.
  thumbfast = pkgs.mpvScripts.thumbfast.overrideAttrs (_: {
    version = "0-unstable-2026-06-28";
    src = pkgs.fetchFromGitHub {
      owner = "po5";
      repo = "thumbfast";
      rev = "0f711de3138c9bd6718209d819ac54022c23ded2";
      hash = "sha256-LVeEtzOMVSgBqN9z6VQLZnxXfrOUoQPOWazVXmj3ZFY=";
    };
  });
in
{
  # programs.mpv owns the package; mpv.conf and input.conf stay native and
  # live-editable, because mpv re-reads them on restart and both files are
  # heavily commented.
  programs.mpv = {
    enable = true;

    # uosc replaces both mpv's builtin OSC and the vanilla-OSC fork the legacy
    # setup carried; it disables the builtin itself and draws thumbfast's
    # previews natively, so neither mpv.conf nor a local package is involved.
    extraMakeWrapperArgs = [
      "--set" "VK_DRIVER_FILES" "${gpuDrivers}/share/vulkan/icd.d"
      "--set" "LIBGL_DRIVERS_PATH" "${gpuDrivers}/lib/dri"
      "--set" "LIBVA_DRIVERS_PATH" "${gpuDrivers}/lib/dri"
      "--set" "VDPAU_DRIVER_PATH" "${gpuDrivers}/lib/vdpau"
      "--set" "__EGL_VENDOR_LIBRARY_FILENAMES"
      "${gpuDrivers}/share/glvnd/egl_vendor.d/50_mesa.json"
    ];

    scripts = (with pkgs.mpvScripts; [
      autoload
      reload
      cut
      uosc
      eisa01.smart-copy-paste-2
    ]) ++ [ thumbfast ] ++ localScripts;
  };

  xdg.configFile."mpv/mpv.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/mpv.conf";

  xdg.configFile."mpv/input.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/input.conf";

  # The shader bindings in input.conf reach these as `~~/shaders/Anime4K/`.
  # This is a symlink to the store directory rather than a copy, and the
  # package lays every .glsl out flat, which is why those bindings no longer
  # name a Restore/ or Upscale/ subdirectory.
  xdg.configFile."mpv/shaders/Anime4K".source = pkgs.anime4k;
}
