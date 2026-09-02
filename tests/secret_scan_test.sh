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
trap 'rm -rf -- "$SECRET_SCAN_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

new_repo() {
  local test_repo

  test_repo="$(mktemp -d "$SECRET_SCAN_TEST_ROOT/repo.XXXXXX")"
  mkdir -p "$test_repo/.githooks" "$test_repo/scripts"
  cp "$REPO_ROOT/.githooks/pre-commit" "$test_repo/.githooks/pre-commit"
  cp "$REPO_ROOT/scripts/check-secrets" "$test_repo/scripts/check-secrets"
  cp "$REPO_ROOT/.gitleaks.toml" "$test_repo/.gitleaks.toml"
  git -C "$test_repo" init --quiet
  git -C "$test_repo" config user.email test@example.invalid
  git -C "$test_repo" config user.name 'Secret scan test'
  printf '%s\n' "$test_repo"
}

assert_rejected() {
  local description="$1"
  local content="$2"
  local test_repo

  test_repo="$(new_repo)"
  printf '%s\n' "$content" >"$test_repo/candidate"
  git -C "$test_repo" add candidate

  if "$test_repo/scripts/check-secrets" --staged >/dev/null 2>&1; then
    fail "$description should be rejected"
  fi
}

assert_allowed() {
  local description="$1"
  local content="$2"
  local test_repo

  test_repo="$(new_repo)"
  printf '%s\n' "$content" >"$test_repo/candidate"
  git -C "$test_repo" add candidate

  if ! "$test_repo/scripts/check-secrets" --staged >/dev/null 2>&1; then
    fail "$description should be allowed"
  fi
}

assert_hook_rejects_secret() {
  local test_repo

  test_repo="$(new_repo)"
  git -C "$test_repo" config core.hooksPath .githooks
  printf '%s\n' "$PRIVATE_AGE_IDENTITY" >"$test_repo/candidate"
  git -C "$test_repo" add candidate

  if git -C "$test_repo" commit --quiet --message 'test secret' >/dev/null 2>&1; then
    fail 'pre-commit hook should reject a staged secret'
  fi
}

assert_rejected \
  'private age identity' \
  "$PRIVATE_AGE_IDENTITY"

assert_rejected \
  'plaintext WireGuard private key' \
  "PrivateKey = $WIREGUARD_PRIVATE_KEY"

assert_allowed \
  'SOPS ciphertext' \
  'password: ENC[AES256_GCM,data:c29tZS1jaXBoZXJ0ZXh0,iv:aXY=,tag:dGFn,type:str]'

assert_hook_rejects_secret

printf 'secret scan tests passed\n'
