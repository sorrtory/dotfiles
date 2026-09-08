#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SUBJECT="$REPO_ROOT/scripts/bootstrap/03-secret-recovery.sh"
RECOVERY_PHASE_TEST_ROOT="$(mktemp -d)"
readonly RECOVERY_PHASE_TEST_ROOT
trap 'rm -rf -- "$RECOVERY_PHASE_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

test_home="$RECOVERY_PHASE_TEST_ROOT/home"
key_file="$test_home/.config/sops/age/keys.txt"
metadata_file="$key_file.recovery"
mock_bin="$RECOVERY_PHASE_TEST_ROOT/bin"
mkdir -p "$(dirname -- "$key_file")" "$mock_bin"
chmod 700 "$(dirname -- "$key_file")"

cat >"$mock_bin/nix" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$NIX_CALL_LOG"
key_file="$HOME/.config/sops/age/keys.txt"
mkdir -p "$(dirname -- "$key_file")"
printf 'recovered identity\n' >"$key_file"
chmod 600 "$key_file"
hash="$(sha256sum "$key_file")"
hash="${hash%% *}"
{
  printf 'recipient=%s\n' 'age1rmcmjswz8e7fanjzegmug24euprves7p240kkedun2sn4qvqkekqqvkgew'
  printf 'sha256=%s\n' "$hash"
} >"$key_file.recovery"
EOF
chmod +x "$mock_bin/nix"

if HOME="$test_home" "$SUBJECT" status >/dev/null 2>&1; then
  fail 'a missing identity should leave the phase unsatisfied'
fi

printf 'test identity\n' >"$key_file"
chmod 600 "$key_file"
hash="$(sha256sum "$key_file")"
hash="${hash%% *}"
{
  printf 'recipient=%s\n' 'age1rmcmjswz8e7fanjzegmug24euprves7p240kkedun2sn4qvqkekqqvkgew'
  printf 'sha256=%s\n' "$hash"
} >"$metadata_file"
chmod 600 "$metadata_file"

HOME="$test_home" "$SUBJECT" status >/dev/null ||
  fail 'matching identity metadata should satisfy the phase'

printf 'changed identity\n' >"$key_file"
chmod 600 "$key_file"
if HOME="$test_home" "$SUBJECT" status >/dev/null 2>&1; then
  fail 'a changed identity should invalidate recovery metadata'
fi

rm "$key_file" "$metadata_file"
nix_call_log="$RECOVERY_PHASE_TEST_ROOT/nix-call"
HOME="$test_home" PATH="$mock_bin:$PATH" NIX_CALL_LOG="$nix_call_log" \
  "$SUBJECT" install >/dev/null
grep -Eq '^run path:.+#recover-age-identity$' "$nix_call_log" ||
  fail 'the phase should invoke the packaged recovery app'

printf 'bootstrap secret recovery tests passed\n'
