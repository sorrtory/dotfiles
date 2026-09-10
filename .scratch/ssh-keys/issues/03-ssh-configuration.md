# 03 — Migrate ~/.ssh configuration as repository material

Status: ready-for-agent
Blocked by: 01

## Goal

Make the reproducible half of SSH reproducible, while keeping out of a public
repository the parts that should not be in one.

This repository is published (`docs/DECISIONS.md` calls it "the public dotfiles
flake"). `~/.ssh/config` and `known_hosts` are not credentials, but they are a
precise map of what the operator connects to and how: internal hostnames, login
names, ports, and jump hosts. An unhashed `known_hosts` is a list of every host
ever reached. None of that belongs in public history, where it is permanent even
if later deleted.

So the config splits three ways rather than two:

- **public** — options, defaults, key-type and cipher preferences, anything that
  would be identical for any operator. Plain repository material.
- **host-identifying** — `Host`/`HostName`/`User`/`Port`/`ProxyJump` for real
  infrastructure. SOPS ciphertext under `secrets/`, or left machine-local.
- **rebuildable** — `known_hosts`. Prefer rebuilding on first connect over
  publishing or encrypting a trust store; a stale entry is a liability, not a
  convenience.

## Work

1. Sort the live `Host` blocks identified by ticket 01 into the three
   categories above. Drop blocks for hosts that no longer exist rather than
   carrying them forward.
2. Assemble the final `~/.ssh/config` from the public part plus the decrypted
   host-identifying part, so the two can live in different places and still
   produce one file. `Include` is the mechanism OpenSSH offers for this; confirm
   it accepts an included file from the decrypted location.
3. Point each `IdentityFile` at whatever ticket 02 established as the working
   form. Until 02 answers, leave the path as the one variable to fill in.
4. Decide `known_hosts` deliberately, defaulting to rebuilding on first connect.
   Say why in the commit either way.
5. Choose between `programs.ssh` options and a native config file. `~/.ssh/config`
   is readable and widely understood, so per `docs/DECISIONS.md` do not
   translate it to Nix merely for aesthetics.

## Constraints

- Public keys are public. Do not encrypt them.
- No real hostname, login name, or internal port reaches plain repository
  material. Use the staged gate and review the diff by eye before committing;
  this is the class of leak a mechanical scan will not catch, because a hostname
  matches no secret pattern.
- Home Manager must not make `~/.ssh` or its contents group- or world-readable;
  OpenSSH will refuse to use the directory if it is.

## Acceptance

- A fresh activation produces a working `~/.ssh/config` with no manual editing.
- Nothing host-identifying appears in plain repository material, confirmed by
  reading the diff rather than only by running the gate.
- No secret material added to the repository by this ticket.
