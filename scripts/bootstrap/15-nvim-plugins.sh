#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

# Neovim's own package managers, run once here instead of on the operator's
# first real edit. lazy.nvim clones the plugin tree, mason downloads the
# language servers and formatters, and nvim-treesitter builds the parsers.
# Together they fetch around a gigabyte from a couple of dozen upstreams; left
# alone, all of it lands while the editor is first being used on a new machine.
#
# This is a phase rather than a Home Manager activation step on purpose.
# Activation runs on every switch and must stay fast, offline and unprivileged;
# a network fetch this size with no timeout and no retry does not belong there.
# docs/DECISIONS.md also records that lazy.nvim and mason keep ownership of
# these, deliberately trading reproducibility for lazy-loading and live
# editing. This phase moves *when* the download happens and changes nothing
# about who owns it, so both editor-side lists stay the single source of truth.
#
# Nothing here carries a copy of those lists. The driver below reads them back
# out of the same plugin specs the editor reads.

# Derived from the environment nvim itself reads rather than from phase-only
# overrides, so the driver below and the plain `nvim` that drives lazy.nvim
# always agree about which configuration and which data directory are in play.
# Pointing XDG_CONFIG_HOME and XDG_DATA_HOME elsewhere is how this phase is
# exercised against a throwaway tree, the same way tests/theme_nvim_test.sh
# drives the editor.
NVIM_CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
readonly NVIM_CONFIG_ROOT
NVIM_DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
readonly NVIM_DATA_ROOT

# mason-tool-installer's synchronous wait is an unbounded `while true` around
# vim.wait, so a stalled download would hang the phase forever rather than
# fail it. These are the only thing that ends such a run.
readonly CHECK_TIMEOUT="${BOOTSTRAP_NVIM_CHECK_TIMEOUT:-120}"
readonly PLUGIN_TIMEOUT="${BOOTSTRAP_NVIM_PLUGIN_TIMEOUT:-900}"
readonly TOOL_TIMEOUT="${BOOTSTRAP_NVIM_TOOL_TIMEOUT:-2700}"

# Inspects or drives all three managers from outside the editor, in `check` or
# `install` mode. Started with -u NONE and an explicit runtimepath rather than
# the real configuration: the wanted sets and mason's own options are read from
# the plugin specs as data, so the run has no colorscheme, no autocommands, no
# lazy.nvim update checker and no theme file to find.
#
# Exits 0 having printed a report, or 2 when it cannot inspect at all.
nvim_driver() (
  local workdir mode timeout_seconds
  mode="$1"
  timeout_seconds="$2"

  workdir="$(mktemp -d)" || return 2
  NVIM_DRIVER_WORKDIR="$workdir"
  trap 'rm -rf -- "$NVIM_DRIVER_WORKDIR"' EXIT

  cat >"$workdir/driver.lua" <<'DRIVER'
local mode = (arg and arg[1]) or "check"
local conf = assert(os.getenv("NVIM_CONFIG_DIR"), "NVIM_CONFIG_DIR is unset")
local data = assert(os.getenv("NVIM_DATA_DIR"), "NVIM_DATA_DIR is unset")
local uv = vim.uv or vim.loop

local function die(message)
  io.stderr:write(message .. "\n")
  os.exit(2)
end

-- The wanted sets, read from the editor's specs as plain data. These files
-- return a table and evaluate nothing at their top level, so dofile yields the
-- spec without loading a plugin. Any spec carrying ensure_installed
-- contributes to the union mason is asked for: mason-lspconfig's servers and
-- mason-tool-installer's formatters and linters alike, named the way each
-- names them. mason-tool-installer maps lspconfig names to package names
-- itself, which is why one undifferentiated list is enough.
local mason_opts, wanted, wanted_parsers = {}, {}, {}
for _, file in ipairs({ "lsp.lua", "format.lua" }) do
  local ok, spec = pcall(dofile, conf .. "/lua/plugins/" .. file)
  if not ok then
    die(("cannot read %s as a plugin spec: %s"):format(file, spec))
  end
  for _, plugin in ipairs(spec) do
    if plugin[1] == "mason-org/mason.nvim" then
      mason_opts = plugin.opts or {}
    elseif type(plugin.opts) == "table" and plugin.opts.ensure_installed then
      for _, name in ipairs(plugin.opts.ensure_installed) do
        table.insert(wanted, name)
      end
    end
  end
end
if #wanted == 0 then
  die("no ensure_installed entries found; the plugin specs have changed shape")
end

local ok, tree_spec = pcall(dofile, conf .. "/lua/plugins/treesitter.lua")
if not ok then
  die("cannot read treesitter.lua as a plugin spec: " .. tree_spec)
end
for _, plugin in ipairs(tree_spec) do
  if plugin[1] == "nvim-treesitter/nvim-treesitter"
      and type(plugin.opts) == "table"
      and plugin.opts.ensure_installed then
    wanted_parsers = plugin.opts.ensure_installed
  end
end
if #wanted_parsers == 0 then
  die("no Tree-sitter parsers found; the plugin spec has changed shape")
end

-- lazy.nvim's own bootstrap checks for the file it requires rather than the
-- directory, because an interrupted clone leaves a directory holding only
-- .git. The same reasoning applies to every plugin here.
local function plugin_installed(name)
  return uv.fs_stat(data .. "/lazy/" .. name) ~= nil
end

local missing_plugins = {}
local lock = io.open(conf .. "/lazy-lock.json")
if not lock then
  die("cannot read lazy-lock.json in " .. conf)
end
local locked = vim.json.decode(lock:read("*a"))
lock:close()
if not uv.fs_stat(data .. "/lazy/lazy.nvim/lua/lazy/init.lua") then
  table.insert(missing_plugins, "lazy.nvim")
end
for name in pairs(locked) do
  if name ~= "lazy.nvim" and not plugin_installed(name) then
    table.insert(missing_plugins, name)
  end
end
table.sort(missing_plugins)

-- mason cannot be consulted before its own plugin is on disk, and on a fresh
-- machine it is not. Everything is then missing, which is the truthful answer
-- and the one that makes install run.
local mason_ready = plugin_installed("mason.nvim")
  and plugin_installed("mason-lspconfig.nvim")
  and plugin_installed("mason-tool-installer.nvim")

if mason_ready then
  for _, name in ipairs({ "mason.nvim", "mason-lspconfig.nvim", "mason-tool-installer.nvim" }) do
    vim.opt.rtp:prepend(data .. "/lazy/" .. name)
  end
  -- install_root_dir is named rather than left to default, because mason
  -- derives it from stdpath("data") and would otherwise inspect whichever
  -- tree this nvim happens to point at instead of the one the phase manages.
  -- The two are the same path in ordinary use; naming it is what makes the
  -- phase's own data-directory override mean anything.
  mason_opts = vim.tbl_deep_extend("force", mason_opts, {
    install_root_dir = data .. "/mason",
  })
  -- Local only: this sets the editor's PATH, appends the registry sources and
  -- registers the commands. It reaches no network, which is what keeps the
  -- check side of this script usable as a read-only status probe.
  require("mason").setup(mason_opts)
end

-- main has this module; the frozen legacy branch does not. Treat an old
-- checkout as not ready so status can request the migration instead of dying
-- while trying to call the rewritten API on it.
local treesitter_ready = uv.fs_stat(
  data .. "/lazy/nvim-treesitter/lua/nvim-treesitter/init.lua"
) ~= nil
if treesitter_ready then
  vim.opt.rtp:prepend(data .. "/lazy/nvim-treesitter")
end

-- The lspconfig-name to package-name map is derived from the registry cached
-- under mason/registries, so it answers offline once a machine has installed
-- anything at all. Before that it is empty and every mapped name resolves to
-- nothing, which again reads as missing rather than as a failure.
local function missing_tools()
  local registry = require("mason-registry")
  local map = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
  local missing = {}
  for _, name in ipairs(wanted) do
    local package_name = map[name] or name
    if not registry.has_package(package_name) or not registry.is_installed(package_name) then
      table.insert(missing, name)
    end
  end
  table.sort(missing)
  return missing
end

local function missing_parsers()
  if not treesitter_ready then
    return wanted_parsers
  end

  local missing = {}
  for _, name in ipairs(wanted_parsers) do
    if not uv.fs_stat(data .. "/site/parser/" .. name .. ".so") then
      table.insert(missing, name)
    end
  end
  table.sort(missing)
  return missing
end

if mode == "install" then
  if not mason_ready then
    die("mason's plugins are not installed; plugins must be fetched first")
  end
  -- run_on_start is switched off so the deferred pass over format.lua's list
  -- alone cannot race the explicit one over the union below. Nothing else
  -- needs overriding: this is the only setup() this nvim performs, so
  -- auto_update stays false and debounce_hours stays nil, and the debounce
  -- guard therefore never blocks a phase that was asked to install.
  require("mason-tool-installer").setup({
    ensure_installed = wanted,
    run_on_start = false,
  })
  -- force_update is deliberately false. Passing true would send every already
  -- installed package through a latest-version check and reinstall the ones
  -- that moved, so a single missing tool would quietly update the other
  -- twenty-four. Bringing the machine up to the declared set is this phase's
  -- job; updating what is already there is the operator's, through :Mason.
  -- The second argument blocks until every package has closed.
  require("mason-tool-installer").check_install(false, true)

  if not treesitter_ready then
    die("nvim-treesitter is not installed; plugins must be fetched first")
  end
  require("nvim-treesitter").setup({ install_dir = data .. "/site" })
  local task = require("nvim-treesitter").install(wanted_parsers, { summary = true })
  if not task:wait() then
    die("one or more Tree-sitter parsers failed to install")
  end
end

local missing = mason_ready and missing_tools() or wanted
local parsers_missing = missing_parsers()
-- Written to stdout by hand: under --headless, print() is routed to stderr,
-- where the phase would never see it.
for _, name in ipairs(missing_plugins) do
  io.stdout:write("missing plugin " .. name .. "\n")
end
for _, name in ipairs(missing) do
  io.stdout:write("missing tool " .. name .. "\n")
end
for _, name in ipairs(parsers_missing) do
  io.stdout:write("missing parser " .. name .. "\n")
end
io.stdout:write(("summary %d %d %d\n"):format(
  vim.tbl_count(locked), #wanted, #wanted_parsers
))
DRIVER

  NVIM_CONFIG_DIR="$NVIM_CONFIG_ROOT" NVIM_DATA_DIR="$NVIM_DATA_ROOT" \
    timeout "$timeout_seconds" nvim -u NONE --headless -l "$workdir/driver.lua" "$mode"
)

# Names the first few missing entries rather than all of them: a fresh machine
# is missing everything, and a list of fifty tells the operator nothing that
# the count does not.
report_missing() {
  local kind="$1" report="$2"
  local -a names=()

  mapfile -t names < <(awk -v kind="$kind" '$1 == "missing" && $2 == kind { print $3 }' <<<"$report")
  if [[ ${#names[@]} -eq 0 ]]; then
    return 0
  fi
  local noun="${kind}s"
  if [[ ${#names[@]} -eq 1 ]]; then
    noun="$kind"
  fi
  if [[ ${#names[@]} -gt 5 ]]; then
    phase_info "missing ${#names[@]} $noun: ${names[*]:0:5} and $((${#names[@]} - 5)) more"
  else
    phase_info "missing ${#names[@]} $noun: ${names[*]}"
  fi
  return 1
}

check() {
  local report summary

  if ! command -v nvim >/dev/null 2>&1; then
    phase_error 'nvim is not on PATH; the home-manager phase provides it'
    return 2
  fi
  if [[ ! -d "$NVIM_CONFIG_ROOT" ]]; then
    phase_error "no Neovim configuration at $NVIM_CONFIG_ROOT"
    return 2
  fi

  if ! report="$(nvim_driver check "$CHECK_TIMEOUT")"; then
    phase_error 'could not inspect the installed plugins and tools'
    return 2
  fi

  summary="$(awk '$1 == "summary" { print $2, $3, $4 }' <<<"$report")"
  if [[ -z "$summary" ]]; then
    phase_error 'the inspection produced no summary'
    return 2
  fi

  local locked wanted wanted_parsers
  read -r locked wanted wanted_parsers <<<"$summary"

  local result=0
  report_missing plugin "$report" || result=1
  report_missing tool "$report" || result=1
  report_missing parser "$report" || result=1
  if [[ $result -eq 0 ]]; then
    phase_info "$locked plugins, $wanted language servers and formatters, and $wanted_parsers Tree-sitter parsers are installed"
  fi
  return "$result"
}

install() {
  local lock="$NVIM_CONFIG_ROOT/lazy-lock.json"
  local before='' after=''

  if [[ -f "$lock" ]]; then
    before="$(sha256sum "$lock")"
  fi

  phase_info 'fetching the plugin tree at the revisions lazy-lock.json pins'
  # Restore existing checkouts before install gets a chance to rewrite the
  # lock from their current branches. Missing plugins are then cloned by
  # install. The bootstrap flag keeps eager plugins unloaded while an old
  # checkout is being replaced; a fresh Nvim process below loads the result.
  timeout "$PLUGIN_TIMEOUT" nvim --headless \
    --cmd 'let g:dotfiles_bootstrap = v:true' \
    "+Lazy! restore" "+Lazy! install" +qa

  # lazy.nvim prunes the lock file to whatever the spec currently declares, so
  # a spec and a lock that disagree leave this phase having edited a
  # version-controlled file in the operator's own checkout. Reverting it would
  # be wrong, since the spec is the thing that moved; saying so is not.
  if [[ -f "$lock" ]]; then
    after="$(sha256sum "$lock")"
  fi
  if [[ "$before" != "$after" ]]; then
    phase_info 'lazy.nvim rewrote lazy-lock.json to match the plugin spec; it is version-controlled, so review the change'
  fi

  phase_info 'installing the language servers, formatters and Tree-sitter parsers; this is the slow part'
  nvim_driver install "$TOOL_TIMEOUT" >/dev/null
}

# These three managers' trees are the whole of this phase's state. Everything else
# under the data directory belongs to the editor's own use of it: shada,
# telescope history, neo-tree's log.
is_uninstalled() {
  if [[ -d "$NVIM_DATA_ROOT/lazy" || -d "$NVIM_DATA_ROOT/mason" \
    || -d "$NVIM_DATA_ROOT/site/parser" || -d "$NVIM_DATA_ROOT/site/queries" \
    || -d "$NVIM_DATA_ROOT/site/parser-info" ]]; then
    return 1
  fi
  phase_info 'no plugin, mason or Tree-sitter tree is present'
}

uninstall() {
  phase_info "removing the plugin, mason and Tree-sitter trees under $NVIM_DATA_ROOT"
  rm -rf -- "$NVIM_DATA_ROOT/lazy" "$NVIM_DATA_ROOT/mason" \
    "$NVIM_DATA_ROOT/mason-tool-installer-debounce" \
    "$NVIM_DATA_ROOT/site/parser" "$NVIM_DATA_ROOT/site/queries" \
    "$NVIM_DATA_ROOT/site/parser-info"
}

phase_main "$@"
