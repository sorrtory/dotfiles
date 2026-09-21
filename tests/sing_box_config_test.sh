#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v sing-box >/dev/null || fail 'sing-box must be on PATH'
command -v jq >/dev/null || fail 'jq must be on PATH'

# Generated for this test only; never use these identities on a real server.
private=$(head -c 32 /dev/urandom | base64)
public=$(head -c 32 /dev/urandom | base64)
psk=$(head -c 32 /dev/urandom | base64)
cat >"$TEST_ROOT/profile.conf" <<EOF
# Test wg-quick profile, including optional fields and inline comments.
[Interface]
PrivateKey = $private
Address = 10.0.0.2/32, fd00::2/128
DNS = 1.1.1.1, 2606:4700:4700::1111
MTU = 1380
ListenPort = 51820
[Peer]
PublicKey = $public
PresharedKey = $psk
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = [2001:db8::1]:51820 # documentation address
PersistentKeepalive = 10
EOF

generate() {
  bash "$REPO_ROOT/modules/programs/sing-box/generate-config.sh" \
    "$TEST_ROOT/profile.conf" "$TEST_ROOT/config.json"
}

generate
[[ $(stat -c %a "$TEST_ROOT/config.json") == 600 ]] || fail 'config must be private'
jq -e '
  .endpoints[0].system == false and
  .endpoints[0].mtu == 1380 and
  .endpoints[0].address == ["10.0.0.2/32", "fd00::2/128"] and
  .endpoints[0].peers[0].address == "2001:db8::1" and
  .endpoints[0].peers[0].port == 51820 and
  .endpoints[0].peers[0].persistent_keepalive_interval == 25 and
  .dns.final == "tunnel-dns-0" and
  ([.dns.servers[] | select(.tag != "bootstrap") | .detour] == ["tunnel", "tunnel"]) and
  .route.final == "tunnel" and
  .route.default_domain_resolver == "tunnel-dns-0" and
  [.inbounds[].listen_port] == [1080, 3128] and
  all(.inbounds[]; .listen == "127.0.0.1") and
  all(.outbounds[]?; .type != "direct")
' "$TEST_ROOT/config.json" >/dev/null || fail 'routing/configuration contract'
[[ $(jq -r '.endpoints[0].private_key' "$TEST_ROOT/config.json") == "$private" ]] || fail 'private key mapping'
[[ $(jq -r '.endpoints[0].peers[0].pre_shared_key' "$TEST_ROOT/config.json") == "$psk" ]] || fail 'preshared key mapping'

cp "$TEST_ROOT/profile.conf" "$TEST_ROOT/valid.conf"
sed -i '/^DNS /d; /^MTU /d; /^PresharedKey /d; s/\[2001:db8::1\]/vpn.example.org/' "$TEST_ROOT/profile.conf"
generate
jq -e '.endpoints[0].mtu == 1420 and .dns.servers[1].server == "1.1.1.1" and
  .endpoints[0].domain_resolver == "bootstrap" and
  .endpoints[0].peers[0].address == "vpn.example.org" and
  (.endpoints[0].peers[0] | has("pre_shared_key") | not)' \
  "$TEST_ROOT/config.json" >/dev/null || fail 'defaults and hostname bootstrap'

expect_rejected() {
  if generate >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"; then
    fail 'unsafe profile accepted'
  fi
  [[ ! -s "$TEST_ROOT/stdout" ]] || fail 'generator wrote to stdout'
  if grep -F -e "$private" -e "$psk" "$TEST_ROOT/stderr" >/dev/null; then
    fail 'credentials in diagnostic output'
  fi
  cmp -s "$TEST_ROOT/config.json" "$TEST_ROOT/last-good.json" || fail 'failed generation replaced working config'
  [[ $(find "$TEST_ROOT" -name 'config.json.*' | wc -l) == 0 ]] || fail 'temporary config leaked'
}
cp "$TEST_ROOT/config.json" "$TEST_ROOT/last-good.json"
for invalid in duplicate unknown_section hook bad_key bad_port missing_key second_peer malformed bad_address; do
  cp "$TEST_ROOT/valid.conf" "$TEST_ROOT/profile.conf"
  case "$invalid" in
    duplicate) printf 'PublicKey = %s\n' "$public" >>"$TEST_ROOT/profile.conf" ;;
    unknown_section) printf '[Secret%s]\n' "$private" >>"$TEST_ROOT/profile.conf" ;;
    hook) printf 'PostUp = touch SHOULD_NOT_EXIST\n' >>"$TEST_ROOT/profile.conf" ;;
    bad_key) sed -i 's/^PrivateKey = /PrivateKey = invalid/' "$TEST_ROOT/profile.conf" ;;
    bad_port) sed -i 's/:51820/:99999/' "$TEST_ROOT/profile.conf" ;;
    missing_key) sed -i '/^PrivateKey /d' "$TEST_ROOT/profile.conf" ;;
    second_peer) printf '[Peer]\n' >>"$TEST_ROOT/profile.conf" ;;
    malformed) printf 'not a configuration line\n' >>"$TEST_ROOT/profile.conf" ;;
    bad_address) sed -i 's#10.0.0.2/32#invalid-address#' "$TEST_ROOT/profile.conf" ;;
  esac
  expect_rejected
done

# While a whole-host tunnel owns the identity, the backend carries no key and
# reaches the network only through that interface, resolvers included.
cp "$TEST_ROOT/valid.conf" "$TEST_ROOT/profile.conf"
bash "$REPO_ROOT/modules/programs/sing-box/generate-config.sh" \
  "$TEST_ROOT/profile.conf" "$TEST_ROOT/config.json" laptop
jq -e '
  (has("endpoints") | not) and
  .outbounds == [{type: "direct", tag: "tunnel", bind_interface: "laptop"}] and
  ([.dns.servers[] | select(.tag != "bootstrap") | .detour] == ["tunnel", "tunnel"]) and
  .route.final == "tunnel" and
  [.inbounds[].listen_port] == [1080, 3128]
' "$TEST_ROOT/config.json" >/dev/null || fail 'passthrough contract'
if grep -F -e "$private" -e "$psk" "$TEST_ROOT/config.json" >/dev/null; then
  fail 'passthrough config carries credentials'
fi
cp "$TEST_ROOT/config.json" "$TEST_ROOT/last-good.json"
if bash "$REPO_ROOT/modules/programs/sing-box/generate-config.sh" \
  "$TEST_ROOT/profile.conf" "$TEST_ROOT/config.json" 'bad name' 2>/dev/null; then
  fail 'invalid interface name accepted'
fi
cmp -s "$TEST_ROOT/config.json" "$TEST_ROOT/last-good.json" || fail 'invalid interface replaced working config'
printf 'sing-box config tests passed\n'
