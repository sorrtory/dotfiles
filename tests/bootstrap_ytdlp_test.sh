#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SUBJECT="$REPO_ROOT/scripts/bootstrap/06-yt-dlp.sh"
YTDLP_TEST_ROOT="$(mktemp -d)"
readonly YTDLP_TEST_ROOT
trap 'rm -rf -- "$YTDLP_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

test_home="$YTDLP_TEST_ROOT/home"
mock_bin="$YTDLP_TEST_ROOT/bin"
release_binary="$YTDLP_TEST_ROOT/release-yt-dlp"
mkdir -p "$test_home" "$mock_bin"

cat >"$release_binary" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
--version) printf '2026.09.01\n' ;;
*) exit 64 ;;
esac
EOF
chmod +x "$release_binary"

cat >"$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
output=''
write_url=0
url=''
while [[ $# -gt 0 ]]; do
  case "$1" in
  --output)
    output="$2"
    shift 2
    ;;
  --write-out)
    write_url=1
    shift 2
    ;;
  -* ) shift ;;
  *)
    url="$1"
    shift
    ;;
  esac
done

case "$url" in
*/releases/latest)
  [[ $write_url -eq 0 ]] ||
    printf 'https://github.com/yt-dlp/yt-dlp/releases/tag/2026.09.01'
  ;;
*/yt-dlp_linux)
  cp "$FAKE_YTDLP_RELEASE" "$output"
  ;;
*/SHA2-256SUMS)
  hash="$(sha256sum "$FAKE_YTDLP_RELEASE")"
  if [[ ${FAKE_BAD_CHECKSUM:-0} -eq 1 ]]; then
    hash='0000000000000000000000000000000000000000000000000000000000000000'
  fi
  printf '%s  yt-dlp_linux\n' "${hash%% *}" >"$output"
  ;;
*) exit 42 ;;
esac
EOF
chmod +x "$mock_bin/curl"

if HOME="$test_home" PATH="$mock_bin:$PATH" "$SUBJECT" status >/dev/null 2>&1; then
  fail 'an absent yt-dlp binary should leave the phase unsatisfied'
fi

mkdir -p "$test_home/.local/state/dotfiles"
printf 'release=partial\n' >"$test_home/.local/state/dotfiles/yt-dlp-release"
HOME="$test_home" PATH="$mock_bin:$PATH" "$SUBJECT" status >/dev/null 2>&1 &&
  fail 'a marker without a binary should leave the phase unsatisfied'
HOME="$test_home" PATH="$mock_bin:$PATH" "$SUBJECT" uninstall >/dev/null

if HOME="$test_home" PATH="$mock_bin:$PATH" FAKE_YTDLP_RELEASE="$release_binary" \
  FAKE_BAD_CHECKSUM=1 "$SUBJECT" install >/dev/null 2>&1; then
  fail 'a mismatched release checksum should fail installation'
fi
[[ ! -e "$test_home/.local/bin/yt-dlp" ]] ||
  fail 'a failed verification must not install the binary'
if compgen -G "$test_home/.local/bin/.yt-dlp.*" >/dev/null; then
  fail 'a failed installation should clean temporary files'
fi

HOME="$test_home" PATH="$mock_bin:$PATH" FAKE_YTDLP_RELEASE="$release_binary" \
  "$SUBJECT" install >/dev/null
HOME="$test_home" PATH="$mock_bin:$PATH" "$SUBJECT" status >/dev/null ||
  fail 'the verified release binary should satisfy the phase'
HOME="$test_home" PATH="$mock_bin:$PATH" FAKE_YTDLP_RELEASE="$release_binary" \
  FAKE_BAD_CHECKSUM=1 "$SUBJECT" install >/dev/null ||
  fail 'an already-satisfied phase should not attempt another download'

HOME="$test_home" PATH="$mock_bin:$PATH" "$SUBJECT" uninstall >/dev/null
[[ ! -e "$test_home/.local/bin/yt-dlp" ]] ||
  fail 'uninstall should remove the managed binary'
[[ ! -e "$test_home/.local/state/dotfiles/yt-dlp-release" ]] ||
  fail 'uninstall should remove the ownership marker'

printf 'bootstrap yt-dlp tests passed\n'
