#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ $# != 2 ]]; then
  echo 'usage: vpn-capture-config BACKEND_CONFIG RUNTIME_DIRECTORY' >&2
  exit 2
fi
backend=$1
runtime=$2
[[ $runtime = /* && -d $runtime && -O $runtime ]] || {
  echo 'vpn-capture-config: expected an owned absolute runtime directory' >&2
  exit 1
}
temporary=$(mktemp "$runtime/config.XXXXXXXX.json")
trap 'rm -f -- "$temporary"' EXIT

# Read the backend privately; deliberately copy only resolver addresses and
# whether IPv6 is on, never WireGuard endpoints or keys. The adapter has no
# independent tunnel identity. Without IPv6 the namespace gets no IPv6 address,
# so programs inside see no IPv6 route rather than one that goes nowhere.
jq -e --arg runtime "$runtime" '
  .route.final as $selected |
  [.dns.servers[] | select(.type == "udp" and .detour == $selected) |
    {type: "udp", tag: .tag, server: .server, detour: "proxy"}] as $dns |
  ($selected != "vpn-default-selector" and .dns.strategy != "ipv4_only") as $ipv6 |
  if ($dns | length) == 0 then error("missing tunnel resolver") else
  {
    log: {level: "warn"},
    network_namespaces: [{type: "unshare", tag: "apps",
      pid_file: ($runtime + "/namespace.pid")}],
    inbounds: [{type: "tun", tag: "apps-in", netns: "apps",
      interface_name: "vpn0",
      address: (["172.31.255.1/30"] + if $ipv6 then ["fd00:ffff::1/126"] else [] end),
      mtu: 1400, auto_route: true, strict_route: true,
      dns_mode: "disabled", stack: "gvisor"}],
    outbounds: [{type: "socks", tag: "proxy", server: "127.0.0.1",
      server_port: 1080, version: "5"}],
    dns: ({servers: $dns, final: $dns[0].tag} +
      if $ipv6 then {} else {strategy: "ipv4_only"} end),
    route: {rules: [{inbound: "apps-in", port: 53, action: "hijack-dns"}],
      final: "proxy"}
  } end
' "$backend" > "$temporary" 2>/dev/null || {
  echo 'vpn-capture-config: cannot read backend resolver configuration' >&2
  exit 1
}
if ! sing-box check -c "$temporary" >/dev/null 2>&1; then
  echo 'vpn-capture-config: generated configuration failed validation' >&2
  exit 1
fi
mv -f -- "$temporary" "$runtime/config.json"
