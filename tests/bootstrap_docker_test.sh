#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SUBJECT="$REPO_ROOT/scripts/bootstrap/07-docker.sh"
DOCKER_TEST_ROOT="$(mktemp -d)"
readonly DOCKER_TEST_ROOT
trap 'rm -rf -- "$DOCKER_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mock_bin="$DOCKER_TEST_ROOT/bin"
state_dir="$DOCKER_TEST_ROOT/state"
mkdir -p "$mock_bin" "$state_dir"

cat >"$mock_bin/id" <<'EOF'
#!/usr/bin/env bash
case "$1" in
-un) printf 'test-user\n' ;;
-nG)
  printf 'test-user'
  [[ ! -e "$FAKE_DOCKER_STATE/group" ]] || printf ' docker'
  printf '\n'
  ;;
*) exit 64 ;;
esac
EOF

cat >"$mock_bin/docker" <<'EOF'
#!/usr/bin/env bash
[[ -e "$FAKE_DOCKER_STATE/engine" ]] || exit 127
case "${1:-}" in
--version) printf 'Docker version 28.4.0, build test\n' ;;
compose) [[ ${2:-} == version ]] ;;
buildx) [[ ${2:-} == version ]] ;;
*) exit 64 ;;
esac
EOF

cat >"$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
[[ ${FAIL_ON_CURL:-0} -eq 0 ]] || exit 99
output=''
while [[ $# -gt 0 ]]; do
  case "$1" in
  --output) output="$2"; shift 2 ;;
  -*) shift ;;
  *) shift ;;
  esac
done
cp "$FAKE_DOCKER_INSTALLER" "$output"
EOF

cat >"$mock_bin/sudo" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
-v) exit 0 ;;
usermod)
  [[ "$*" == 'usermod -aG docker test-user' ]] || exit 64
  touch "$FAKE_DOCKER_STATE/group"
  ;;
gpasswd)
  [[ "$*" == 'gpasswd -d test-user docker' ]] || exit 64
  rm -f "$FAKE_DOCKER_STATE/group"
  ;;
apt-get)
  [[ ${2:-} == purge ]] || exit 64
  rm -f "$FAKE_DOCKER_STATE/engine"
  ;;
rm)
  case "$*" in
  *'/var/lib/docker'*) rm -f "$FAKE_DOCKER_STATE/data" ;;
  *) rm -f "$FAKE_DOCKER_STATE/repository" ;;
  esac
  ;;
*) "$@" ;;
esac
EOF

cat >"$mock_bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
[[ -e "$FAKE_DOCKER_STATE/engine" ]] || exit 1
printf 'ii '
EOF

cat >"$mock_bin/stat" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
/var/lib/docker | /var/lib/containerd)
  [[ -e "$FAKE_DOCKER_STATE/data" ]]
  ;;
/etc/apt/keyrings/docker.asc | /etc/apt/keyrings/docker.gpg | \
/etc/apt/sources.list.d/docker.list | /etc/apt/sources.list.d/docker.sources | \
/etc/yum.repos.d/docker-ce.repo)
  [[ -e "$FAKE_DOCKER_STATE/repository" ]]
  ;;
*) exit 1 ;;
esac
EOF

cat >"$DOCKER_TEST_ROOT/installer.sh" <<'EOF'
#!/usr/bin/env sh
if [ "${1:-}" = '--dry-run' ]; then
  exit 0
fi
touch "$FAKE_DOCKER_STATE/engine" "$FAKE_DOCKER_STATE/data" \
  "$FAKE_DOCKER_STATE/repository"
EOF
chmod +x "$mock_bin/id" "$mock_bin/docker" "$mock_bin/curl" \
  "$mock_bin/sudo" "$mock_bin/dpkg-query" "$mock_bin/stat" \
  "$DOCKER_TEST_ROOT/installer.sh"

run_phase() {
  HOME="$DOCKER_TEST_ROOT/home" PATH="$mock_bin:$PATH" \
    FAKE_DOCKER_STATE="$state_dir" \
    FAKE_DOCKER_INSTALLER="$DOCKER_TEST_ROOT/installer.sh" \
    "$SUBJECT" "$@"
}

run_phase status >/dev/null 2>&1 &&
  fail 'an absent Docker installation should leave the phase unsatisfied'

touch "$state_dir/engine"
run_phase status >/dev/null 2>&1 &&
  fail 'Docker without group membership should leave the phase unsatisfied'
FAIL_ON_CURL=1 run_phase install >/dev/null
[[ -e "$state_dir/group" ]] ||
  fail 'partial installation should add the target user to the docker group'

run_phase status >/dev/null ||
  fail 'Docker components and group membership should satisfy the phase'
FAIL_ON_CURL=1 run_phase install >/dev/null ||
  fail 'an already-satisfied phase should not download the installer'

rm -f "$state_dir/engine" "$state_dir/group"
run_phase install >/dev/null
[[ -e "$state_dir/engine" && -e "$state_dir/group" ]] ||
  fail 'installation should establish Docker and group membership'

rm -f "$state_dir/group"
FAIL_ON_CURL=1 run_phase install >/dev/null
[[ -e "$state_dir/group" ]] ||
  fail 'repair should restore group membership without reinstalling'

run_phase uninstall >/dev/null
[[ ! -e "$state_dir/engine" && ! -e "$state_dir/group" ]] ||
  fail 'uninstall should remove Docker packages and group membership'
[[ ! -e "$state_dir/data" && ! -e "$state_dir/repository" ]] ||
  fail 'uninstall should remove Docker data and repository configuration'

if run_phase uninstall >/dev/null 2>&1; then
  fail 'uninstall should refuse when no recognized Docker state remains'
fi

printf 'bootstrap Docker tests passed\n'
