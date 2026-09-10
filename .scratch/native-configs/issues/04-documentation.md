# 04 — Documentation corrections

Status: ready-for-agent
Blocked by: 01, 02, 03

## Goal

Correct the canonical documents. Several rows describe intentions that this
slice either fulfilled differently or proved wrong.

## Work

1. `docs/SOFTWARE.md` — update the `Neovim`, `tmux`, `Yazi`, `Node.js and
   pnpm`, and `fnm` rows to their real mechanism and link the modules that now
   exist.
2. `docs/SOFTWARE.md` — **the `lazygit` row is factually wrong.** It reads
   *"Terminal Git client integrated by retained Neovim configuration; deferred
   to the Neovim migration."* There is no lazygit anywhere in
   `configs/nvim/`. Nothing was waiting on this migration. Correct or remove
   the row rather than carrying the claim forward.
3. `docs/SOFTWARE.md` — the `Vim` row says *"expected to be replaced by
   Neovim."* That remains true and stands as written; `.vimrc` shipping as
   repository material does not contradict it. Add a clarifying clause only if
   a reader would otherwise think Vim is now a declared package.
4. `docs/DECISIONS.md`, "Configuration policy" — record the plugin-ownership
   split and its reasoning, since it is the non-obvious decision of this
   slice: Nix owns tmux and Yazi plugins, `lazy.nvim` and mason keep Neovim's.
5. `docs/MIGRATION.md` §10 to §12 — confirm the text matches what shipped.

## Constraints

- Do not state the plugin split as a general rule. It is two specific
  judgments about two specific plugin sets, and writing it as a rule would
  mislead the next migration.
- Do not record anything about the legacy repository's retirement. That is the
  operator's, handled by reinstalling the host, and outside this repository.

## Acceptance

- Every `SOFTWARE.md` row touched by this slice links to a file that exists.
- No canonical document claims lazygit is part of the Neovim configuration.
- `tests/*.sh` still pass.
