#!/usr/bin/env bash
# docs/WORKAROUNDS.md records, for each override of a Nixpkgs package, the
# packaged version that still has the defect being worked around. That is a
# claim about someone else's release, so it expires on its own: the entry stays
# accurate only until Nixpkgs moves past that version. This checks every such
# claim against what the flake evaluates today, so a `nix flake update` that
# happens to fix a workaround fails here, naming the entry to re-test, instead
# of leaving an override in place that quietly holds the environment back.
#
# A failure is not a broken build. It means an entry is due for review: either
# the workaround can go, or its recorded version and check date move forward.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$REPO_ROOT/docs/WORKAROUNDS.md"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

[ -r "$DOC" ] || fail 'docs/WORKAROUNDS.md is missing'

# Each entry is a "### " heading followed by its metadata bullets. Only the
# sections listing live workarounds are read; "## Removed" is history and names
# versions that are deliberately no longer current.
awk '
  function flush(  f) {
    if (buf == "") return
    f = ""
    if (buf ~ /\*\*Defect in:\*\*/)      f = "defect"
    else if (buf ~ /\*\*Checked:\*\*/)   f = "checked"
    else if (buf ~ /\*\*Upstream:\*\*/)  f = "upstream"
    else if (buf ~ /\*\*Defined in:\*\*/) f = "defined"
    else if (buf ~ /\*\*Removed when\*\*/) f = "removed"
    if (f != "" && name != "") print name "\t" f "\t" buf
    buf = ""
  }
  /^## / { flush(); live = ($0 == "## Carried silently" || $0 == "## Self-announcing"); name = ""; next }
  !live { next }
  /^### / { flush(); name = substr($0, 5); next }
  name == "" { next }
  # A field runs from its marker until the next one, a blank line or a heading;
  # continuation lines are indented, which is how the document wraps at 79.
  /^(- )?\*\*/ { flush(); buf = $0; next }
  /^[ \t]+[^ \t]/ && buf != "" { buf = buf " " $0; sub(/[ \t]+/, " ", buf); next }
  { flush() }
' "$DOC" > "$TEST_ROOT/fields"

cut -f1 "$TEST_ROOT/fields" | uniq > "$TEST_ROOT/entries"
[ -s "$TEST_ROOT/entries" ] || fail 'no workaround entries found; has the document layout changed?'

field() { # entry, field name
  awk -F'\t' -v n="$1" -v f="$2" '$1 == n && $2 == f { print $3; found = 1 } END { exit !found }' \
    "$TEST_ROOT/fields"
}

# Every entry carries the full record, so none can be added as prose alone.
while read -r entry; do
  for f in defect checked upstream defined removed; do
    field "$entry" "$f" >/dev/null || fail "$entry: no **$f** field; see the other entries for the shape"
  done

  checked=$(field "$entry" checked | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}') ||
    fail "$entry: **Checked:** is not an ISO date"

  # The definition must exist, so a moved override cannot orphan its entry.
  target=$(field "$entry" defined | grep -oE '\]\(\.\./[^)#]+\)' | head -1 | sed 's/](\.\.\///;s/)$//') ||
    fail "$entry: **Defined in:** links to nothing under the repository root"
  [ -e "$REPO_ROOT/$target" ] || fail "$entry: **Defined in:** points at $target, which does not exist"

  defect=$(field "$entry" defect)
  attr=$(printf '%s' "$defect" | grep -oE '`[^`]+`' | head -1 | tr -d '`') ||
    fail "$entry: **Defect in:** names no attribute"
  version=$(printf '%s' "$defect" | sed -n 's/.*` at \([^ ,.]*\(\.[^ ,]*\)*\)[,.].*/\1/p')
  [ -n "$version" ] || fail "$entry: **Defect in:** names no version after the attribute"

  # The attribute is interpolated into a Nix expression below.
  printf '%s' "$attr" | grep -qE '^(pkgs|unstablePkgs)(\.[A-Za-z0-9_-]+)+$' ||
    fail "$entry: **Defect in:** names $attr, which is not a pkgs or unstablePkgs attribute path"

  printf '%s\t%s\t%s\t%s\n' "$entry" "$attr" "$version" "$checked" >> "$TEST_ROOT/claims"
done < "$TEST_ROOT/entries"

# One evaluation for every claim, so the cost does not grow with the file.
{
  printf 'let f = builtins.getFlake "%s";\n' "$REPO_ROOT"
  printf '    pkgs = f.homeConfigurations.z.pkgs;\n'
  printf '    unstablePkgs = f.inputs.nixpkgs-unstable.legacyPackages.${builtins.currentSystem};\n'
  printf 'in {\n'
  cut -f2 "$TEST_ROOT/claims" | sort -u | while read -r attr; do
    printf '  "%s" = (%s).version;\n' "$attr" "$attr"
  done
  printf '}\n'
} > "$TEST_ROOT/expr.nix"

nix eval --impure --json --file "$TEST_ROOT/expr.nix" > "$TEST_ROOT/packaged" 2>"$TEST_ROOT/eval.err" ||
  fail "could not evaluate the recorded attributes: $(cat "$TEST_ROOT/eval.err")"
command -v jq >/dev/null || fail 'jq must be on PATH'

stale=0
while IFS=$'\t' read -r entry attr recorded checked; do
  packaged=$(jq -r --arg a "$attr" '.[$a]' "$TEST_ROOT/packaged")
  [ "$packaged" = "$recorded" ] && continue
  stale=1
  printf 'STALE: %s\n  %s is %s; the workaround was recorded against %s on %s.\n' \
    "$entry" "$attr" "$packaged" "$recorded" "$checked" >&2
  printf '  Re-test it: if the defect is gone, delete the override and move the entry\n'  >&2
  printf '  under "## Removed"; if it remains, update **Defect in:** and **Checked:**.\n' >&2
done < "$TEST_ROOT/claims"
[ "$stale" -eq 0 ] || fail "$(wc -l < "$TEST_ROOT/claims") workarounds checked, at least one out of date"

printf 'ok: %s workarounds still apply to the packaged versions recorded\n' \
  "$(wc -l < "$TEST_ROOT/claims")"
