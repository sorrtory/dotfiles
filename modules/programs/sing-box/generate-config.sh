#!/usr/bin/env bash

# Never trace configuration containing credentials, even under bash -x.
set +x
set -euo pipefail
umask 077

if [[ $# -lt 2 || $# -gt 3 ]]; then
  printf 'usage: sing-box-config PROFILE OUTPUT [INTERFACE]\n' >&2
  exit 64
fi

profile=$1
output=$2
# With INTERFACE, a whole-host tunnel owns the identity: sing-box only passes
# traffic to that interface, and fails closed while it is absent.
interface=${3-}
if [[ -n $interface && ! $interface =~ ^[A-Za-z0-9_=+.-]{1,15}$ ]]; then
  printf 'sing-box-config: invalid interface name\n' >&2
  exit 64
fi
temporary=$(mktemp "${output}.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT

# jq reads the profile itself: no key travels through argv or the environment.
# Suppress parser/checker diagnostics because they may quote secret input.
if ! jq -n --rawfile profile "$profile" --arg bind "$interface" '
  def trim: gsub("^\\s+|\\s+$"; "");
  def items: split(",") | map(trim) | select(length > 0 and all(. != ""));
  def key: select(test("^[A-Za-z0-9+/]{43}=$"));
  def required($v): if $v == null or $v == "" then error("missing field") else $v end;
  reduce ($profile | split("\n")[] | sub("#.*$"; "") | trim | select(. != "")) as $line
    ({section: null, Interface: {}, Peer: {}, seen: []};
      if ($line | test("^\\[.*\\]$")) then
        ($line | ltrimstr("[") | rtrimstr("]")) as $section |
        if (["Interface", "Peer"] | index($section)) == null or
           (.seen | index($section)) != null then error("unsupported section")
        else .section = $section | .seen += [$section] end
      else
        ($line | capture("^(?<name>[A-Za-z]+)\\s*=\\s*(?<value>.*)$")) as $entry |
        ($entry.value | trim) as $value |
        if .section == null or $value == "" then error("invalid field")
        elif .[.section][$entry.name] != null then error("duplicate field")
        elif (.section == "Interface" and
          (["Address", "PrivateKey", "DNS", "MTU", "ListenPort"] | index($entry.name)) != null) or
          (.section == "Peer" and
          (["Endpoint", "PublicKey", "PresharedKey", "AllowedIPs", "PersistentKeepalive"] | index($entry.name)) != null)
        then .[.section][$entry.name] = $value
        else error("unsupported field") end
      end) as $config |
  $config.Interface as $interface | $config.Peer as $peer |
  (required($interface.PrivateKey) | key) as $private |
  (required($peer.PublicKey) | key) as $public |
  (required($interface.Address) | items) as $addresses |
  (required($peer.AllowedIPs) | items) as $allowed |
  (required($peer.Endpoint) |
    capture("^(?:\\[(?<ipv6>[^]]+)\\]|(?<host>[^:]+)):(?<port>[0-9]+)$")) as $remote |
  ($remote.port | tonumber | select(. >= 1 and . <= 65535)) as $port |
  (($interface.MTU // "1420") | tonumber | select(. >= 1280 and . <= 65535)) as $mtu |
  (($interface.DNS // "1.1.1.1") | items) as $dns |
  (if $peer.PresharedKey then ($peer.PresharedKey | key) else null end) as $psk |
  {
    log: {level: "warn"},
    dns: {
      servers: ([{type: "local", tag: "bootstrap"}] +
        [$dns | to_entries[] | {
          type: "udp", tag: ("tunnel-dns-" + (.key | tostring)),
          server: .value, detour: "tunnel"
        }]),
      final: "tunnel-dns-0"
    }
  } + if $bind != "" then {
    outbounds: [{type: "direct", tag: "tunnel", bind_interface: $bind}]
  } else {
    endpoints: [{
      type: "wireguard", tag: "tunnel", system: false,
      address: $addresses, private_key: $private, mtu: $mtu,
      domain_resolver: "bootstrap",
      peers: [{
        address: ($remote.ipv6 // $remote.host), port: $port,
        public_key: $public, allowed_ips: $allowed,
        persistent_keepalive_interval: 25
      } + (if $psk then {pre_shared_key: $psk} else {} end)]
    }]
  } end + {
    inbounds: [
      {type: "mixed", tag: "mixed", listen: "127.0.0.1", listen_port: 1080},
      {type: "http", tag: "http", listen: "127.0.0.1", listen_port: 3128}
    ],
    route: {final: "tunnel", default_domain_resolver: "tunnel-dns-0"}
  }
' >"$temporary" 2>/dev/null || [[ ! -s "$temporary" ]]; then
  printf 'sing-box-config: invalid or unsupported WireGuard profile\n' >&2
  exit 1
fi

if ! sing-box check -c "$temporary" >/dev/null 2>&1; then
  printf 'sing-box-config: generated configuration failed validation\n' >&2
  exit 1
fi

mv -f -- "$temporary" "$output"
