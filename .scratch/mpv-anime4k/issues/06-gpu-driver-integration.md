# 06 — GPU driver integration for a non-NixOS host

Status: claimed
Blocked by: 01, 04

## Goal

Make the GPU path this slice depends on actually work on Ubuntu, and decide
where the privileged step that enables it belongs.

## Why this exists

It was not in the original ticket set because nobody had run the migrated MPV
on a machine yet. Verification on the staging VM found that the Nix-built MPV
cannot initialize any GPU context at all:

```
[vo/gpu-next/libplacebo] Failed creating instance: VK_ERROR_INCOMPATIBLE_DRIVER
[vo/gpu-next] Failed initializing any suitable GPU context!
```

This is not a VM artifact. The same probe on the host, with `vulkaninfo` from
the pinned Nixpkgs, skips every one of Ubuntu's ICD manifests:

```
libvulkan_radeon.so: cannot open shared object file: No such file or directory
loader_icd_scan: Failed loading library associated with ICD JSON ... Ignoring this JSON
```

The loader in a Nix closure reads `/usr/share/vulkan/icd.d`, then cannot open
the driver libraries those manifests name, because they live in Ubuntu's
library path rather than in the closure. Putting Ubuntu's library directory on
`LD_LIBRARY_PATH` proves the diagnosis — the host's `AMD Radeon 760M (RADV)`
appears immediately — but it is a fragile trick, not a fix.

It matters because `mpv.conf` selects `vo=gpu-next` with `gpu-api=vulkan`, and
the Anime4K shaders this slice migrated exist only on the GPU path. Without
this, MPV falls back to software output and every shader binding is inert —
the slice's whole point, silently absent.

## What has been done

`modules/gpu.nix` enables `targets.genericLinux.gpu`, Home Manager's own
answer: build the drivers from Nixpkgs and point `/run/opengl-driver` at them.
Activation checks that symlink and prints the command when it is missing or
stale; it never escalates, so working rule 7 holds. `docs/DECISIONS.md` and
the README record it.

## Work

1. Run the privileged setup once on the staging VM, then confirm a Vulkan
   context initializes there:
   `sudo "$(readlink -f ~/.nix-profile/bin/non-nixos-gpu-setup)"`.
2. With a GPU context available, finish ticket 04's real acceptance: press
   `CTRL+1` through `CTRL+6` during playback and confirm no shader load error
   at `--msg-level=all=info`, and that `CTRL+0` clears. Until then the shader
   bindings are verified only as far as "the right files exist at the right
   paths and the property is set".
3. Confirm thumbnails and the uosc bar draw, which also needs the GPU path.
4. Decide whether this becomes a bootstrap phase. It has the shape of one —
   idempotent, privileged, explicit, with a check that reports state — and
   the alternative is a README step the operator must remember after every
   driver-moving `flake.lock` update. Docker is the precedent for a privileged
   phase; `login-shell` is the precedent for a small one.
5. Decide whether `targets.genericLinux.enable` should be set repository-wide
   rather than only its `gpu` submodule. It would also supply the Nix profile
   sourcing that `modules/programs/zsh.nix` currently does by hand — which is
   a Zsh-slice decision, so this ticket only raises it.

## Constraints

- Normal Home Manager activation must not invoke `sudo` (working rule 7). The
  current module obeys this; any bootstrap phase must keep the escalation
  explicit and separate from activation.
- Do not paper over the problem by putting the distro's library directory on
  `LD_LIBRARY_PATH` for graphical programs. It mixes two glibc worlds and will
  fail in ways that are hard to diagnose later.

## Acceptance

- A Vulkan context initializes for the Nix-built MPV on the staging VM.
- Anime4K modes load with no shader error, on the GPU path, under normal
  playback.
- The privileged step is either a bootstrap phase or a documented manual step
  the README states plainly, decided rather than left implicit.

## Comments

The drivers half is verified; only the privileged half is not.

Pointing a single mpv process at the driver set Home Manager already built —
`VK_ICD_FILENAMES` and `LD_LIBRARY_PATH` into
`targets.genericLinux.gpu.drivers` — took it from "no GPU context at all" to
`VO: [gpu-next]`, and everything gated behind the GPU path then worked:
Anime4K compiled in all six modes, uosc drew, thumbfast produced thumbnails.
Those environment variables are exactly what `/run/opengl-driver` makes
unnecessary, so this establishes that the module's driver set is the right one
and that the symlink is only a delivery mechanism.

What has not been run is the privileged step itself,
`sudo non-nixos-gpu-setup`. The sandbox in the session doing this work refuses
to send a sudo password to a remote host, which is the correct instinct, so
the VM has no `/run/opengl-driver` yet and no unprivileged program there sees
a GPU by default.

One detail for whoever runs it: with `hwdec=auto-safe`, mpv tried Vulkan video
decoding, hit `Device does not support the VK_KHR_video_decode_queue
extension` on the software device, and fell back to software decoding without
interrupting playback. That is the fallback behaving as intended, and it is
worth re-checking on the host, where RADV may accept the hardware path.
