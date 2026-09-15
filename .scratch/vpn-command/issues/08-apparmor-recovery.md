# 08 — Make AppArmor install and removal failure-recoverable

Status: ready-for-agent
Priority: P2

## Evidence

Review at 1e75b0f, scripts/bootstrap/09-apparmor.sh:

- install copies the profile before kernel loading. A failed --replace leaves
  matching files, so the next check incorrectly reports installation complete.
- remove_profile suppresses all unload failures, then removes the file;
  uninstall can report success while an allowance remains loaded.

These are conditional control-flow defects, not reproduced kernel failures.

## Work and acceptance

- Establish successful kernel loading as well as matching installed files;
  retry must repair a partial install, including after a failed update.
- Distinguish already-unloaded policy from a real unload failure. Do not lose
  the recovery input or report successful removal while policy remains loaded.
- Add isolated fault-injection tests for load failure, retry, unload failure
  and already-absent policy; preserve existing idempotency and unrelated policy.
- Keep exact executable allowances, explicit privileged bootstrap, and no sudo
  during Home Manager activation. Verify the normal lifecycle on staging.
