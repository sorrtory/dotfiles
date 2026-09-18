# 03 — Align operator and staging documentation

Status: ready-for-agent
Blocked by: 01, 02

## Goal

Make day-to-day and staging instructions agree with the canonical Fedora
baseline and with the fact that no staging VM currently exists.

## Work

1. Update `README.md` to lead with the current Fedora/Home Manager state while
   retaining fresh-machine and cross-distro instructions where supported.
2. Update `docs/SOFTWARE.md` so it no longer calls Ubuntu the selected current
   user environment; keep installation mechanisms and platform qualifications
   accurate.
3. Review `docs/STAGING.md` and `AGENTS.md` for wording that confuses a known
   Ubuntu test recipe or old VM with a VM currently available to the operator.
4. Keep recorded Ubuntu verification results, but clearly separate them from
   future Fedora or GNOME staging work.
5. Make activation guidance fit normal Fedora use without authorizing an
   unattended or privileged host activation policy.

## Constraints

- Do not invent VM names, addresses, snapshots, Fedora versions, or test
  results.
- Do not provision, reset, or connect to a VM in this ticket.
- Preserve distro-specific troubleshooting that is still correct.

## Acceptance

- A reader can tell that the main machine is Fedora, Home Manager is active,
  and no staging VM is presently installed.
- Historical Ubuntu validation remains attributable to the environment where
  it occurred.
- The README, software catalog, staging guide, and agent instructions do not
  contradict the canonical documents.

## Comments
