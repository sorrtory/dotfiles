# 03 — Align operator and staging documentation

Status: resolved
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

## Answer

- `README.md`: the opening now leads with the Fedora main machine and the
  environment in daily use before the migration caveat. The virtualization
  record is dated and attributed to "an Ubuntu 24.04 staging VM", with an
  explicit note that it is not evidence about another distribution. The
  paragraph about the legacy LXD proxy on "the current migration host" and the
  `desktop-ubuntu` identity is deleted — LXD is retired (MIGRATION §13) and that
  VM no longer exists. The project-guidance list no longer calls `AGENTS.md`
  "the staging target".
- `docs/SOFTWARE.md`: "the selected Ubuntu user environment" became "the
  selected user environment", with a sentence saying distro-qualified rows (the
  AppArmor allowances, `fdfind`, Ubuntu Dock) apply only there. The table is
  unchanged.
- `docs/STAGING.md`: rewritten for the VM that exists. It documents
  `silverblue43` / `z@192.168.122.79` (Fedora 43 Silverblue, 2 vCPU, ~2.8 GiB
  RAM, 13 GiB free), its snapshot, and the verified fact that the bootstrap
  cannot run on an rpm-ostree image. The mirroring command and the TTY-less
  sudo helper moved here from the old `AGENTS.md#staging` section. The Ubuntu
  reset, disk-growth and clock-stepping steps are gone with the VM they
  described. The 2026-09-16 virtualization results are kept verbatim under
  "Historical Ubuntu verification", introduced as records that are not evidence
  about Fedora.
- `AGENTS.md`: the opening states the Fedora host and Home Manager as normal,
  keeping the cross-distro scope and the unfinished feature migration. A
  four-line `## Staging` section names the VM, its blocker, and points at
  `docs/STAGING.md`. The project map now matches the tree (`home.nix` rather
  than a `home/` directory, plus `flake.nix`, `docs/`, `modules/theme/` and
  `modules/apparmor.nix`), and the "destinations, not files" paragraph shrank to
  one sentence.

Superseded the same day: the operator replaced the Silverblue VM with `fedora`
at `z@192.168.122.21`, Fedora 44 Workstation on GNOME/Wayland, where `host-deps`
and `nix` both run. `docs/STAGING.md` and `AGENTS.md` were updated to that VM and
keep the Silverblue rpm-ostree gap as a recorded predecessor.

Three dead links are gone: `docs/STAGING.md` and `README.md` both pointed at
`AGENTS.md#staging`, a section deleted in `166c784`.

## Comments
