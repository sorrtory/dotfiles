# 06 — Package it, expose it, and write down what it is

Status: ready-for-agent
Blocked by: 05

## Goal

Ship the command as part of the user environment, and leave the documents
describing what exists rather than what was planned.

## Work

1. Keep the source at `scripts/bin/vpn.sh` and package it with
   `writeShellApplication`, reading the separate file rather than embedding the
   script in a Nix string. `docs/DECISIONS.md` requires both.
2. Declare its runtime dependencies explicitly — `iproute2`,
   `wireguard-tools`, `iptables`, `util-linux`, `procps`, and whatever the
   instance checks need — so it does not inherit them from the host by luck.
   Note that `sudo` resets `PATH`; the re-exec must keep the wrapper's.
3. Expose it as `vpn` through a `modules/scripts.nix` the project map already
   anticipates, since this is the first script to move.
4. `docs/SOFTWARE.md`: a row for the command naming its mechanism and linking
   the module.
5. `docs/MIGRATION.md` §7: describe what shipped, including that DNS modes and
   host resolver rewriting were dropped rather than migrated.
6. `docs/DECISIONS.md`: record the boundary with sing-box in the terms the spec
   uses — opt-in proxy versus unconditional namespace — since that is the
   question a reader will have, and it decides which tool a future application
   should use.
7. Decide what happens to `vpn-up` and `vpn-down` in
   `modules/programs/zsh.nix`. They are not what this replaces: they put the
   whole host on the `laptop` tunnel, while this puts one application on the
   `extra` one. If they stay, their names should stop implying they are this
   command's relatives.

## Constraints

- Do not delete `~/Documents/scripts/vpn.sh`. Legacy material is retired by
  the operator reinstalling, and working rule 10 asks for normal use first
  regardless.
- `writeShellApplication` runs `shellcheck`. Treat what it finds as work rather
  than suppressing it.

## Acceptance

- `vpn` is on `PATH` after activation and works from a fresh login shell.
- `nix flake check`, the activation build, and `tests/*.sh` pass.
- No canonical document describes the VPN command as planned or pending.
- The naming question about the aliases is resolved, not left open.
