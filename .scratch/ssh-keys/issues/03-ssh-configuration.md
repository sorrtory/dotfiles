# 03 — Migrate ~/.ssh configuration as repository material

Status: ready-for-agent
Blocked by: 01

## Goal

Make the non-secret half of SSH reproducible. `~/.ssh/config`, `known_hosts`,
and public keys contain nothing sensitive, and they are the part that is
genuinely tedious to rebuild by hand on a new machine.

Keeping them out of `secrets/` is deliberate: the gate there demands ciphertext,
and encrypting a host alias list would be security theatre that also makes it
unreadable in review.

## Work

1. Migrate the live `Host` blocks identified by ticket 01. Drop blocks for hosts
   that no longer exist rather than carrying them forward.
2. Point each `IdentityFile` at whatever ticket 02 established as the working
   form. Until 02 answers, leave the path as the one variable to fill in.
3. Decide `known_hosts` deliberately. It is a trust store, so a stale entry is a
   liability rather than a convenience; rebuilding it on first connect may be
   the better answer. Whichever way, say why in the commit.
4. Choose between `programs.ssh` options and a native config file. `~/.ssh/config`
   is readable and widely understood, so per `docs/DECISIONS.md` do not
   translate it to Nix merely for aesthetics.

## Constraints

- Public keys are public. Do not encrypt them.
- Home Manager must not make `~/.ssh` or its contents group- or world-readable;
  OpenSSH will refuse to use the directory if it is.

## Acceptance

- A fresh activation produces a working `~/.ssh/config` with no manual editing.
- No secret material added to the repository by this ticket.
