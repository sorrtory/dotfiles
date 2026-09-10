#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
SECRET_SCAN_TEST_ROOT="$(mktemp -d)"
readonly SECRET_SCAN_TEST_ROOT
PRIVATE_AGE_IDENTITY="AGE-SECRET-KEY-1$(printf 'Q%.0s' {1..58})"
readonly PRIVATE_AGE_IDENTITY
WIREGUARD_PRIVATE_KEY="$(printf 'A%.0s' {1..43})="
readonly WIREGUARD_PRIVATE_KEY
GITHUB_TOKEN="ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ$(printf '%s' 0123456789)"
readonly GITHUB_TOKEN
# Shaped like real whole-file SOPS output: an encrypted payload plus a sops
# metadata block naming the encryption method and the age recipient.
SOPS_CIPHERTEXT="$(
  cat <<'FIXTURE'
{
	"data": "ENC[AES256_GCM,data:Tr7oAQ==,iv:aXY=,tag:dGFn,type:str]",
	"sops": {
		"age": [
			{
				"recipient": "age1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
				"enc": "-----BEGIN AGE ENCRYPTED FILE-----\nYWdlLWVuY3J5cHRpb24ub3JnL3Yx\n-----END AGE ENCRYPTED FILE-----\n"
			}
		],
		"lastmodified": "2026-09-10T00:00:00Z",
		"mac": "ENC[AES256_GCM,data:bWFj,iv:aXY=,tag:dGFn,type:str]",
		"unencrypted_suffix": "_unencrypted",
		"version": "3.10.2"
	}
}
FIXTURE
)"
readonly SOPS_CIPHERTEXT
trap 'rm -rf -- "$SECRET_SCAN_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

new_repo() {
  local test_repo

  test_repo="$(mktemp -d "$SECRET_SCAN_TEST_ROOT/repo.XXXXXX")"
  mkdir -p \
    "$test_repo/.githooks" \
    "$test_repo/scripts/bootstrap/common" \
    "$test_repo/scripts/repo"
  cp "$REPO_ROOT/.githooks/pre-commit" "$test_repo/.githooks/pre-commit"
  cp "$REPO_ROOT/flake.lock" "$REPO_ROOT/flake.nix" "$REPO_ROOT/home.nix" "$test_repo/"
  cp "$REPO_ROOT/scripts/repo/check-secrets.sh" "$test_repo/scripts/repo/check-secrets.sh"
  cp "$REPO_ROOT/scripts/repo/check-bootstrap-phases.sh" "$test_repo/scripts/repo/check-bootstrap-phases.sh"
  cp "$REPO_ROOT/scripts/bootstrap/common/"*.sh \
    "$test_repo/scripts/bootstrap/common/"
  cp "$REPO_ROOT/.gitleaks.toml" "$test_repo/.gitleaks.toml"
  git -C "$test_repo" init --quiet
  git -C "$test_repo" config user.email test@example.invalid
  git -C "$test_repo" config user.name 'Secret scan test'
  git -C "$test_repo" add .githooks .gitleaks.toml flake.lock flake.nix home.nix scripts
  git -C "$test_repo" commit --quiet --message 'fixture repository'
  printf '%s\n' "$test_repo"
}

assert_scan_result() {
  local expectation="$1"
  local description="$2"
  local content="$3"
  local candidate="${4:-candidate}"
  local scan_output
  local scan_status
  local test_repo

  test_repo="$(new_repo)"
  scan_output="$test_repo/scan-output"
  mkdir -p -- "$(dirname -- "$test_repo/$candidate")"
  printf '%s\n' "$content" >"$test_repo/$candidate"
  git -C "$test_repo" add -- "$candidate"

  if "$test_repo/scripts/repo/check-secrets.sh" --staged >"$scan_output" 2>&1; then
    scan_status=0
  else
    scan_status=$?
  fi

  case "$expectation:$scan_status" in
  allowed:0 | rejected:1) ;;
  *)
    cat -- "$scan_output" >&2
    fail "$description should be $expectation (scanner exited $scan_status)"
    ;;
  esac
}

assert_hook_behavior() {
  local test_repo

  test_repo="$(new_repo)"
  git -C "$test_repo" config core.hooksPath .githooks
  printf 'safe\n' >"$test_repo/candidate"
  git -C "$test_repo" add candidate
  if ! git -C "$test_repo" commit --quiet --message 'safe test data' >/dev/null 2>&1; then
    fail 'pre-commit hook should allow safe staged content'
  fi

  printf '%s\n' "$PRIVATE_AGE_IDENTITY" >"$test_repo/candidate"
  git -C "$test_repo" add candidate

  if git -C "$test_repo" commit --quiet --message 'test secret' >/dev/null 2>&1; then
    fail 'pre-commit hook should reject a staged secret'
  fi
}

assert_scan_result \
  allowed \
  'SOPS ciphertext' \
  'password: ENC[AES256_GCM,data:c29tZS1jaXBoZXJ0ZXh0,iv:aXY=,tag:dGFn,type:str]'

assert_scan_result \
  allowed \
  'public age recipient' \
  "age1$(printf 'q%.0s' {1..58})"

assert_scan_result \
  rejected \
  'private age identity' \
  "$PRIVATE_AGE_IDENTITY"

assert_scan_result \
  rejected \
  'plaintext WireGuard private key' \
  "PrivateKey = $WIREGUARD_PRIVATE_KEY"

assert_scan_result \
  rejected \
  'default gitleaks GitHub token' \
  "$GITHUB_TOKEN"

# The secrets/ invariant: ciphertext only, recognized by structure.

assert_scan_result \
  rejected \
  'plaintext under secrets/ matching no gitleaks rule' \
  'Endpoint = vpn.example.invalid:51820' \
  'secrets/wireguard/wg0.conf'

assert_scan_result \
  allowed \
  'SOPS ciphertext under secrets/' \
  "$SOPS_CIPHERTEXT" \
  'secrets/wireguard/wg0.conf'

assert_scan_result \
  rejected \
  'file under secrets/ that merely mentions sops' \
  '# encrypted with sops, honest' \
  'secrets/wireguard/wg0.conf'

# Regression: marker substrings are not proof of encryption. A plaintext file
# can simply carry them in comments, so recognition must come from SOPS itself.
assert_scan_result \
  rejected \
  'plaintext under secrets/ decorated with both SOPS markers' \
  'Endpoint = vpn.example.invalid:51820
# ENC[AES256_GCM,fake]
# -----BEGIN AGE ENCRYPTED FILE-----' \
  'secrets/wireguard/wg0.conf'

assert_scan_result \
  allowed \
  'the same plaintext outside secrets/' \
  'Endpoint = vpn.example.invalid:51820' \
  'docs/example-endpoint.txt'

assert_scan_result \
  allowed \
  'placeholder keeping secrets/ present' \
  '' \
  'secrets/.gitkeep'

assert_scan_result \
  allowed \
  'non-sensitive metadata under secrets/' \
  'This directory holds SOPS ciphertext only.' \
  'secrets/README.md'

assert_hook_behavior

printf 'secret scan tests passed\n'
