#!/usr/bin/env bash
# Test built launchers without granting privileges or touching a disk.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
bin=${1:-$repo/result/home-path/bin}
bin=$(realpath -- "$bin")
(( EUID != 0 )) || { echo 'Run this test as an ordinary user.' >&2; exit 1; }
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$root/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$VENTOY_TEST_ARGS"
exit "${VENTOY_TEST_STATUS:-0}"
EOF
chmod +x "$root/sudo"
export PATH="$root:$PATH" VENTOY_TEST_ARGS="$root/args"

for command in ventoy ventoy-web; do
  "$bin/$command" --help > "$root/help"
  [[ ! -e $root/args ]] || fail "$command help requested root"
  [[ -s $root/help ]] || fail "$command help was empty"

  # A fake disk name must reach sudo as one argument, without interpretation.
  "$bin/$command" -i '/dev/not a device; echo unexpected' ''
  mapfile -d '' -t args < "$root/args"
  [[ ${#args[@]} == 5 && ${args[0]} == -- ]] || fail 'sudo argument boundary changed'
  [[ ${args[1]} == /nix/store/*/bin/"$command" ]] || fail 'sudo target is not a store executable'
  [[ -x ${args[1]} ]] || fail 'sudo target does not exist'
  [[ $(realpath -- "${args[1]}") != $(realpath -- "$bin/$command") ]] || fail 'sudo would recurse into the launcher'
  [[ ${args[2]} == -i && ${args[3]} == '/dev/not a device; echo unexpected' && ${args[4]} == '' ]] ||
    fail 'caller arguments changed'
  rm "$root/args"

  status=0
  VENTOY_TEST_STATUS=37 "$bin/$command" > /dev/null || status=$?
  [[ $status == 37 ]] || fail 'sudo denial status was lost'
  rm "$root/args"
done

for flag in -V --version; do
  "$bin/ventoy" "$flag" > "$root/version"
  [[ ! -e $root/args ]] || fail 'version query requested root'
  [[ -s $root/version ]] || fail 'version query was empty'
done

echo 'PASS: Ventoy launchers request sudo for operations and preserve arguments and failures'
