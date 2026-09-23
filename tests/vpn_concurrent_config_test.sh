#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
cat > "$root/egresses" <<'JSON'
{"endpoints":[],"outbounds":[
  {"type":"socks","tag":"route-a","server":"127.0.0.1","server_port":15001},
  {"type":"socks","tag":"route-b","server":"127.0.0.1","server_port":15002}
],"dns":{"servers":[
  {"type":"udp","tag":"dns-a","server":"8.8.8.8","detour":"route-a"},
  {"type":"udp","tag":"dns-b","server":"1.1.1.1","detour":"route-b"}
]}}
JSON
printf '{"defaults":{"%s":"route-a"},"pins":{},"ipv6":{"route-a":false,"route-b":true}}\n' \
  "$(hostname)" > "$root/policy"
compile() {
  python3 "$repo/modules/programs/sing-box/compile-inventory.py" --concurrent \
    "$root/egresses" "$root/policy" "$root/config"
}
compile
jq -e '
  .route.final == "vpn-default-selector" and
  .outbounds[-1].type == "selector" and
  .outbounds[-1].default == "route-a" and
  .outbounds[-1].outbounds == ["route-a", "route-b"] and
  ([.inbounds[] | select(.tag | startswith("vpn-named-")) | .listen_port] | unique | length) == 2 and
  ([.inbounds[] | select(.tag | startswith("vpn-named-")) | .listen] | all(. == "127.0.0.1")) and
  any(.route.rules[]; .inbound == ["vpn-named-route-a"] and .outbound == "route-a") and
  any(.route.rules[]; .inbound == ["vpn-named-route-b"] and .outbound == "route-b") and
  any(.dns.rules[]; .inbound == ["vpn-named-route-a"] and .server == "dns-a") and
  any(.dns.rules[]; .inbound == ["vpn-named-route-b"] and .server == "dns-b") and
  any(.dns.rules[]; .inbound == ["mixed", "http"] and .query_type == ["AAAA"] and .action == "predefined") and
  .dns.servers[1].detour == "vpn-default-selector"
' "$root/config" >/dev/null || fail 'concurrent routing contract'
jq -c '[.inbounds[] | select(.tag | startswith("vpn-named-")) | {tag,listen_port}]' \
  "$root/config" > "$root/bindings"
jq '.outbounds |= reverse' "$root/egresses" > "$root/reordered"
mv "$root/reordered" "$root/egresses"
compile
jq -c '[.inbounds[] | select(.tag | startswith("vpn-named-")) | {tag,listen_port}]' \
  "$root/config" | cmp -s - "$root/bindings" || fail 'listener binding changed with inventory order'
mkdir "$root/capture" "$root/host"
bash "$repo/modules/programs/vpnized-apps/capture-config.sh" "$root/config" "$root/capture"
bash "$repo/modules/programs/vpnized-apps/whole-host-config.sh" "$root/config" "$root/host/config.json"
jq -e '.dns.strategy == "ipv4_only" and .dns.servers == [{"type":"udp","tag":"vpn-default-dns","server":"8.8.8.8","detour":"proxy"}]' \
  "$root/capture/config.json" >/dev/null || fail 'default capture DNS or IPv6'
jq -e '.dns.servers[0].server == "8.8.8.8"' "$root/host/config.json" >/dev/null ||
  fail 'whole-host resolver'
printf 'vpn concurrent compiler tests passed\n'
