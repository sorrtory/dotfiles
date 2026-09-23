#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
subject="$repo/modules/programs/vpnized-apps/capture-config.sh"
printf '%s\n' '{"endpoints":[{"private_key":"DO-NOT-COPY"}],"route":{"final":"tunnel"},"dns":{"servers":[{"type":"local","tag":"bootstrap"},{"type":"udp","tag":"tunnel-dns-0","server":"1.1.1.1","detour":"tunnel"}]}}' > "$test_root/backend.json"
bash "$subject" "$test_root/backend.json" "$test_root"
[[ $(stat -c %a "$test_root/config.json") == 600 ]] || fail 'config permissions'
jq -e --arg runtime "$test_root" '
  .network_namespaces[0].pid_file == ($runtime + "/namespace.pid") and
  .inbounds[0].netns == "apps" and .inbounds[0].strict_route and
  .inbounds[0].dns_mode == "disabled" and
  .outbounds == [{type:"socks",tag:"proxy",server:"127.0.0.1",server_port:1080,version:"5"}] and
  .dns.servers == [{type:"udp",tag:"tunnel-dns-0",server:"1.1.1.1",detour:"proxy"}] and
  .route.final == "proxy" and .route.rules[0].action == "hijack-dns" and
  (has("endpoints") | not)
' "$test_root/config.json" >/dev/null || fail 'capture boundary'
if rg -q 'DO-NOT-COPY' "$test_root/config.json"; then fail 'copied backend key'; fi
jq -e '.inbounds[0].address == ["172.31.255.1/30", "fd00:ffff::1/126"] and
  (.dns | has("strategy") | not)' "$test_root/config.json" >/dev/null || fail 'IPv6 namespace'
# A backend without IPv6 gives the namespace no IPv6 address or answers.
jq '.dns.strategy = "ipv4_only"' "$test_root/backend.json" > "$test_root/backend4.json"
bash "$subject" "$test_root/backend4.json" "$test_root"
jq -e '.inbounds[0].address == ["172.31.255.1/30"] and .dns.strategy == "ipv4_only"' \
  "$test_root/config.json" >/dev/null || fail 'IPv4-only namespace'
before=$(sha256sum "$test_root/config.json")
printf '{}\n' > "$test_root/backend.json"
if bash "$subject" "$test_root/backend.json" "$test_root" 2>/dev/null; then
  fail 'accepted missing DNS'
fi
[[ $(sha256sum "$test_root/config.json") == "$before" ]] || fail 'invalid input replaced config'
echo 'PASS: capture configuration and secret boundary'
