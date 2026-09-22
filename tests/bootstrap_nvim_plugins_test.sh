#!/usr/bin/env bash
# The nvim-plugins phase's status contract: what it reports satisfied, what it
# reports unfinished, what it refuses to judge, and that inspecting changes
# nothing. Installation is not exercised here, because it downloads about a
# gigabyte from a couple of dozen upstreams; the phase is driven against the
# real installed trees instead, the way tests/theme_nvim_test.sh does.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

phase="$REPO_ROOT/scripts/bootstrap/15-nvim-plugins.sh"
command -v nvim >/dev/null || fail 'nvim must be on PATH'
installed="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
[[ -d $installed/lazy ]] || fail "no installed plugins in $installed/lazy; run nvim once first"
[[ -d $installed/mason ]] || fail "no mason tree in $installed/mason; run nvim once first"
[[ -d $installed/site/parser ]] || fail "no installed Tree-sitter parsers in $installed/site; run the nvim-plugins phase"

# Each case is a configuration directory and a data directory handed to the
# phase through the same environment nvim itself reads.
STATUS_OUTPUT=""
STATUS_CODE=0
status_of() {
  local config="$1" data="$2"
  STATUS_OUTPUT=""
  STATUS_CODE=0
  STATUS_OUTPUT="$(XDG_CONFIG_HOME="$config" XDG_DATA_HOME="$data" \
    bash "$phase" status 2>&1)" || STATUS_CODE=$?
}

mkdir -p "$TEST_ROOT/config"
ln -s "$REPO_ROOT/configs/nvim" "$TEST_ROOT/config/nvim"

# A branch migration must be able to restore a legacy eager plugin before its
# incompatible config runs. The bootstrap flag makes only this spec lazy for
# that first process; normal starts remain eager.
XDG_STATE_HOME="$TEST_ROOT/state" nvim -u NONE -i NONE -n --headless \
  "+lua vim.g.dotfiles_bootstrap = true; local spec = dofile('$REPO_ROOT/configs/nvim/lua/plugins/treesitter.lua'); assert(spec[1].lazy == true); vim.g.dotfiles_bootstrap = nil; spec = dofile('$REPO_ROOT/configs/nvim/lua/plugins/treesitter.lua'); assert(spec[1].lazy == false)" \
  +qa

# A complete machine: the operator's own plugin and mason trees.
mkdir -p "$TEST_ROOT/complete/nvim"
ln -s "$installed/lazy" "$TEST_ROOT/complete/nvim/lazy"
ln -s "$installed/mason" "$TEST_ROOT/complete/nvim/mason"
ln -s "$installed/site" "$TEST_ROOT/complete/nvim/site"
status_of "$TEST_ROOT/config" "$TEST_ROOT/complete"
[[ $STATUS_CODE -eq 0 ]] ||
  fail "a complete tree reported $STATUS_CODE: $STATUS_OUTPUT"

# Inspecting must not create or alter anything, least of all a mason tree.
mkdir -p "$TEST_ROOT/empty/nvim"
status_of "$TEST_ROOT/config" "$TEST_ROOT/empty"
[[ $STATUS_CODE -eq 1 ]] || fail "an empty tree reported $STATUS_CODE: $STATUS_OUTPUT"
[[ "$STATUS_OUTPUT" == *"missing 24 plugins"* ]] ||
  fail "empty tree did not report missing plugins: $STATUS_OUTPUT"
[[ "$STATUS_OUTPUT" == *"missing 25 tools"* ]] ||
  fail "empty tree did not report missing tools: $STATUS_OUTPUT"
[[ "$STATUS_OUTPUT" == *"missing 35 parsers"* ]] ||
  fail "empty tree did not report missing parsers: $STATUS_OUTPUT"
[[ ! -e "$TEST_ROOT/empty/nvim/mason" ]] || fail 'status created a mason tree'
[[ ! -e "$TEST_ROOT/empty/nvim/lazy" ]] || fail 'status created a plugin tree'
[[ ! -e "$TEST_ROOT/empty/nvim/site" ]] || fail 'status created a Tree-sitter tree'

# An installed plugin tree without parsers is incomplete, but inspecting it
# must not create the parser installation directories.
mkdir -p "$TEST_ROOT/parserless/nvim"
ln -s "$installed/lazy" "$TEST_ROOT/parserless/nvim/lazy"
ln -s "$installed/mason" "$TEST_ROOT/parserless/nvim/mason"
status_of "$TEST_ROOT/config" "$TEST_ROOT/parserless"
[[ $STATUS_CODE -eq 1 ]] || fail "a parser-less tree reported $STATUS_CODE: $STATUS_OUTPUT"
[[ "$STATUS_OUTPUT" == *"missing 35 parsers"* ]] ||
  fail "parser-less tree did not report missing parsers: $STATUS_OUTPUT"
[[ ! -e "$TEST_ROOT/parserless/nvim/site" ]] || fail 'status created parser directories'

# Plugins without their tools is the state a machine reaches partway through.
mkdir -p "$TEST_ROOT/partial/nvim"
ln -s "$installed/lazy" "$TEST_ROOT/partial/nvim/lazy"
ln -s "$installed/site" "$TEST_ROOT/partial/nvim/site"
status_of "$TEST_ROOT/config" "$TEST_ROOT/partial"
[[ $STATUS_CODE -eq 1 ]] || fail "a mason-less tree reported $STATUS_CODE: $STATUS_OUTPUT"
[[ "$STATUS_OUTPUT" == *"missing 25 tools"* ]] ||
  fail "mason-less tree did not report missing tools: $STATUS_OUTPUT"
[[ "$STATUS_OUTPUT" != *"missing"*"parsers"* ]] ||
  fail "mason-less tree reported parsers missing: $STATUS_OUTPUT"
[[ "$STATUS_OUTPUT" != *"missing"*"plugins"* ]] ||
  fail "mason-less tree reported plugins missing: $STATUS_OUTPUT"

# A configuration that cannot be read is unjudgeable rather than unfinished,
# so it must exit above 1 and stop the flow instead of triggering an install.
status_of "$TEST_ROOT/nonexistent" "$TEST_ROOT/complete"
[[ $STATUS_CODE -eq 2 ]] ||
  fail "a missing configuration must report exit 2, got $STATUS_CODE"

mkdir -p "$TEST_ROOT/broken/nvim/lua/plugins"
cp "$REPO_ROOT/configs/nvim/lazy-lock.json" "$TEST_ROOT/broken/nvim/lazy-lock.json"
printf 'this is not a plugin spec\n' >"$TEST_ROOT/broken/nvim/lua/plugins/lsp.lua"
status_of "$TEST_ROOT/broken" "$TEST_ROOT/complete"
[[ $STATUS_CODE -eq 2 ]] ||
  fail "an unreadable plugin spec must report exit 2, got $STATUS_CODE"

# Uninstall owns the two managers' trees and nothing else under the data
# directory. Plain directories, never the symlinks above, so a mistake here
# cannot reach the operator's own tree.
mkdir -p "$TEST_ROOT/removable/nvim/lazy/plugin" \
  "$TEST_ROOT/removable/nvim/mason/bin" \
  "$TEST_ROOT/removable/nvim/site/parser" \
  "$TEST_ROOT/removable/nvim/site/queries" \
  "$TEST_ROOT/removable/nvim/site/parser-info" \
  "$TEST_ROOT/removable/nvim/site/pack/kept" \
  "$TEST_ROOT/removable/nvim/telescope_history"
XDG_DATA_HOME="$TEST_ROOT/removable" bash "$phase" uninstall >/dev/null
[[ ! -e "$TEST_ROOT/removable/nvim/lazy" ]] || fail 'uninstall left the plugin tree'
[[ ! -e "$TEST_ROOT/removable/nvim/mason" ]] || fail 'uninstall left the mason tree'
[[ ! -e "$TEST_ROOT/removable/nvim/site/parser" ]] || fail 'uninstall left Tree-sitter parsers'
[[ -d "$TEST_ROOT/removable/nvim/site/pack/kept" ]] || fail 'uninstall removed unrelated site data'
[[ -d "$TEST_ROOT/removable/nvim/telescope_history" ]] ||
  fail 'uninstall removed unrelated editor state'
if XDG_DATA_HOME="$TEST_ROOT/removable" bash "$phase" uninstall >/dev/null 2>&1; then
  fail 'uninstall repeated on an absent tree'
fi

printf 'bootstrap nvim-plugins tests passed\n'
