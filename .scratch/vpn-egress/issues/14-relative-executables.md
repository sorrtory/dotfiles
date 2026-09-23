# 14: Accept relative executable paths in vpn

Status: resolved
Blocked by: None (can start immediately)
Priority: P2

**What to build:** Let `vpn` launch an executable named by a relative path or
found through a relative `PATH` entry, while preserving the executable's
multicall name and the caller's own `PATH`. This independent defect does not
gate the egress rewrite.

- [ ] `./program`, `../program`, relative `PATH` entries, spaces and final
      symlinks work; shell builtins still fail as non-executables.
- [ ] Unsupported package families remain rejected even when named by a
      relative path.
- [ ] Existing argument passing and caller `PATH` behavior remain intact,
      without user-wrapper runtime inputs that silently change command
      resolution.

## Answer

`vpn` anchors relative executable paths before handing them to systemd and checks the resolved target for unsupported package families. The command test covers relative paths, a relative PATH entry, spaces and final symlinks; it passed locally and on staging.
