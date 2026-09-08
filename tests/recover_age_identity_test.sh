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

printf 'recover age identity tests passed\n'
