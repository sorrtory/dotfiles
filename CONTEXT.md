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

**Mutable session**:
Machine-local authentication or application state created interactively and intentionally excluded from declarative provisioning.
_Avoid_: Reproducible secret

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
The user-facing command that creates an isolated WireGuard network environment, launches a payload there as the invoking user, and cleans up privileged network state.
_Avoid_: Root command launcher, WireGuard config

**Package baseline**:
The package requirements declared by the legacy installation sources, translated into user-owned and host-owned responsibilities during migration.
_Avoid_: Installed package snapshot, unconditional package copy
