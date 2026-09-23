#!/usr/bin/env python3
"""Compile encrypted-at-rest native egresses into this host's default backend."""

import ipaddress
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


def compile_config(inventory, policy):
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
    for server in servers:
        if not isinstance(server, dict) or server.get("type") != "udp" or \
                server.get("detour") not in entries or not isinstance(server.get("tag"), str):
            raise InvalidConfig("invalid DNS server route")
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
    return config


def main():
    if len(sys.argv) != 4 or not os.path.isabs(sys.argv[3]):
        print("usage: vpn-inventory-config INVENTORY POLICY ABSOLUTE_OUTPUT", file=sys.stderr)
        return 2
    try:
        inventory = jsonc(Path(sys.argv[1]).read_text())
        policy = jsonc(Path(sys.argv[2]).read_text())
        config = compile_config(inventory, policy)
    except (OSError, ValueError, InvalidConfig) as error:
        # Parser exceptions can include input fragments. Only our fixed messages
        # leave this boundary; credentials and private tags never enter logs.
        message = str(error) if isinstance(error, InvalidConfig) else "invalid JSONC or unreadable input"
        print(f"vpn-inventory-config: {message}", file=sys.stderr)
        return 1
    output = Path(sys.argv[3])
    temporary = None
    try:
        # Check every native entry before selecting one. An inactive route with
        # malformed protocol fields must not wait until a later host switch to
        # surface its error. `check` parses the config without starting peers.
        all_routes = {**config, "endpoints": inventory["endpoints"],
                      "outbounds": inventory["outbounds"],
                      "dns": {**config["dns"], "servers":
                              [{"type": "local", "tag": "bootstrap"}] +
                              inventory["dns"]["servers"]}}
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
