#!/usr/bin/env python3
"""Compile encrypted-at-rest native egresses into a private backend config."""

import ipaddress
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile


class InvalidConfig(Exception):
    pass


def jsonc(text):
    """Remove comments without changing quoted URLs or escape sequences."""
    out = []
    quoted = False
    escaped = False
    index = 0
    while index < len(text):
        char = text[index]
        following = text[index + 1] if index + 1 < len(text) else ""
        if quoted:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
            out.append(char)
        elif char == "/" and following == "/":
            index += 2
            while index < len(text) and text[index] != "\n":
                index += 1
            continue
        else:
            out.append(char)
        index += 1
    return json.loads("".join(out))


def object_at(value, name):
    if not isinstance(value, dict):
        raise InvalidConfig(f"{name} must be an object")
    return value


def named_port(tag):
    # A tag keeps its binding when inventory order or other entries change.
    return 20000 + int.from_bytes(hashlib.sha256(tag.encode()).digest()[:4], "big") % 40000


def compile_config(inventory, policy, concurrent=False):
    inventory = object_at(inventory, "inventory")
    policy = object_at(policy, "policy")
    if set(inventory) != {"endpoints", "outbounds", "dns"}:
        raise InvalidConfig("inventory must contain native endpoints, outbounds and DNS")
    endpoints = inventory["endpoints"]
    outbounds = inventory["outbounds"]
    if not isinstance(endpoints, list) or not isinstance(outbounds, list):
        raise InvalidConfig("endpoints and outbounds must be lists")
    entries = {}
    for kind, group in (("endpoints", endpoints), ("outbounds", outbounds)):
        for entry in group:
            if not isinstance(entry, dict):
                raise InvalidConfig("egress entry must be an object")
            tag = entry.get("tag")
            if not isinstance(tag, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", tag):
                raise InvalidConfig("invalid egress name")
            if tag in entries:
                raise InvalidConfig("duplicate egress name")
            if entry.get("type") == "direct" and not entry.get("bind_interface"):
                raise InvalidConfig("unbound direct outbound")
            entries[tag] = (kind, entry)
    if not entries:
        raise InvalidConfig("empty inventory")
    dns = object_at(inventory["dns"], "dns")
    if set(dns) != {"servers"} or not isinstance(dns["servers"], list):
        raise InvalidConfig("invalid DNS server inventory")
    servers = dns["servers"]
    server_tags = set()
    for server in servers:
        if not isinstance(server, dict) or server.get("type") != "udp" or \
                server.get("detour") not in entries or not isinstance(server.get("tag"), str):
            raise InvalidConfig("invalid DNS server route")
        if server["tag"] in server_tags:
            raise InvalidConfig("duplicate DNS server name")
        server_tags.add(server["tag"])
        try:
            if ipaddress.ip_address(server.get("server", "")).version != 4:
                raise InvalidConfig("default DNS needs an IPv4 resolver")
        except ValueError:
            raise InvalidConfig("DNS server must use an IP literal") from None
    if set(policy) != {"defaults", "pins", "ipv6"}:
        raise InvalidConfig("policy must contain defaults, pins and ipv6")
    defaults = object_at(policy["defaults"], "defaults")
    pins = object_at(policy["pins"], "pins")
    ipv6 = object_at(policy["ipv6"], "ipv6")
    if any(not isinstance(value, str) or value not in entries for value in defaults.values()):
        raise InvalidConfig("unknown declarative default")
    if any(not isinstance(value, str) or value not in entries for value in pins.values()):
        raise InvalidConfig("unknown installed-app pin")
    if set(ipv6) != set(entries) or any(type(value) is not bool for value in ipv6.values()):
        raise InvalidConfig("invalid IPv6 capability map")
    selected = defaults.get(socket.gethostname())
    if selected is None:
        raise InvalidConfig("missing hostname default")
    kind, entry = entries[selected]
    selected_dns = [server for server in servers if server["detour"] == selected]
    if not selected_dns:
        raise InvalidConfig("selected egress has no DNS server")
    config = {
        "log": {"level": "warn"},
        "dns": {"servers": [{"type": "local", "tag": "bootstrap"}] + selected_dns,
                "final": selected_dns[0]["tag"], "strategy": "ipv4_only"},
        "inbounds": [
            {"type": "mixed", "tag": "mixed", "listen": "127.0.0.1", "listen_port": 1080},
            {"type": "http", "tag": "http", "listen": "127.0.0.1", "listen_port": 3128},
        ],
        "route": {"final": selected, "default_domain_resolver": selected_dns[0]["tag"],
                  "auto_detect_interface": True,
                  "rules": [{"ip_version": 6, "action": "reject"}]},
        kind: [entry],
    }
    if concurrent:
        missing_dns = set(entries) - {server["detour"] for server in servers}
        if missing_dns:
            raise InvalidConfig("egress has no DNS server")
        ports = {tag: named_port(tag) for tag in entries}
        if len(set(ports.values())) != len(ports):
            raise InvalidConfig("named listener port collision")
        selector = "vpn-default-selector"
        if selector in entries or selector in server_tags or "vpn-default-dns" in server_tags:
            raise InvalidConfig("reserved VPN tag in inventory")
        default_dns = {"type": "udp", "tag": "vpn-default-dns",
                       "server": selected_dns[0]["server"], "detour": selector}
        named_inbounds = {tag: "vpn-named-" + tag for tag in entries}
        config["endpoints"] = endpoints
        config["outbounds"] = outbounds + [{"type": "selector", "tag": selector,
                                           "outbounds": list(entries), "default": selected,
                                           "interrupt_exist_connections": False}]
        config["inbounds"] += [
            {"type": "mixed", "tag": named_inbounds[tag],
             "listen": "127.0.0.1", "listen_port": ports[tag]}
            for tag in sorted(entries)
        ]
        config["dns"] = {
            "servers": [{"type": "local", "tag": "bootstrap"}, default_dns] + servers,
            "final": default_dns["tag"],
            "rules": [
                {"inbound": ["mixed", "http"], "query_type": ["AAAA"],
                 "action": "predefined"},
            ] + [
                {"inbound": [named_inbounds[tag]], "query_type": ["AAAA"],
                 "action": "predefined"}
                for tag in sorted(entries) if not ipv6[tag]
            ] + [
                {"inbound": [named_inbounds[tag]], "action": "route",
                 "server": next(server["tag"] for server in servers
                                if server["detour"] == tag)}
                for tag in sorted(entries)
            ],
        }
        config["route"] = {
            "final": selector, "default_domain_resolver": default_dns["tag"],
            "auto_detect_interface": True,
            "rules": [
                {"inbound": ["mixed", "http"], "ip_version": 6,
                 "action": "reject"},
            ] + [
                {"inbound": [named_inbounds[tag]], "ip_version": 6,
                 "action": "reject"}
                for tag in sorted(entries) if not ipv6[tag]
            ] + [
                {"inbound": [named_inbounds[tag]], "action": "route",
                 "outbound": tag}
                for tag in sorted(entries)
            ],
        }
    return config


def main():
    concurrent = len(sys.argv) == 5 and sys.argv[1] == "--concurrent"
    paths = sys.argv[2:] if concurrent else sys.argv[1:]
    if len(paths) != 3 or not os.path.isabs(paths[2]):
        print("usage: vpn-inventory-config [--concurrent] INVENTORY POLICY ABSOLUTE_OUTPUT", file=sys.stderr)
        return 2
    try:
        inventory = jsonc(Path(paths[0]).read_text())
        policy = jsonc(Path(paths[1]).read_text())
        config = compile_config(inventory, policy, concurrent)
    except (OSError, ValueError, InvalidConfig) as error:
        # Parser exceptions can include input fragments. Only our fixed messages
        # leave this boundary; credentials and private tags never enter logs.
        message = str(error) if isinstance(error, InvalidConfig) else "invalid JSONC or unreadable input"
        print(f"vpn-inventory-config: {message}", file=sys.stderr)
        return 1
    output = Path(paths[2])
    temporary = None
    try:
        # Check every native entry before selecting one. An inactive route with
        # malformed protocol fields must not wait until a later host switch to
        # surface its error. `check` parses the config without starting peers.
        all_routes = config if concurrent else {
            **config, "endpoints": inventory["endpoints"],
            "outbounds": inventory["outbounds"],
            "dns": {**config["dns"], "servers":
                    [{"type": "local", "tag": "bootstrap"}] +
                    inventory["dns"]["servers"]},
        }
        with tempfile.NamedTemporaryFile(mode="w", dir=output.parent,
                                     prefix=output.name + ".", delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(all_routes, stream, separators=(",", ":"))
            stream.write("\n")
        result = subprocess.run(["sing-box", "check", "-c", str(temporary)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                check=False)
        if result.returncode != 0:
            raise InvalidConfig("native inventory failed sing-box validation")
        with temporary.open("w") as stream:
            json.dump(config, stream, separators=(",", ":"))
            stream.write("\n")
        result = subprocess.run(["sing-box", "check", "-c", str(temporary)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                check=False)
        if result.returncode != 0:
            raise InvalidConfig("generated sing-box configuration failed validation")
        os.replace(temporary, output)
        temporary = None
    except (OSError, InvalidConfig) as error:
        message = str(error) if isinstance(error, InvalidConfig) else "cannot write configuration"
        print(f"vpn-inventory-config: {message}", file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
