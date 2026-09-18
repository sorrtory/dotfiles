# Spec: Fedora documentation cutover

Status: ready-for-agent

## Why

The operator has completed the move to Fedora and is already running the Home
Manager environment there. The repository still contains migration-era wording
that treats Home Manager activation on the main host as a future or unusually
restricted step, and some documents describe Ubuntu as the current user
environment rather than as a supported host or a record of past staging work.

That mismatch makes otherwise useful safety and ownership rules look obsolete.
The documentation needs to distinguish the current Fedora baseline, durable
cross-distribution architecture, historical verification evidence, and work
that still has not been verified on a fresh staging VM.

## Decisions

- **Fedora is the current host baseline.** Home Manager is installed and in
  normal use there; the docs must not describe that cutover as pending.
- **The repository remains cross-distribution.** Fedora becoming the current
  host does not turn Fedora-specific system integration into Home Manager work
  or remove supported Debian/Ubuntu and Arch branches from bootstrap phases.
- **Ownership boundaries survive the cutover.** Fedora owns privileged and
  distro-coupled integration. Home Manager owns the user environment. Normal
  Home Manager activation still does not invoke `sudo`.
- **Historical evidence stays historical.** Results measured on an Ubuntu VM
  remain valid records when labelled as such. They must not be rewritten to
  imply that equivalent Fedora or GNOME staging verification has happened.
- **No staging VM exists yet.** Documentation may describe how a future VM
  should be provisioned, but must not claim fresh-machine Fedora verification
  until it has actually been performed.

## Scope

In scope:

- audit current documentation for stale host, migration, activation, and
  verification claims;
- describe Fedora as the current host with Home Manager already active;
- retain the cross-distro ownership and security model;
- distinguish completed host migration from unfinished feature migration;
- make README, canonical docs, software catalog, and staging guidance agree;

Out of scope:

- changing Home Manager modules or activating a generation;
- installing or creating a staging VM;
- implementing or renumbering bootstrap phases;
- deleting Ubuntu-specific implementation notes or verification records merely
  because Fedora is now the main host.

## Risks

- **Erasing evidence.** A broad Ubuntu-to-Fedora replacement would falsify
  staging records and destroy useful platform-specific guidance.
- **Weakening a real boundary.** Removing stale activation cautions must not
  imply that Home Manager may take over privileged host integration or run
  `sudo` during activation.
- **Overstating completion.** The host cutover is complete, but the repository's
  feature migration and fresh-machine validation may still be incomplete.

## Tickets

See [map.md](map.md).
