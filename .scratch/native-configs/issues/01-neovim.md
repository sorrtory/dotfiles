# 01 — Neovim

Status: claimed

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

## Comments

Implemented on the host. `configs/nvim/` is a verbatim copy of the legacy tree
including `lazy-lock.json`, minus the eight-line `fnm` shim; `grep -rn fnm
configs/nvim/` returns nothing. `modules/programs/neovim.nix` keeps `enable`
and `defaultEditor` and links the whole directory with `mkOutOfStoreSymlink`
in the `configRoot` shape `vscode.nix` uses. `nodejs` is in
`modules/packages.nix`. `.vimrc` is at `configs/vim/.vimrc`, exposed through
`home.file.".vimrc"`, and no Vim package is declared.

One thing the ticket could not have known: `programs.neovim` writes its own
generated `init.lua` into `nvim/`, and Home Manager refuses to install a file
inside a directory that is itself an out-of-store symlink — the build fails
with `Error installing file '.config/nvim/init.lua' outside $HOME`. The module
sets `sideloadInitLua = true`, which hands that generated Lua to the wrapper
instead of to a file. Nothing is lost, because this configuration generates
none. Recorded in `docs/DECISIONS.md` and `docs/MIGRATION.md` §10.

Verified on the host without activating, by running the built Neovim against a
copy of `configs/nvim/` in a throwaway `XDG_*` sandbox:

- `nix build .#homeConfigurations.z.activationPackage` succeeds, and the
  generated `home-manager-files` carries `.config/nvim` as a symlink resolving
  to `/home/z/Documents/dotfiles/configs/nvim`.
- `lazy.nvim` bootstrapped itself and installed every plugin in
  `lazy-lock.json`: 21 directories for 21 lock entries. The ticket's "16" is
  the number of declared specs; the other five are their dependencies
  (`plenary.nvim`, `nui.nvim`, `nvim-web-devicons`, `nvim-lspconfig`,
  `blink.cmp`).
- `vim.fn.exepath("node")` and `exepath("npm")` both resolve inside
  `/nix/store`, and `vim.env.PATH` contains no `fnm` path.
- `treesitter.lua`'s `auto_install` compiled its grammars with `cc` resolving
  inside `/nix/store`, which is the confirmation the ticket asked for about
  GCC. One grammar (`typescript`) failed a tarball extraction on first attempt
  and succeeded on the retry, which is nvim-treesitter's own download
  behaviour rather than anything this repository controls.
- mason installs against this Node: `prettierd` (npm) and
  `lua-language-server` (prebuilt download) both install, and `prettierd
  --help` runs, which is the runtime half of the Node argument rather than the
  install half.
- opening the sample `.ts` file attaches `ts_ls` and
  `vim.treesitter.highlighter.active` holds the buffer, so both acceptance
  behaviours for a TypeScript file hold.
- `:checkhealth` reports no missing dependency this configuration uses. It does
  report three things, none of them that: `luarocks` and Lua 5.1 are absent,
  which only limits plugins requiring rocks and none of the sixteen do;
  `Composer`, `PHP` and `julia` are absent under mason, which are optional
  runtimes for tools this configuration does not install; and "no clipboard
  tool" plus a non-UTF-8 locale are artifacts of the `env -i` sandbox, since
  `wl-clipboard` is already a global user tool and a real session has a locale.

What the host could not settle, and why: the staging VM could not be synced
from this session — `rsync` to the guest was refused by this session's
permission layer as a shared-resource change. A clean `bootstrap.sh install`
there, and `:Lazy` read in a real terminal, still want either that permission
or the operator.

## Comments — Operator activation on staging, 2026-09-15

The operator activated the Lubuntu VM and opened Neovim: every plugin
installed, but the first start needed "Press ENTER or type command to
continue" about fifty times. Two defects turned up, and the sandbox above hid
both: it ran headless, so it never showed a prompt, and a fresh-machine mason
install was never actually exercised.

**The prompts are nvim-treesitter's.** `ensure_installed` starts 36 grammar
installs at once, and each emits several progress lines. Reproduced on the VM
in a tmux pane with fresh `XDG_DATA_HOME`, `XDG_STATE_HOME` and
`XDG_CACHE_HOME`, pressing Enter whenever a prompt appeared: at 80×24 it took
37 `Press ENTER` and 62 `-- More --` prompts, every one on a treesitter line.
Nothing installs while a prompt waits: left unanswered, 0 of 36 grammars
existed after 91 s. At 140×40 the lines fit, and only one prompt appeared.

**mason installed nothing, on the operator's VM or in any reproduction.** Its
default provider resolves the registry version through
`api.mason-registry.dev`, which times out from the host, from the VM, and
through the VM's sing-box proxy, while `api.github.com`, `github.com` and the
npm registry answer. The registry never lands, so no server or formatter is
installed, and the editor is the subtly broken one this ticket warned about.

Fixes, both in `configs/nvim/`:

- `init.lua` enables Neovim 0.12's experimental `ui2`, which replaces the
  hit-enter prompt with collapsed messages (`g<` shows them). The operator
  chose it over quietening treesitter alone.
- `lua/plugins/lsp.lua` puts `mason.providers.client` ahead of
  `mason.providers.registry-api`. The client provider asks `gh`, and then
  `api.github.com`, for the latest registry release.

Evidence, with the edited tree copied to the VM as `XDG_CONFIG_HOME` and the
same fresh-directory harness at 80×24: no prompt of either kind, all 21
plugins, all 36 grammars, and all 25 mason packages (16 servers, 9 tools)
within 160 s. `mason.log` has two errors, neither a failure: `gh` is not
installed, so the client provider falls through to `api.github.com` as
designed, and PyPI metadata names no Python versions for one package.

Also seen, not fixed: opening a file whose grammar is in `ensure_installed`
starts `auto_install` for it as well, and the two installs race in one
directory (`src/scanner.c: No such file or directory`). One of them succeeds,
so it costs a single error on the first start only.

Remaining: the operator activating the fixed tree, which the change to
`init.lua` reaches live through the out-of-store link.
