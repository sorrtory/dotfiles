# 01 — Audit stale platform and migration claims

Status: resolved

## Goal

Produce an evidence-backed inventory of wording that became inaccurate when
the operator moved to Fedora and began using the Home Manager environment on
the main host.

## Work

1. Search all maintained Markdown for claims about the current host, Ubuntu as
   the selected user environment, pending Home Manager use, host activation,
   incomplete cutover, and staging verification.
2. Classify each match as one of:
   - stale current-state wording to change;
   - durable architecture or safety policy to keep;
   - platform-specific operational guidance to keep;
   - historical verification evidence to keep and label;
   - genuinely unfinished migration work to keep open.
3. Append the inventory under `## Answer`; include file and section names, not
   a prose impression of the repository.
4. Identify any contradictions between `CONTEXT.md`, `docs/DECISIONS.md`,
   `docs/MIGRATION.md`, `README.md`, `docs/SOFTWARE.md`, `docs/STAGING.md`, and
   `AGENTS.md`.

## Constraints

- Do not edit canonical or operator documentation in this ticket.
- Do not treat every mention of Ubuntu as stale.
- Do not assume that successful use on the current host proves a fresh-machine
  bootstrap path.

## Acceptance

- Every proposed documentation change is traceable to an inventoried claim.
- Ubuntu history and Ubuntu-only behavior are separated from stale statements
  that call Ubuntu the current host.
- Real ownership and activation safety rules are identified rather than swept
  up with obsolete migration cautions.

## Answer

Audited 2026-09-20 over `AGENTS.md`, `CONTEXT.md`, `README.md` and `docs/`.

### Stale current-state wording to change

| Location | Claim |
| --- | --- |
| `AGENTS.md:3` | "This repository is being migrated" as the whole framing; no statement of the current host |
| `AGENTS.md` project map | lists `home/`, which does not exist; the real file is `home.nix` |
| `AGENTS.md` | no `## Staging` section, yet `docs/STAGING.md:5` and `README.md:492` link to `AGENTS.md#staging` and call it "the staging target" — both links are dead |
| `CONTEXT.md:1` | titled "Dotfiles Migration"; no vocabulary separating current host, supported host, and staging evidence |
| `docs/DECISIONS.md` "Platform and ownership" | records the cross-distro model but never names a current host |
| `docs/DECISIONS.md:551` | "The staging VM is disposable and may be activated after a successful build" — presumes a VM that exists and runs this flow |
| `docs/MIGRATION.md:19-24` | method steps 3/4 require "build without activating on the host" and "activate on the staging VM" before host activation; this postpones normal use of an environment now in daily use |
| `docs/MIGRATION.md` | no statement that the host cutover itself is done |
| `docs/SOFTWARE.md:3` | "the selected Ubuntu user environment" — names Ubuntu as the current environment |
| `README.md:8-10` | leads with "Migration ... is in progress" and never says what the main machine runs |
| `README.md:152-154` | "On the current migration host, the running legacy LXD proxy also uses the laptop peer" and "The staging VM is tested with its separate desktop-ubuntu identity" — LXD is retired (MIGRATION §13) and that VM no longer exists |
| `docs/STAGING.md` (whole file) | written against `Lubuntu24.04` at `192.168.122.214`, a VM the operator no longer has |

### Durable architecture and safety policy to keep

- `docs/DECISIONS.md` "Platform and ownership": host/user ownership split, keyboard split, and "normal Home Manager activation must not invoke `sudo`".
- `AGENTS.md` working rules 6-9 (secrets, no `sudo` in activation, host owns system integration, session state stays local).
- `docs/DECISIONS.md` "Migration and review": operator review before commit, mechanical secret scan, retire legacy only after the replacement survives normal use.
- Cross-distro scope: `README.md:54`, `docs/DECISIONS.md:121`, `docs/SOFTWARE.md:14` (Debian/Ubuntu, Fedora, Arch; NixOS excluded).

### Platform-specific operational guidance to keep

- Every AppArmor/`userns` mention: `README.md:42,142,149`, `docs/SOFTWARE.md:22,90,121`, `docs/VESKTOP-APPARMOR.md`, `docs/DECISIONS.md:500`, `docs/MIGRATION.md:331`. These are true of Ubuntu specifically; Fedora does not set the restriction, which the VM's `apparmor` status line confirms.
- `fd` replacing Ubuntu's `fdfind` (`docs/SOFTWARE.md:45`); Ubuntu Dock as a distro session-mode extension (`docs/DECISIONS.md:133`, `docs/SOFTWARE.md:59`).
- Fedora-specific: the RPM-owned Nix daemon profile (`scripts/bootstrap/02-nix.sh`), `fedora-amd-gpu`, and `nix-gpu`.

### Historical verification evidence to keep and label

- `docs/STAGING.md:124-136` — virtualization verified 2026-09-16 on Ubuntu 24.04.3.
- `README.md:102-108` — the same result, restated.
- `docs/MIGRATION.md:113-118` (VPN), `:210` (Neovim), `:229` (tmux), `:247` (Yazi), `:265` (sing-box) — all "shipped on staging", all measured on VMs that no longer exist.
- `docs/VESKTOP-APPARMOR.md:114` — measured on Ubuntu 26.04.1.

None of these may be relabelled as Fedora results.

### Genuinely unfinished work to keep open

- `docs/MIGRATION.md:337-340` — non-Ubuntu virtualization branches have command-flow tests only.
- `docs/MIGRATION.md:117` — network change and suspend-to-RAM unverified for the VPN command.
- `docs/MIGRATION.md` "Additional candidates" — `firefox-nix`, `vault-split`, helper scripts, desktop application review.
- No fresh-machine bootstrap has been run on Fedora.

### Contradictions between documents

1. `README.md` and `AGENTS.md` disagree: the README calls migration in progress and points at a staging target in `AGENTS.md`; `AGENTS.md:27` already says Fedora is the current host and has no staging section.
2. `docs/SOFTWARE.md:3` (Ubuntu is current) contradicts `AGENTS.md:27` (Fedora is current).
3. `docs/MIGRATION.md:22` and `docs/DECISIONS.md:551` require staging activation before host activation; `AGENTS.md:35` only requires operator approval on the host. The VM those steps assume does not exist.
4. `docs/STAGING.md` and `CONTEXT.md`'s "Staging VM" entry imply a standing VM; there was none until the Fedora Silverblue VM below.

### New fact established during the audit

The operator has provisioned a staging VM at `z@192.168.122.79`: **Fedora 43.1.6 Silverblue**, 2 vCPU, 2.8 GiB RAM, 13 GiB free on `/var/home`. It is not a substitute for the old Ubuntu VMs, and it cannot currently run the bootstrap:

```
$ ssh z@192.168.122.79 'cd ~/Documents/dotfiles && ./scripts/bootstrap.sh install host-deps'
[host-deps] required commands are missing: dnf
```

`scripts/bootstrap/common/packages.sh` maps `ID=fedora` to `dnf`, which an rpm-ostree image does not ship, and `02-nix.sh` installs Nix from Fedora's RPM onto a read-only `/`. Supporting rpm-ostree is implementation work and is out of this milestone's scope; documentation must describe the VM as present but not yet able to bootstrap.

## Comments
