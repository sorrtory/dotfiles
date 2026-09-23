#!/usr/bin/env bash
# Build a credential-free whole-host TUN from the running backend's resolver.
set +x
set -euo pipefail
umask 077
[[ $# == 2 && $2 == /* ]] || { echo 'usage: vpn-host-config BACKEND OUTPUT' >&2; exit 2; }
backend=$1 output=$2
temporary=$(mktemp "${output}.XXXXXXXX")
trap 'rm -f -- "$temporary"' EXIT
jq -e '
  .route.final as $selected |
  [.dns.servers[] | select(.type == "udp" and .detour == $selected) | .server] as $dns |
  if ($dns | length) == 0 then error("missing tunnel resolver") else
  {
    log: {level: "warn"},
    inbounds: [{type: "tun", tag: "host-tun", interface_name: "vpn-host0",
      address: ["172.31.254.1/30"], mtu: 1400, auto_route: true,
      strict_route: false, dns_mode: "hijack", stack: "gvisor",
      route_exclude_address: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
        "169.254.0.0/16", "127.0.0.0/8", "::1/128", "fe80::/10", "fc00::/7"]}],
    outbounds: [{type: "socks", tag: "backend", server: "127.0.0.1",
      server_port: 1080, version: "5"}],
    dns: {servers: ($dns | to_entries | map({type: "udp",
      tag: ("via-backend-" + (.key | tostring)), server: .value, detour: "backend"})),
      final: "via-backend-0", strategy: "ipv4_only"},
    route: {rules: [{inbound: "host-tun", port: 53, action: "hijack-dns"},
      {ip_version: 6, action: "reject"}], final: "backend"}
  } end
' "$backend" > "$temporary" 2>/dev/null || {
  echo 'vpn-host-config: backend resolver unavailable' >&2; exit 1;
}
if ! sing-box check -c "$temporary" >/dev/null 2>&1; then
  echo 'vpn-host-config: generated configuration failed validation' >&2
  exit 1
fi
mv -f -- "$temporary" "$output"
