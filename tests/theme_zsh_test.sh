#!/usr/bin/env bash
# Zsh's side of the theme: the generated file is valid zsh, zsh itself renders
# the palette's colors from it, the styles survive zsh-syntax-highlighting
# loading afterwards, and the reload hook .zshrc ships re-reads the file only
# when it changed. New files must be tracked (git add -N is enough) for the
# flake to see them.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v zsh >/dev/null || fail 'zsh must be on PATH'

theme_path="$HOME/.local/share/dotfiles/theme/zsh.zsh"

home() {
  printf '((builtins.getFlake "%s").homeConfigurations.z.extendModules { modules = [ ({ lib, ... }: { dotfiles.theme = lib.mapAttrs (_: lib.mkForce) (%s); }) ]; })' \
    "$REPO_ROOT" "$1"
}
generated() {
  nix build --impure --no-link --print-out-paths \
    --expr "$(home "$1").config.dotfiles.theme.liveFiles.\"$theme_path\"" 2>/dev/null ||
    fail "the theme file for $1 does not build"
}
# What zsh makes of a prompt escape, which is the only thing that says the
# colors reach the screen: reading %F{#rrggbb} back out of the file would
# pass just as well on a zsh too old to draw it.
rendered() {
  zsh -f -c "source ${1@Q}; print -rP -- \$$2" ||
    fail "zsh could not render $2 from $1"
}
sgr() { printf '\033[38;2;%d;%d;%dm' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"; }
# The first color zsh emitted for a prompt escape, whatever hex is behind it.
color_of() { [[ $1 =~ $'\033'\[[0-9\;]*m ]] && printf '%s' "${BASH_REMATCH[0]}"; }

for theme in gruvbox autumn-leaves onedark; do
  file=$(generated "{ name = \"$theme\"; }")
  zsh -n "$file" || fail "$theme: the theme file is not valid zsh"

  # An associative array, not the ordinary one a subscript assignment to an
  # undeclared name would have made.
  [[ $(zsh -f -c "source $file; echo \${(t)ZSH_HIGHLIGHT_STYLES}") == association ]] ||
    fail "$theme: ZSH_HIGHLIGHT_STYLES is not an associative array"

  for key in default unknown-token comment command path precommand \
    single-quoted-argument redirection globbing comment; do
    value=$(zsh -f -c "source $file; print -r -- \$ZSH_HIGHLIGHT_STYLES[$key]")
    [[ $value == fg=\#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]* ]] ||
      fail "$theme: style $key is \"$value\", not a hex"
  done
  [[ $(zsh -f -c "source $file; print -r -- \$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE") == fg=\#* ]] ||
    fail "$theme: the autosuggestion has no color"
done

# The palette reaches the prompt: each theme draws its own caret, and the
# branch its own brackets.
declare -A accents=([gruvbox]='#fe8019' [autumn-leaves]='#d2703f' [onedark]='#61afef')
for theme in "${!accents[@]}"; do
  file=$(generated "{ name = \"$theme\"; }")
  prompt=$(rendered "$file" PROMPT)
  [[ $prompt == *"$(sgr "${accents[$theme]}")"* ]] ||
    fail "$theme: the caret is not the accent"
  [[ $prompt == *"$(sgr "${accents[$theme]}")%"* ]] ||
    fail "$theme: the prompt does not end in the caret"
done

# The branch and the marker that says the tree is dirty have to be told apart
# in every palette, which rules out any role a palette is free to collapse
# into the second accent: autumn-leaves makes its warning that same copper.
for theme in gruvbox autumn-leaves onedark; do
  file=$(generated "{ name = \"$theme\"; }")
  branch=$(color_of "$(rendered "$file" ZSH_THEME_GIT_PROMPT_PREFIX)")
  dirty=$(color_of "$(rendered "$file" ZSH_THEME_GIT_PROMPT_DIRTY)")
  [[ -n $branch && -n $dirty ]] || fail "$theme: the branch has no color"
  [[ $branch != "$dirty" ]] ||
    fail "$theme: the dirty marker is the color of the brackets around it"
done

# The right prompt speaks only for a command that failed, in the error color.
file=$(generated '{ name = "gruvbox"; }')
[[ $(zsh -f -c "source $file; true; print -rP -- \$RPS1") == "" ]] ||
  fail 'the right prompt says something after a command that succeeded'
[[ $(zsh -f -c "source $file; false; print -rP -- \$RPS1") == *"$(sgr '#fb4934')1 "* ]] ||
  fail 'the right prompt does not show the status of a failed command'

# An override wins, the same way it does for every other themed app.
file=$(generated '{ overrides.zsh = { accent = "#123456"; }; }')
[[ $(rendered "$file" PROMPT) == *"$(sgr '#123456')"* ]] ||
  fail 'an override did not reach the prompt'

# zsh-syntax-highlighting fills in only the styles nobody set, so loading it
# after this file has to leave every generated style alone. .zshrc puts them
# in that order; this proves the order is the one that survives.
file=$(generated '{ name = "gruvbox"; }')
highlighter=$(nix build --impure --no-link --print-out-paths \
  --expr "$(home '{ }').config.programs.zsh.syntaxHighlighting.package" 2>/dev/null) ||
  fail 'zsh-syntax-highlighting does not build'
after=$(zsh -f -c "source $file
  source $highlighter/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  print -r -- \$ZSH_HIGHLIGHT_STYLES[comment] \$ZSH_HIGHLIGHT_STYLES[path]")
[[ $after == 'fg=#a89984 fg=#83a598,underline' ]] ||
  fail "the highlighter overwrote the generated styles: $after"

# The shell as it is actually configured: .zshrc reads the file, hooks the
# reload in front of the hooks oh-my-zsh registered, loads the colors as an
# oh-my-zsh theme of our own, and no longer carries the hard-coded suggestion
# color the generated file replaced.
generation=$(nix build --impure --no-link --print-out-paths \
  --expr "$(home '{ }').activationPackage" 2>/dev/null) ||
  fail 'the activation package does not build'
zshrc="$generation/home-files/.zshrc"
grep -qF "_dotfiles_theme_file=$theme_path" "$zshrc" || fail '.zshrc does not read the theme file'
grep -qF 'precmd_functions=(_dotfiles_theme_load $precmd_functions)' "$zshrc" ||
  fail '.zshrc does not hook the reload in front of the existing hooks'
# Quoted or bare, depending on whether escapeShellArg thought the string
# needed it, which is nixpkgs' business and not this test's.
custom_dir="$HOME/.local/share/dotfiles/zsh-custom"
grep -qE "^ZSH_THEME='?dotfiles'?\$" "$zshrc" || fail '.zshrc does not select the generated theme'
grep -qE "^ZSH_CUSTOM='?${custom_dir}'?\$" "$zshrc" ||
  fail '.zshrc does not point oh-my-zsh at the directory holding that theme'

# The theme oh-my-zsh will find under that name, at the path its `is_theme`
# checks. It holds no colors of its own: they are in the live file, because a
# store symlink carries the epoch mtime the reload hook would never see
# change. A shell before the first activation reads neither and still starts.
shim="$generation/home-files/.local/share/dotfiles/zsh-custom/themes/dotfiles.zsh-theme"
[[ -r $shim ]] || fail 'oh-my-zsh has no dotfiles.zsh-theme to load'
grep -qF "source $theme_path" "$shim" || fail 'the theme does not load the generated colors'
zsh -n "$shim" || fail 'the theme is not valid zsh'
sed "s|$theme_path|$TEST_ROOT/absent.zsh|g" "$shim" >"$TEST_ROOT/theme.zsh-theme"
[[ -z $(zsh -f -c "source $TEST_ROOT/theme.zsh-theme" 2>&1) ]] ||
  fail 'the theme complains out loud when the colors are not written yet'
# A theme is the last thing .zshrc runs, so a non-zero status here is what the
# first prompt would draw as a command that failed.
zsh -f -c "source $TEST_ROOT/theme.zsh-theme" ||
  fail 'the theme leaves a failed status when the colors are not written yet'
! grep -q 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE' "$zshrc" ||
  fail '.zshrc still sets the suggestion color itself'
line_of() { grep -n "$1" "$zshrc" | head -1 | cut -d: -f1; }
(( $(line_of 'oh-my-zsh.sh') < $(line_of '_dotfiles_theme_load()') )) ||
  fail 'the theme file is read before oh-my-zsh sets its own prompt'
(( $(line_of '_dotfiles_theme_load()') < $(line_of 'zsh-syntax-highlighting.zsh') )) ||
  fail 'the theme file is read after zsh-syntax-highlighting has taken its defaults'

# The reload itself, run as .zshrc ships it: a changed file is re-read at the
# next prompt, an unchanged one is not read again.
sed -n '/^typeset -g _dotfiles_theme_file=/,/^precmd_functions=(_dotfiles_theme_load/p' "$zshrc" \
  >"$TEST_ROOT/hook.zsh"
grep -q 'zstat' "$TEST_ROOT/hook.zsh" || fail 'the reload hook was not found in .zshrc'
live="$TEST_ROOT/zsh.zsh"
printf 'typeset -g reloads=$(( reloads + 1 ))\ntypeset -g tint=first\n' >"$live"
got=$(zsh -f -c "
  typeset -g reloads=0
  source $TEST_ROOT/hook.zsh
  _dotfiles_theme_file=$live
  _dotfiles_theme_mtime=
  _dotfiles_theme_load
  _dotfiles_theme_load
  printf 'typeset -g reloads=\$(( reloads + 1 ))\ntypeset -g tint=second\n' >$live
  touch -d '+1 minute' $live
  _dotfiles_theme_load
  print -r -- \$reloads \$tint")
[[ $got == '2 second' ]] ||
  fail "the reload should have run twice and ended on the new file, got \"$got\""

# A shell that starts before the first activation has nothing to read, and
# must still reach its prompt.
zsh -f -c "
  source $TEST_ROOT/hook.zsh
  _dotfiles_theme_file=$TEST_ROOT/absent.zsh
  _dotfiles_theme_mtime=
  _dotfiles_theme_load" || fail 'the reload fails when the theme file is missing'

printf 'theme Zsh tests passed\n'
