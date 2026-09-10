{ ... }:

{
  # A Nix-built graphical program on a non-NixOS distro cannot use the distro's
  # GPU drivers. The Vulkan loader in this closure reads Ubuntu's ICD manifests
  # under /usr/share/vulkan/icd.d, then fails to dlopen the driver libraries
  # they name, because those live in Ubuntu's library path and not in the
  # closure: every ICD is skipped and no GPU context initializes. MPV is the
  # first program here to need one — `mpv.conf` asks for `vo=gpu-next` with
  # `gpu-api=vulkan`, and the Anime4K shaders are GPU-only — but nothing about
  # the problem is MPV-specific, which is why this is its own module.
  #
  # Home Manager's own answer is to build the drivers from Nixpkgs and point
  # /run/opengl-driver at them, the path a Nix graphics closure already looks
  # for. Creating that symlink needs root, so activation only checks it and
  # prints the command to run; it never escalates by itself, which keeps
  # working rule 7 intact. The privileged step belongs to explicit host setup,
  # like Docker's.
  targets.genericLinux.gpu.enable = true;
}
