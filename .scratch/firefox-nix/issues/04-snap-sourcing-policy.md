# 04 — Record the Snap sourcing policy

Status: needs-triage
Blocked by: 01

## Goal

Write down the rule this effort establishes, so the next person adding
software knows Snap is not an option and knows why `snapd` is still installed.

## Work

1. `docs/DECISIONS.md`, "Package policy" — record both halves:
   - `snapd` remains host-owned infrastructure. Other host function depends on
     it, and this repository has no replacement for that function.
   - No software this repository declares may be installed through Snap,
     because Snap packages are not pinned by `flake.lock`, update themselves
     out of band, and cannot be described declaratively.

   Place it alongside the existing Docker and `yt-dlp` carve-outs, which are
   the other two "the host owns this, and here is exactly why" entries.
2. `docs/SOFTWARE.md` — update the `Firefox` row to its real mechanism and
   link the module. Update the `Snap` row from *"Host-owned; excluded from
   normal Home Manager activation"* to also state the sourcing rule.
3. `docs/SOFTWARE.md` — note that Snap is not among the options for the
   applications still deferred to desktop application review: Chrome, DBeaver,
   Sublime Merge, LibreOffice, Audacity, and Gradia.

## Constraints

- State it as a sourcing constraint, not an anti-Snap position. The reason is
  reproducibility, and saying so is what makes the exception for host-owned
  `cups` and `firmware-updater` coherent rather than inconsistent.
- Do not promote the six deferred applications. Recording that Snap is off the
  table for them is not deciding them; this effort is not the desktop
  application review.
- The legacy `install.conf` declared exactly three snaps — `lxd`, `obsidian`,
  `yazi`. Obsidian is already a Home Manager package, Yazi becomes one in the
  `native-configs` effort, and the LXD proxy is retired. With
  Firefox, the set is closed; the policy is a statement of a reached state,
  not an aspiration.

## Acceptance

- `docs/DECISIONS.md` answers both "may I install this with Snap?" and "then
  why is `snapd` still here?" without a reader needing this ticket.
- Every `SOFTWARE.md` row touched links to a file that exists.
- `tests/*.sh` still pass.
