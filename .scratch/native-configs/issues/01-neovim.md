# 01 — Neovim

Status: ready-for-agent

## Goal

Move the Neovim configuration into this repository as a live-editable native
tree, and make Nix supply the runtime dependencies that `lazy.nvim` and mason
assume are already on `PATH`.

## Work

1. Copy `~/Documents/configs/nvim/` to `configs/nvim/`, including
   `lazy-lock.json`. Copy verbatim except for step 4.
2. Extend `modules/programs/neovim.nix`: keep `enable` and `defaultEditor`,
   and add `xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink
   "${configRoot}"`, following the `configRoot` shape used in
   `modules/programs/vscode.nix`.
3. Add Node.js to `modules/packages.nix` as a global user tool.
4. Delete the `fnm` PATH shim at `configs/nvim/init.lua` lines 4 to 11.
5. Copy `~/Documents/configs/.vimrc` to `configs/vim/.vimrc` and expose it
   with `home.file.".vimrc"`. Do not declare Vim as a package.

## Constraints

- **Nix does not own the plugins.** `lazy.nvim`, `lazy-lock.json`, and all
  three mason plugins stay exactly as they are. Do not add
  `programs.neovim.plugins`, do not introduce nixvim, and do not translate
  any Lua.
- **Node is the point of this ticket.** Ten of the sixteen servers in
  `configs/nvim/lua/plugins/lsp.lua` are npm packages that need Node at
  runtime, not just at install time: `pyright`, `ts_ls`, `eslint`, `html`,
  `cssls`, `jsonls`, `tailwindcss`, `yamlls`, `bashls`, `dockerls`. So are
  `prettierd` and `prettier` in `format.lua`. Without Node on `PATH` those
  silently fail to start and the editor looks subtly broken rather than
  obviously broken.
- `docs/SOFTWARE.md` currently says Node.js is *"Deferred; projects own
  runtimes unless a global requirement is selected."* This ticket is that
  selection. Update the row rather than contradicting it silently.
- fnm is not migrated. The shim exists because fnm's `PATH` does not survive a
  GUI or session launch; a Nix-provided Node has no such problem, so
  reproducing the workaround would preserve a bug.
- `treesitter.lua` sets `auto_install = true` over 30 grammars and compiles
  them with a C compiler. GCC is already in the global development baseline,
  so leave this alone — but confirm it, because a fresh VM with no compiler
  would fail here.
- `.vimrc` is repository material, not a migration slice. It has no plugins,
  the operator does not use it, and its own header describes it as a drop-in
  for remote servers. Five lines of work, no Vim package.

## Acceptance

- `nix build .#homeConfigurations.z.activationPackage` succeeds.
- On the staging VM after a clean `bootstrap.sh install`:
  - `~/.config/nvim` resolves to `~/Documents/dotfiles/configs/nvim`;
  - `node --version` resolves inside `/nix/store`;
  - `nvim` opens, `:Lazy` reports all 16 plugins installed, and `:checkhealth`
    reports no missing external dependency;
  - opening a `.ts` file attaches `ts_ls` and shows treesitter highlighting;
  - `:lua vim.print(vim.env.PATH)` contains no `fnm` path.
- `grep -rn fnm configs/nvim/` returns nothing.
