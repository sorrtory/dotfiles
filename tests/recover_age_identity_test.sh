#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SUBJECT="$REPO_ROOT/scripts/repo/recover-age-identity.sh"
RECOVERY_TEST_ROOT="$(mktemp -d)"
readonly RECOVERY_TEST_ROOT
trap 'rm -rf -- "$RECOVERY_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mock_bin="$RECOVERY_TEST_ROOT/bin"
recovery_repo="$RECOVERY_TEST_ROOT/keepass"
key_file="$RECOVERY_TEST_ROOT/config/sops/age/keys.txt"
call_log="$RECOVERY_TEST_ROOT/calls"
mkdir -p "$mock_bin" "$recovery_repo/.git"
touch "$recovery_repo/Passwords.kdbx" "$call_log"

cat >"$mock_bin/gh" <<'EOF'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >>"$RECOVERY_CALL_LOG"
if [[ "$1 $2" == 'auth status' ]]; then
  [[ "${GH_AUTH_REQUIRED:-0}" == '0' ]]
fi
EOF

cat >"$mock_bin/git" <<'EOF'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$RECOVERY_CALL_LOG"
if [[ "$*" == *'status --porcelain'* ]]; then
  exit 0
fi
EOF

cat >"$mock_bin/keepassxc-cli" <<'EOF'
#!/usr/bin/env bash
printf 'keepassxc-cli %s\n' "$*" >>"$RECOVERY_CALL_LOG"
[[ "$1" == 'attachment-export' ]] || exit 2
if [[ "${MOCK_EXPORT_FAILS:-0}" != '0' ]]; then
  printf 'Entry %s not found.\n' "$3" >&2
  exit 1
fi
printf 'TEST-AGE-IDENTITY\n' >"${@: -1}"
EOF

cat >"$mock_bin/age-keygen" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == '-y' ]] || exit 2
grep -qx 'TEST-AGE-IDENTITY' "$2" || exit 1
printf '%s\n' "$MOCK_AGE_RECIPIENT"
EOF

chmod +x "$mock_bin/"*

run_recovery() {
  printf '\n' | env \
    PATH="$mock_bin:$PATH" \
    RECOVERY_CALL_LOG="$call_log" \
    RECOVERY_REPOSITORY_DIR="$recovery_repo" \
    AGE_KEY_FILE="$key_file" \
    MOCK_AGE_RECIPIENT="${MOCK_AGE_RECIPIENT:-age1rmcmjswz8e7fanjzegmug24euprves7p240kkedun2sn4qvqkekqqvkgew}" \
    "$SUBJECT" "$@"
}

GH_AUTH_REQUIRED=1 run_recovery install >/dev/null
[[ "$(<"$key_file")" == 'TEST-AGE-IDENTITY' ]] ||
  fail 'the attachment should be installed as the age identity'
[[ "$(stat -c '%a' "$key_file")" == '600' ]] ||
  fail 'the age identity should have mode 0600'
[[ "$(stat -c '%a' "$(dirname -- "$key_file")")" == '700' ]] ||
  fail 'the age identity directory should have mode 0700'
grep -qx 'recipient=age1rmcmjswz8e7fanjzegmug24euprves7p240kkedun2sn4qvqkekqqvkgew' "$key_file.recovery" ||
  fail 'recovery metadata should record the verified recipient'
grep -q '^keepassxc-cli attachment-export .*Encryption Keys/sops keys.txt ' "$call_log" ||
  fail 'the configured KeePassXC entry and attachment should be exported'
grep -qx 'gh auth login --hostname github.com --git-protocol https --web' "$call_log" ||
  fail 'missing GitHub credentials should trigger browser authentication'

run_recovery status >/dev/null || fail 'the recovered identity should satisfy status'

calls_before="$(wc -l <"$call_log")"
run_recovery install >/dev/null
calls_after="$(wc -l <"$call_log")"
[[ "$calls_before" -eq "$calls_after" ]] ||
  fail 'a valid recovered identity should skip all external work'

rm "$key_file.recovery"
run_recovery install >/dev/null
[[ -f "$key_file.recovery" ]] ||
  fail 'valid existing identities should have missing metadata repaired'
calls_after_repair="$(wc -l <"$call_log")"
[[ "$calls_after" -eq "$calls_after_repair" ]] ||
  fail 'repairing metadata should not access GitHub or KeePassXC'

printf 'WRONG-IDENTITY\n' >"$key_file"
chmod 600 "$key_file"
if run_recovery install >/dev/null 2>&1; then
  fail 'an existing mismatched identity should be rejected'
fi
[[ "$(<"$key_file")" == 'WRONG-IDENTITY' ]] ||
  fail 'a mismatched existing identity must not be overwritten'

bad_key_file="$RECOVERY_TEST_ROOT/bad/config/sops/age/keys.txt"
if printf '\n' | env \
  PATH="$mock_bin:$PATH" \
  RECOVERY_CALL_LOG="$call_log" \
  RECOVERY_REPOSITORY_DIR="$recovery_repo" \
  AGE_KEY_FILE="$bad_key_file" \
  MOCK_AGE_RECIPIENT='age1differentrecipient' \
  "$SUBJECT" install >/dev/null 2>&1; then
  fail 'an attachment with the wrong recipient should be rejected'
fi
[[ ! -e "$bad_key_file" ]] ||
  fail 'an attachment with the wrong recipient must not be installed'
if find "$(dirname -- "$bad_key_file")" -maxdepth 1 \
  -name '.recover-age-identity.*' -print -quit | grep -q .; then
  fail 'temporary identity material should be removed after failure'
fi

unresolved_key_file="$RECOVERY_TEST_ROOT/unresolved/config/sops/age/keys.txt"
export_output="$RECOVERY_TEST_ROOT/export-output"
if printf '\n' | env \
  PATH="$mock_bin:$PATH" \
  RECOVERY_CALL_LOG="$call_log" \
  RECOVERY_REPOSITORY_DIR="$recovery_repo" \
  AGE_KEY_FILE="$unresolved_key_file" \
  RECOVERY_ENTRY='Root/Encryption Keys/sops' \
  MOCK_EXPORT_FAILS=1 \
  "$SUBJECT" install >"$export_output" 2>&1; then
  fail 'a failing attachment export should fail the wizard'
fi
grep -q 'keepassxc-cli ls -R -f' "$export_output" ||
  fail 'a failing export should explain how to list the real entry paths'
[[ ! -e "$unresolved_key_file" ]] ||
  fail 'a failing export must not install an age identity'
if find "$(dirname -- "$unresolved_key_file")" -maxdepth 1 \
  -name '.recover-age-identity.*' -print -quit | grep -q .; then
  fail 'a failing export should leave no temporary identity material'
fi

# The configured recipient comes from .sops.yaml, so a config naming a
# different recipient must reject an otherwise valid attachment. This is what
# couples recovery to the file encryption actually uses.
run_with_config() {
  local config="$1" target="$2"

  printf '\n' | env \
    PATH="$mock_bin:$PATH" \
    RECOVERY_CALL_LOG="$call_log" \
    RECOVERY_REPOSITORY_DIR="$recovery_repo" \
    AGE_KEY_FILE="$target" \
    SOPS_CONFIG_FILE="$config" \
    MOCK_AGE_RECIPIENT="${MOCK_AGE_RECIPIENT:-age1rmcmjswz8e7fanjzegmug24euprves7p240kkedun2sn4qvqkekqqvkgew}" \
    "$SUBJECT" install
}

other_config="$RECOVERY_TEST_ROOT/other.sops.yaml"
printf 'keys:\n  - &z age1%s\n' "$(printf 'q%.0s' {1..58})" >"$other_config"
mismatch_key_file="$RECOVERY_TEST_ROOT/mismatch/config/sops/age/keys.txt"
if run_with_config "$other_config" "$mismatch_key_file" >/dev/null 2>&1; then
  fail 'an attachment not matching .sops.yaml should be rejected'
fi
[[ ! -e "$mismatch_key_file" ]] ||
  fail 'an attachment not matching .sops.yaml must not be installed'

# A config the recipient cannot be read from is a repository error, not a
# reason to fall back to some other value.
empty_config="$RECOVERY_TEST_ROOT/empty.sops.yaml"
printf 'creation_rules: []\n' >"$empty_config"
empty_key_file="$RECOVERY_TEST_ROOT/empty/config/sops/age/keys.txt"
if run_with_config "$empty_config" "$empty_key_file" >/dev/null 2>&1; then
  fail 'a config naming no recipient should fail loudly'
fi

ambiguous_config="$RECOVERY_TEST_ROOT/ambiguous.sops.yaml"
{
  printf 'keys:\n'
  printf '  - &a age1%s\n' "$(printf 'q%.0s' {1..58})"
  printf '  - &b age1%s\n' "$(printf 'p%.0s' {1..58})"
} >"$ambiguous_config"
ambiguous_key_file="$RECOVERY_TEST_ROOT/ambiguous/config/sops/age/keys.txt"
if run_with_config "$ambiguous_config" "$ambiguous_key_file" >/dev/null 2>&1; then
  fail 'a config naming several recipients should fail loudly'
fi

# A recipient that is too long must not contribute its first 58 characters as
# if they were a valid one; a truncated recipient verifies against a key
# nothing was encrypted to.
overlong_config="$RECOVERY_TEST_ROOT/overlong.sops.yaml"
printf 'keys:\n  - &z age1%szz\n' "$(printf 'q%.0s' {1..58})" >"$overlong_config"
overlong_key_file="$RECOVERY_TEST_ROOT/overlong/config/sops/age/keys.txt"
if run_with_config "$overlong_config" "$overlong_key_file" >/dev/null 2>&1; then
  fail 'a malformed recipient should fail loudly rather than be truncated'
fi

missing_config="$RECOVERY_TEST_ROOT/absent.sops.yaml"
missing_key_file="$RECOVERY_TEST_ROOT/absent/config/sops/age/keys.txt"
if run_with_config "$missing_config" "$missing_key_file" >/dev/null 2>&1; then
  fail 'a missing config should fail loudly'
fi

printf 'recover age identity tests passed\n'
