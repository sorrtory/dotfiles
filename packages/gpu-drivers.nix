# GPU drivers built from Nixpkgs, for programs in this closure to use on a
# distro that is not NixOS.
#
# A Nix-built program cannot use the distro's drivers: its loaders read the
# distro's manifests, then fail to open the driver libraries those name,
# because they live in the distro's library path rather than in the closure.
# The program then finds no device at all. These are the same packages Home
# Manager's own `targets.genericLinux.gpu` collects; the difference is only in
# delivery, and the consumer points at this path through its own wrapper
# instead of a root-owned symlink. See docs/DECISIONS.md.
#
# Mesa covers AMD and Intel, including RADV and ANV for Vulkan. A proprietary
# Nvidia driver is deliberately not here: it has to match the running kernel
# module version exactly, which is a per-machine fact this repository does not
# have. Home Manager's module handles that case if a machine ever needs it.
{
  lib,
  stdenv,
  buildEnv,
  mesa,
  libglvnd,
  libvdpau-va-gl,
  intel-media-driver,
}:

buildEnv {
  name = "gpu-drivers";

  paths = [
    mesa
    libglvnd
    libvdpau-va-gl
  ]
  ++ lib.optional stdenv.hostPlatform.isx86_64 intel-media-driver;
}
