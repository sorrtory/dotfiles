#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ $# != 2 && $# != 3 ]]; then
  echo 'usage: vpn-capture-config BACKEND_CONFIG RUNTIME_DIRECTORY [EGRESS]' >&2
  exit 2
fi
backend=$1
runtime=$2
egress=
if [[ $# == 3 ]]; then
  encoded=$3
  [[ $encoded =~ ^([0-9a-f]{2})+$ ]] || {
    echo 'vpn-capture-config: invalid named route encoding' >&2
    exit 1
  }
  for ((index=0; index<${#encoded}; index+=2)); do
    printf -v char '%b' "\\x${encoded:index:2}"
    egress+=$char
  done
  [[ $egress =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
    echo 'vpn-capture-config: invalid named route' >&2
    exit 1
  }
fi
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
jq -e --arg runtime "$runtime" --arg egress "$egress" '
  (if $egress == "" then .route.final else $egress end) as $selected |
  (if $egress == "" then 1080 else
    [.inbounds[] | select(.tag == ("vpn-named-" + $egress)) | .listen_port][0]
   end) as $port |
  (if $egress == "" then false else
    any(.route.rules[]; .inbound == [("vpn-named-" + $egress)] and .ip_version == 6 and .action == "reject")
   end) as $reject_ipv6 |
  [.dns.servers[] | select(.type == "udp" and .detour == $selected) |
    {type: "udp", tag: .tag, server: .server, detour: "proxy"}] as $dns |
  (if $egress == "" then
    $selected != "vpn-default-selector" and .dns.strategy != "ipv4_only"
   else $reject_ipv6 | not end) as $ipv6 |
  if ($dns | length) == 0 or $port == null then error("missing named listener or tunnel resolver") else
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
      server_port: $port, version: "5"}],
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
