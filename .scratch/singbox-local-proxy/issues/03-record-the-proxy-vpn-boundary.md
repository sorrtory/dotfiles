# 03 — Record the shared backend and the two entry points

Status: resolved

## Goal

Record the operator-confirmed design: one sing-box backend and one exclusive
WireGuard peer per machine, with local proxy settings and a namespace launcher
as separate entry points.

## Answer

`CONTEXT.md` distinguishes the local proxy from the VPN command.
`docs/DECISIONS.md` records the shared backend, per-machine peer identities,
restart interruption, no direct fallback, and the host-DNS bootstrap exception.
`docs/MIGRATION.md` orders the work as proxy service, namespace prototype,
then launcher. The local proxy can use 1.13.19; built-in namespace support
requires 1.14+ and host-policy validation.

The former claim that sing-box necessarily needs host-wide capture to support
UDP is superseded. Namespace-scoped capture is the selected direction, with
compatibility to be proven by the prototype. Two independent WireGuard clients
must not reuse a peer identity, even on the same machine.

The original shared-extra design and separate kernel-WireGuard launcher are
retained only as history; existing legacy execution is not removed here.
