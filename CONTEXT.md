# Dotfiles Migration

This repository defines a cross-distribution Linux user environment while leaving low-level system integration to the host distribution.

## Language

**Host environment**:
The operating-system layer owned by the installed Linux distribution, including hardware integration and system services.
_Avoid_: NixOS configuration, whole system

**User environment**:
The packages, tools, preferences, scripts, and reproducible secrets owned by Nix and Home Manager for one user.
_Avoid_: Host environment, whole system

**Global user tool**:
A tool made available in every user session through Home Manager without becoming host-owned software.
_Avoid_: System package, root-level tool

**Project tool**:
A tool available inside a project development environment, normally to select a project-specific version or dependency set.
_Avoid_: Global user tool, system package

**Bootstrap phase**:
An ordered, idempotent step that checks and establishes one part of the fresh-machine flow.
_Avoid_: Home Manager module, unordered installer

**Legacy source**:
Existing configuration, script, or secret material being evaluated for migration. It is evidence of current behavior, not a requirement to retain it.
_Avoid_: Canonical configuration, migration requirement

**Migration candidate**:
A legacy item under explicit consideration for retention, improvement, replacement, or removal.
_Avoid_: Required migration

**Migration slice**:
One coherent, independently verifiable transfer of responsibility into the user environment.
_Avoid_: Rewrite

**Behavior baseline**:
The intentionally selected behavior a migration slice must preserve while its representation may improve.
_Avoid_: Exact legacy copy

**Native config**:
Application configuration kept in the application's own readable format and optionally exposed through Home Manager.
_Avoid_: Unmanaged config

**Declarative config**:
Application or environment configuration expressed through a Home Manager option model when that model improves ownership or maintenance.
_Avoid_: Nixified config

**Reproducible secret**:
Sensitive machine configuration that must be provisioned again from encrypted repository material.
_Avoid_: Password, session state

**Secret recovery phase**:
The required interactive bootstrap phase that restores access to reproducible secrets before a secret-bearing user environment can be activated.
_Avoid_: Optional warning, Home Manager activation

**Recovery repository**:
A private transport for the encrypted recovery vault that is independently accessible during fresh-machine recovery.
_Avoid_: Legacy secrets repository, declarative secrets directory

**Recovery vault**:
The operator's main KeePassXC database, independently obtainable during fresh-machine recovery and containing the backup private age identity.
_Avoid_: Declarative secret store, repository-managed config

**Mutable session**:
Machine-local authentication or application state created interactively and intentionally excluded from declarative provisioning.
_Avoid_: Reproducible secret

**Private vault**:
The operator's encrypted collection of private notes and other personal files, made accessible together when unlocked. It is a gocryptfs filesystem named by the directory it mounts on, holding data this repository never creates or carries.
_Avoid_: Recovery vault, declarative secret store

**Knowledge database**:
The operator's public-safe Obsidian collection, independent of the private vault.
_Avoid_: Private vault, recovery vault

**Public-safe secret material**:
SOPS ciphertext or non-sensitive metadata that is safe to publish in repository history.
_Avoid_: Plaintext secret, private identity, potentially sensitive file

**Staging VM**:
A disposable execution target used to build and activate changes without making it the source of repository truth.
_Avoid_: Development source, production host

**Staging credential**:
An intentionally public login used only by the disposable staging VM and never reused by a trusted machine or service.
_Avoid_: Secret, production credential

**Core milestone**:
The first prioritized migration set defined in `docs/MIGRATION.md`.
_Avoid_: Complete migration

**Additional candidate**:
A component outside the core milestone that is deferred until its value and priority are explicitly reassessed.
_Avoid_: Required follow-up

**Operator review**:
The user's approval of the resulting configuration and intentional behavior changes before a migration slice is committed.
_Avoid_: Automated review

**VPN command**:
The opt-in command that launches an application with its network traffic confined to a tunnel while other applications retain their ordinary connection.
_Avoid_: Whole-host VPN, proxy setting, root command launcher

**VPNized application**:
An application the user environment installs so that every ordinary way of starting it goes through the VPN command.
_Avoid_: Proxied app, sandboxed app

**VPN identity**:
The one tunnel peer a machine is allowed to use, never used by another machine or client at the same time.
_Avoid_: Profile, shared key

**Local proxy**:
The user environment's tunnel entry point for applications that explicitly send connections through their proxy settings.
_Avoid_: VPN command, whole-application tunneling

**Package baseline**:
The package requirements declared by the legacy installation sources, translated into user-owned and host-owned responsibilities during migration.
_Avoid_: Installed package snapshot, unconditional package copy
