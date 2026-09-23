#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
private=$(printf "0%.0s" {1..32} | base64)
public=$(printf "1%.0s" {1..32} | base64)
hostname=$(hostname)
cat > "$root/egresses.jsonc" <<EOF2
{
  // Safe note: synthetic WireGuard peer for compiler verification.
  "endpoints": [{
    "type": "wireguard", "tag": "fixture-main-wireguard-a",
    "system": false, "address": ["10.0.0.2/32"],
    "private_key": "$private", "mtu": 1420,
    "peers": [{"address": "203.0.113.1", "port": 51820,
      "public_key": "$public", "allowed_ips": ["0.0.0.0/0"]}]
  }],
  "outbounds": [],
  "dns": {"servers": [
    {"type":"udp", "tag":"fixture-dns-0", "server":"1.1.1.1", "detour":"fixture-main-wireguard-a"},
    {"type":"udp", "tag":"fixture-dns-1", "server":"9.9.9.9", "detour":"fixture-main-wireguard-a"}
  ]}
}
EOF2
cat > "$root/policy.jsonc" <<EOF2
{
  // The default is restored whenever the backend starts.
  "defaults": {"$hostname": "fixture-main-wireguard-a"},
  "pins": {},
  "ipv6": {"fixture-main-wireguard-a": false}
}
EOF2
compile() {
  python3 "$repo/modules/programs/sing-box/compile-inventory.py" \
    "$root/egresses.jsonc" "$root/policy.jsonc" "$root/config.json"
}
compile
[[ $(stat -c %a "$root/config.json") == 600 ]] || fail 'generated config is not private'
jq -e '.endpoints[0].tag == "fixture-main-wireguard-a" and
  .route.final == "fixture-main-wireguard-a" and
  .route.auto_detect_interface == true and
  .dns.strategy == "ipv4_only" and
  .dns.servers[1].detour == "fixture-main-wireguard-a" and
  .dns.servers[2].server == "9.9.9.9" and
  [.inbounds[].listen_port] == [1080,3128] and
  all(.outbounds[]?; .type != "direct")' "$root/config.json" >/dev/null ||
  fail 'compiled routing contract'
[[ $(jq -r '.endpoints[0].private_key' "$root/config.json") == "$private" ]] ||
  fail 'credential not passed to sing-box config'
mkdir "$root/host-runtime"
bash "$repo/modules/programs/vpnized-apps/whole-host-config.sh" \
  "$root/config.json" "$root/host-runtime/config.json"
jq -e '.dns.servers[0].server == "1.1.1.1" and
  .dns.servers[1].server == "9.9.9.9" and
  .route.final == "backend"' "$root/host-runtime/config.json" >/dev/null ||
  fail 'whole-host TUN did not follow the selected route resolvers'
! grep -F "$private" "$root/host-runtime/config.json" >/dev/null ||
  fail 'whole-host TUN received a provider credential'
cp "$root/config.json" "$root/last-good.json"
rejected() {
  if compile >"$root/stdout" 2>"$root/stderr"; then fail 'invalid policy accepted'; fi
  [[ ! -s $root/stdout ]] || fail 'compiler wrote secret-bearing stdout'
  ! grep -F -e "$private" -e "$public" "$root/stderr" >/dev/null || fail 'secret in diagnostic'
  cmp -s "$root/config.json" "$root/last-good.json" || fail 'failed compile replaced config'
}
cp "$root/policy.jsonc" "$root/valid-policy"
cp "$root/egresses.jsonc" "$root/valid-egresses"
sed -i 's/fixture-main-wireguard-a/unknown-route/' "$root/policy.jsonc"
rejected
cp "$root/valid-policy" "$root/policy.jsonc"
sed -i "s/\"$hostname\"/\"other-host\"/" "$root/policy.jsonc"
rejected
cp "$root/valid-policy" "$root/policy.jsonc"
sed -i 's/"pins": {}/"pins": {"vesktop": "unknown-route"}/' "$root/policy.jsonc"
rejected
cp "$root/valid-policy" "$root/policy.jsonc"
sed -i 's/"outbounds": \[\]/"outbounds": [{"type":"block","tag":"fixture-main-wireguard-a"}]/' "$root/egresses.jsonc"
rejected
cp "$root/valid-egresses" "$root/egresses.jsonc"
sed -i 's/"outbounds": \[\]/"outbounds": [{"type":"wireguard","tag":"invalid-unused"}]/' "$root/egresses.jsonc"
sed -i 's/"fixture-main-wireguard-a": false/"fixture-main-wireguard-a": false, "invalid-unused": false/' "$root/policy.jsonc"
rejected
cp "$root/valid-policy" "$root/policy.jsonc"
cp "$root/valid-egresses" "$root/egresses.jsonc"
printf '\n// Comments survive encrypted whole-file editing.\n' >> "$root/egresses.jsonc"
compile
printf 'vpn inventory compiler tests passed\n'
