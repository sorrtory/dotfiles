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
  {"type":"udp","tag":"dns-b","server":"8.8.8.8","detour":"route-b"}
]}}
JSON
printf '{"defaults":{"%s":"route-a"},"pins":{},"ipv6":{"route-a":false,"route-b":true}}\n' \
  "$(hostname)" > "$root/policy"
compile() {
  python3 "$repo/modules/programs/sing-box/compile-inventory.py" --concurrent \
    --bindings "$root/listeners.json" \
    "$root/egresses" "$root/policy" "$root/config"
}
compile
jq -e '
  .route.final == "vpn-default-selector" and
  .outbounds[-1].type == "selector" and
  .outbounds[-1].default == "route-a" and
  (.dns | has("strategy") | not) and
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
cp "$root/egresses" "$root/valid-egresses"
jq '(.dns.servers[] | select(.tag == "dns-b") | .server) = "1.1.1.1"' \
  "$root/egresses" > "$root/different-dns"
mv "$root/different-dns" "$root/egresses"
if compile >"$root/stdout" 2>"$root/stderr"; then
  fail 'different default DNS addresses accepted'
fi
grep -q 'shared primary DNS server' "$root/stderr" || fail 'missing DNS rejection'
cp "$root/valid-egresses" "$root/egresses"
jq '(.outbounds[] | select(.tag == "route-a") | .server) = "example.invalid"' \
  "$root/egresses" > "$root/hostname-server"
mv "$root/hostname-server" "$root/egresses"
if compile >"$root/stdout" 2>"$root/stderr"; then
  fail 'hostname server accepted without physical-route bootstrap'
fi
grep -q 'physical-route bootstrap' "$root/stderr" || fail 'missing hostname rejection'
cp "$root/valid-egresses" "$root/egresses"

# A removed listener keeps its port reservation for this login session.
read -r old_tag new_tag < <(python3 - "$repo" <<'PY'
import runpy, sys
port = runpy.run_path(sys.argv[1] + "/modules/programs/sing-box/compile-inventory.py")["named_port"]
reserved = {port("route-a"), port("route-b")}
seen = {}
for index in range(1000):
    tag = f"collision-{index}"
    number = port(tag)
    if number in reserved:
        continue
    if number in seen:
        print(seen[number], tag)
        break
    seen[number] = tag
else:
    raise SystemExit("no synthetic port collision found")
PY
)
cat > "$root/egresses" <<EOF2
{"endpoints":[],"outbounds":[{"type":"socks","tag":"$old_tag","server":"127.0.0.1","server_port":15001}],"dns":{"servers":[{"type":"udp","tag":"collision-dns","server":"8.8.8.8","detour":"$old_tag"}]}}
EOF2
printf '{"defaults":{"%s":"%s"},"pins":{},"ipv6":{"%s":false}}\n' \
  "$(hostname)" "$old_tag" "$old_tag" > "$root/policy"
compile
sed -i "s/$old_tag/$new_tag/g" "$root/egresses" "$root/policy"
if compile >"$root/stdout" 2>"$root/stderr"; then
  fail 'removed route port was silently reassigned'
fi
grep -q 'reserved by another route' "$root/stderr" || fail 'missing port reservation rejection'

# The shared VLESS-like route may run on both machines; each WireGuard peer
# belongs only to the hostname that declares it as its default.
private=$(printf '0%.0s' {1..32} | base64)
public=$(printf '1%.0s' {1..32} | base64)
cat > "$root/egresses" <<EOF2
{"endpoints":[
  {"type":"wireguard","tag":"host-wireguard","system":false,"address":["10.0.0.2/32"],"private_key":"$private","peers":[{"address":"203.0.113.1","port":51820,"public_key":"$public","allowed_ips":["0.0.0.0/0"]}]},
  {"type":"wireguard","tag":"vm-wireguard","system":false,"address":["10.0.0.3/32"],"private_key":"$private","peers":[{"address":"203.0.113.2","port":51820,"public_key":"$public","allowed_ips":["0.0.0.0/0"]}]}
],"outbounds":[{"type":"socks","tag":"shared-route","server":"127.0.0.1","server_port":15003}],"dns":{"servers":[
  {"type":"udp","tag":"host-dns","server":"8.8.8.8","detour":"host-wireguard"},
  {"type":"udp","tag":"vm-dns","server":"8.8.8.8","detour":"vm-wireguard"},
  {"type":"udp","tag":"shared-dns","server":"8.8.8.8","detour":"shared-route"}
]}}
EOF2
printf '{"defaults":{"%s":"host-wireguard","other-host":"vm-wireguard"},"wireguard_owners":{"host-wireguard":"%s","vm-wireguard":"other-host"},"pins":{},"ipv6":{"host-wireguard":false,"vm-wireguard":false,"shared-route":false}}\n' \
  "$(hostname)" \
  "$(hostname)" > "$root/policy"
compile
jq -e '
  [.endpoints[].tag] == ["host-wireguard"] and
  [.outbounds[].tag] == ["shared-route", "vpn-default-selector"] and
  .dns.strategy == "ipv4_only" and
  (.inbounds | all(.tag != "vpn-named-vm-wireguard")) and
  (.dns.servers | all(.detour != "vm-wireguard"))
' "$root/config" >/dev/null || fail 'exclusive peer entered concurrent backend'
jq '.defaults["'"$(hostname)"'"] = "shared-route"' "$root/policy" > "$root/vless-default"
mv "$root/vless-default" "$root/policy"
compile
jq -e '.outbounds[-1].default == "shared-route" and [.endpoints[].tag] == ["host-wireguard"]' \
  "$root/config" >/dev/null || fail 'declarative default changed WireGuard ownership'
jq 'del(.wireguard_owners."vm-wireguard")' "$root/policy" > "$root/missing-owner"
mv "$root/missing-owner" "$root/policy"
if compile >"$root/stdout" 2>"$root/stderr"; then
  fail 'unowned WireGuard peer accepted'
fi
printf 'vpn concurrent compiler tests passed\n'
