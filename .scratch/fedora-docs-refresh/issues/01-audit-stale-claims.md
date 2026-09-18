# 01 — Audit stale platform and migration claims

Status: ready-for-agent

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

## Comments
