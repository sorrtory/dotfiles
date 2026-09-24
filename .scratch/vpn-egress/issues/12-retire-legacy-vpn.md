# 12: Retire reviewed legacy VPN material

Status: claimed
Blocked by: 11 (everyday recovery)

**What to build:** After normal use proves the new VPN path, retire only the
legacy launcher, handover practice and reference material that the operator
has explicitly reviewed. Preserve durable decisions in canonical docs before
closing the migration effort.

- [x] Name every retirement target and obtain the operator's approval for
      each removal; legacy data and login/session state are never deleted
      automatically.
- [x] Confirm the replacement under normal use before removing the old path,
      not merely because a service started once.
- [x] Canonical vocabulary, security decisions and fresh-machine instructions
      describe the final egress model before scratch coordination is retired.

## Retirement proposal, 2026-09-24

Ticket 11 now records observed physical Wi-Fi changes and real suspend/resume
on the daily host. The host's installed backend, named app captures and
whole-host TUN worked on normal Wi-Fi. On an alternate network the WireGuard
path remained unreachable while VLESS worked through the same TUN; returning
to the original Wi-Fi restored WireGuard without a service restart. This
establishes normal-use recovery and fail-closed behavior; it does not prove
that every network permits the WireGuard protocol.

The active host has no `/etc/wireguard` directory, running legacy WireGuard
interface or `wg-quick@` unit to remove. The original source repositories are
cloned at `~/Projects/scripts` and `~/Projects/secrets`, outside this dotfiles
repository. Neither source repository is part of Home Manager activation.

The operator must approve each proposed removal below. No item here is an
approval, and no plaintext or encrypted profile data is deleted by preparing
this proposal.

| ID | Proposed removal | Effect |
| --- | --- | --- |
| R1 | Legacy profile decryption and identity selector in `modules/secrets.nix`, `modules/programs/sing-box/default.nix`, `home.nix`, `flake.nix` and the obsolete interface guard in `modules/programs/zsh.nix` | Home Manager stops materializing old `wg-quick` profiles. The native inventory remains the only VPN credential source. Keep the `staging` output name as a compatibility alias; hostname policy still selects its peer. |
| R2 | `wireguard-tools` from `modules/packages.nix` and its `docs/SOFTWARE.md` catalog entry | The user profile no longer installs tools used only by the retired handover. |
| R3 | Unused `modules/programs/sing-box/generate-config.sh` and `tests/sing_box_config_test.sh` | Removes the old `wg-quick` profile converter and its tests. Current inventory compiler and tests remain. |
| R4 | `secrets/wireguard/laptop.conf` | Removes the older encrypted laptop profile, whose peer is now in encrypted native inventory. |
| R5 | `secrets/wireguard/desktop-ubuntu.conf` | Removes the older encrypted staging profile, whose peer is now in encrypted native inventory. |
| R6 | `secrets/wireguard/extra.conf` | Removes the old shared secondary profile, which the new backend does not use. |
| R7 | `secrets/wireguard/desktop-old.conf` | Removes an encrypted identity not present in the new inventory. |
| R8 | `secrets/wireguard/desktop-win.conf` | Removes an encrypted identity not present in the new inventory. |
| R9 | `secrets/wireguard/phone.conf` | Removes an encrypted identity not present in the new inventory. |
| R10 | `~/Projects/scripts/vpn.sh` and its installation/reference entries in that repository's `install.conf` and `README.md` | Retires the old root-run veth/NAT launcher in the historical scripts source. Leave unrelated installer functions intact. |
| R11 | Legacy WireGuard files under `~/Projects/secrets/wireguard/` | Retires source data from the historical secrets repository. Each of its six files needs a separate operator decision; nothing there is required by the installed backend. |
| R12 | `.scratch/vpn-egress/` after all durable facts are moved to canonical docs | Closes the implementation coordination per the issue-tracker convention; Git history retains the tickets and spec. Cross-links from other scratch efforts must be updated in the same change. |

Recommended first approval set: R1–R3. They remove only unused implementation
and leave encrypted profile history intact. R4–R9 and R11 are data-retention
choices; retaining any of them does not keep the old path installed. R10 is an
independent change in another repository. R12 follows only after final docs
and approved retirement are complete.

## Approved scope

The operator first approved **R1, R2 and R3** on 2026-09-24. The approved
changes remove old profile
decryption, the legacy identity option and interface guard, `wireguard-tools`,
and the unused profile converter with its tests. The `staging` Home Manager
output remains as a compatibility alias; encrypted hostname policy determines
which WireGuard peer its backend loads. The operator separately approved host
activation under `AGENTS.md` on 2026-09-24.

The operator later approved removal of the entire `secrets/wireguard/`
directory in this repository, covering **R4–R9**. The operator explicitly
excluded the outer `~/Projects/scripts` and `~/Projects/secrets` repositories
from this work. R10 and R11 were not performed. R12 was not part of the
directory-removal request.

## Implementation and validation

R1–R3 are removed in the working tree. `CONTEXT.md`, `README.md`,
`docs/DECISIONS.md`, `docs/MIGRATION.md`, `docs/SOFTWARE.md` and
`docs/STAGING.md` now describe the installed concurrent egress model and its
daily-host recovery evidence. `nix flake check` passed; activation packages
for both `z` and the retained `staging` output built on the host. The evaluated
`z` secret names contain `vpn-egresses` and `vpn-policy` and no legacy
`wireguard/*` declaration. `git diff --check` passed.

The separately approved `home-manager switch --flake .#z` completed on the
daily host. After activation, sing-box was active; `vpn-egress status` showed
the declarative laptop WireGuard default; `vpn-egress check` reported HTTPS
reachable on both the laptop WireGuard and `orange-vless` routes. Host HTTPS,
default `vpn` capture and named VLESS capture each returned 204. The user
profile had no `wg-quick`, and the legacy runtime secret directory was absent.
No commit or change to either historical source repository was made. After
the later approval, all six tracked files under `secrets/wireguard/` were
removed and the empty directory disappeared. The native encrypted inventory
and policy were kept. R10–R12 remain untouched; the outer repositories are
explicitly out of scope.

After R4–R9 removal, `nix flake check` and
`nix build --no-link .#homeConfigurations.z.activationPackage` passed again on
the host. This source-only removal did not require another Home Manager
activation; the approved R1–R3 generation was already active and had no
legacy `wireguard/*` secret declarations.
