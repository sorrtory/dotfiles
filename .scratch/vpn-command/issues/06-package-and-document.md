# 06 — Document, review and gate legacy retirement

Status: ready-for-agent
Blocked by: 05

## Goal

Hand off one module-owned application VPN implementation with clear ownership
and evidence. Packaging begins in tickets 01/03, not after desktop verification.

## Work

1. Update README, docs/SOFTWARE.md, docs/MIGRATION.md §7 and the relevant
   docs/DECISIONS.md wording to describe vpnizedApps, installed Vesktop, managed
   launch paths and module-private helpers. Reconcile the earlier mandatory
   scripts/bin VPN source location and generic vpn command scope explicitly.
   Review terminology in CONTEXT.md through the domain documentation workflow.
2. Explain the two sing-box processes/one tunnel identity, on-demand capture,
   protocol-independent launcher, rootless prerequisites and raw-executable
   bypass. Generic vpn remains optional follow-up using the same implementation.
3. Document explicit machine identity and coexistence constraints with legacy
   proxy/WireGuard and whole-host vpn-up/vpn-down aliases. Do not alter those
   aliases or running host services as incidental cleanup.
4. Run flake evaluation/build, regression checks and the staged secret gate
   before requesting commit review. Obtain explicit host activation approval;
   do not activate unrelated pending work along with this slice.
5. Obtain normal-use operator review before retiring legacy scripts or
   installations. Preserve scripts/bin/vpn.sh and external legacy material until
   that gate; list exact retirement targets and obtain approval before removal.
6. Fold durable findings into canonical documentation and remove completed
   scratch coordination material only in the completion commit.

## Acceptance

- Documentation matches shipped behavior and does not claim unverified support.
- One chosen app-VPN implementation serves everyday Vesktop.
- Builds/tests pass; operator review, activation and retirement are distinct gates.
- Legacy data and session state are not deleted automatically.
