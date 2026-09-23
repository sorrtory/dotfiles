# 14: Accept relative executable paths in vpn

Status: ready-for-agent
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
