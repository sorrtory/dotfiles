# Issue tracker: Local Markdown

Issues and specs for this repository live as version-controlled Markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`.
- The spec is `.scratch/<feature-slug>/spec.md`.
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`.
- Never combine all tickets into one file.
- Triage state is recorded as a `Status:` line near the top of each issue.
- Blocking relationships are recorded as a `Blocked by:` line.
- Comments and conversation history are appended under a `## Comments` heading.

## Publishing

When a skill says "publish to the issue tracker," create a file under `.scratch/<feature-slug>/`, creating the directory when needed.

## Fetching tickets

When a skill says "fetch the relevant ticket," read the referenced file. The user will normally provide its path or issue number.

## Completion

Keep only active coordination material in `.scratch/`. When a feature is complete, preserve durable terminology and decisions in canonical project documentation, then remove its scratch directory in the completion commit. Git history remains the record of its spec and tickets.

## Wayfinding operations

- **Map:** `.scratch/<effort>/map.md`.
- **Child ticket:** `.scratch/<effort>/issues/<NN>-<slug>.md`.
- **Type:** `research`, `prototype`, `grilling`, or `task`.
- **Status:** `claimed` or `resolved`.
- **Blocking:** `Blocked by: NN, NN`. A ticket is unblocked when every listed ticket is resolved.
- **Frontier:** the first numbered open, unblocked, and unclaimed ticket.
- **Claim:** set `Status: claimed` before beginning work.
- **Resolve:** append the result under `## Answer`, set `Status: resolved`, and add a context pointer to the map.
