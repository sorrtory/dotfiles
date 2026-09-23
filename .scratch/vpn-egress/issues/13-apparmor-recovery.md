# 13: Recover cleanly from AppArmor allowance failures

Status: resolved
Blocked by: None (can start immediately)
Priority: P2

**What to build:** Make the explicit AppArmor allowance bootstrap recover
from a failed profile load or unload without reporting a false installed or
removed state. This independent defect was observed in the current bootstrap
flow and does not gate the egress rewrite.

- [ ] A failed load leaves a retryable state; the next install confirms
      kernel state as well as installed files.
- [ ] A real unload failure preserves recovery input and is reported as a
      failure; an already-absent policy remains a successful no-op.
- [ ] Isolated fault-injection checks cover load failure, retry, unload
      failure and absent policy while preserving unrelated profiles.
- [ ] The normal lifecycle is checked on staging; Home Manager activation
      remains unprivileged and allowances remain exact-path.

## Answer

The bootstrap phase now checks kernel policy as well as installed files. A failed load is retryable, and a failed unload leaves its profile file in place. Fault-injection checks passed locally and on staging; Fedora's unrestricted normal path skipped correctly.
