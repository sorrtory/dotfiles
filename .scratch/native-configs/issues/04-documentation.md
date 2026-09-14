# 04 — Documentation corrections

Status: claimed
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

## Comments

Done, in the same working tree as 01 to 03.

- `docs/SOFTWARE.md`: the `Neovim`, `tmux`, and `Yazi` rows now describe the
  mechanism that shipped and link the modules. `Node.js and pnpm` is split,
  because only Node was selected: a `Node.js` row pointing at
  `modules/packages.nix` with the reason, and a `pnpm` row still deferred. The
  `fnm` row moves from "deferred" to "not selected", with the reason the shim
  existed. Two rows were added for what Nix now owns, following the precedent
  of the `MPV script:` rows: the three tmux plugins, and the Yazi plugin
  package.
- The `lazygit` row claimed it was "integrated by retained Neovim
  configuration; deferred to the Neovim migration". Nothing in `configs/nvim/`
  mentions lazygit, so the row now reads "Not selected; nothing in the Neovim
  configuration ever referenced it, so no migration was waiting on it".
- The `Vim` row keeps its judgment and gains the clarifying clause: the
  package stays undeclared, while `configs/vim/.vimrc` ships as repository
  material, and its Definition cell points at where that delivery is defined.
- `docs/DECISIONS.md`, Configuration policy: the plugin-ownership split is
  recorded as two specific judgments rather than a rule, along with the
  upstream-name plugin layout that repairs `prefix + Ctrl+d`, the
  `PATH`-obligation that makes Node global, and the two Home Manager modules
  that generate the file a native config must occupy. The ownership sentence
  now says Home Manager owns Zsh, Neovim, tmux, MPV, and Yazi.
- `docs/MIGRATION.md` §10 to §12 now match what shipped, including the
  `sideloadInitLua` detail, the reason the tmux module avoids `programs.tmux`,
  and the Yazi plugin's pin and `setup` call.

`tests/*.sh` still pass, except `tests/sing_box_config_test.sh`, which fails
with "sing-box must be on PATH" for reasons belonging to another slice in the
same tree.

Nothing was written about the legacy repository's retirement.

Deliberately not done: the four `SOFTWARE.md` rows and the `MIGRATION.md`
sections carry no "shipped and confirmed under normal use" line, because the
slice has not been through a VM activation yet. See the Comments on 01 to 03.
