# 01 — Inventory and classify the SSH material

Status: resolved

## Answer

The operator selected `id_ed25519_github` and `id_ed25519_servers` as
reproducible operator identities. Their public halves are ordinary repository
material. Generic SSH options are public native configuration; real host names,
users and ports are a whole-file SOPS secret included at runtime. `known_hosts`
is rebuilt on connection rather than migrated. Commit `376ef7b` implements the
classification without reading private key contents.

## Goal

Decide which keys are migrated, which become removal candidates, and which
`~/.ssh` files are ordinary repository material. Nothing else in this slice can
be specified until that list exists.

## Why this needs the operator

The classification rule is "does this key identify the operator, or does it
identify a machine?" — and that cannot be read off the filesystem. A file called
`id_ed25519` might be a personal key used everywhere or a key generated once on
one laptop for one server. Only the operator knows what each key is for and
where its public half is registered.

## Work

1. The operator supplies, per key: the filename, what it authenticates to, and
   whether its public half is registered somewhere they control.
2. Classify each as:
   - **migrate** — identifies the operator; losing it costs real work to
     replace. Git signing keys belong here almost by definition.
   - **drop** — identifies one machine, or authenticates to something retired.
     Generate a fresh key on the next machine instead.
   - **undecided** — needs the operator to check where it is registered.
3. Record the classification and the rule that produced it, so a key added later
   can be classified without re-litigating.
4. Inventory the non-secret side too: which `Host` blocks in `~/.ssh/config` are
   still live, and whether `known_hosts` is worth carrying or better rebuilt.

## Constraints

- Filenames, modes, and sizes only. Do not read private key contents; see the
  spec's reading constraint.
- A key nobody can account for is a **drop**, not a **migrate**. Carrying an
  unexplained key forward makes it permanent.

## Acceptance

- Every file under the SSH portion of the legacy secrets tree is classified.
- Each `migrate` entry names what it authenticates to.
- The classification rule is written down, not just applied.
