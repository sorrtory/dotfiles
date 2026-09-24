#!/usr/bin/env python3
"""Compile one encrypted egress list into a private sing-box config."""

import ipaddress
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
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


def operator_notes(text):
    """Inventory // lines are designated safe, public operator notes."""
    return [line.strip()[2:].strip() for line in text.splitlines()
            if line.strip().startswith("//")]


def object_at(value, name):
    if not isinstance(value, dict):
        raise InvalidConfig(f"{name} must be an object")
    return value


def native_routes(routes):
    """Place one source list into the sections required by sing-box."""
    return ([route for route in routes if route["type"] == "wireguard"],
            [route for route in routes if route["type"] != "wireguard"])


def named_port(tag):
    # A tag keeps its binding when inventory order or other entries change.
    return 20000 + int.from_bytes(hashlib.sha256(tag.encode()).digest()[:4], "big") % 40000


def binding_ledger(path, config):
    """Reserve a named listener's port until reboot, including removed tags."""
    previous = {}
    if path.exists():
        try:
            previous = json.loads(path.read_text())
        except (OSError, ValueError):
            raise InvalidConfig("invalid listener binding record") from None
        if not isinstance(previous, dict) or any(
                not isinstance(tag, str) or not isinstance(port, int)
                for tag, port in previous.items()):
            raise InvalidConfig("invalid listener binding record")
    current = {item["tag"]: item["listen_port"] for item in config["inbounds"]
               if item["tag"].startswith("vpn-named-")}
    by_port = {port: tag for tag, port in previous.items()}
    if len(by_port) != len(previous):
        raise InvalidConfig("listener binding record reuses a port")
    if any(tag in previous and previous[tag] != port or
           port in by_port and by_port[port] != tag
           for tag, port in current.items()):
        raise InvalidConfig("named listener port was reserved by another route")
    return {**previous, **current}


def compile_config(inventory, policy, apps, concurrent=False):
    inventory = object_at(inventory, "inventory")
    policy = object_at(policy, "policy")
    if (not isinstance(apps, list) or
            any(not isinstance(app, str) or
                not re.fullmatch(r"[a-z][a-z0-9-]*", app) for app in apps) or
            len(apps) != len(set(apps))):
        raise InvalidConfig("invalid installed-app registry")
    registered_apps = set(apps)
    if set(inventory) != {"outbounds", "dns"}:
        raise InvalidConfig("inventory must contain outbounds and DNS")
    routes = inventory["outbounds"]
    if not isinstance(routes, list):
        raise InvalidConfig("outbounds must be a list")
    entries = {}
    for entry in routes:
        if not isinstance(entry, dict):
            raise InvalidConfig("egress entry must be an object")
        tag = entry.get("tag")
        if not isinstance(tag, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", tag):
            raise InvalidConfig("invalid egress name")
        if tag in entries:
            raise InvalidConfig("duplicate egress name")
        if entry.get("type") == "direct" and not entry.get("bind_interface"):
            raise InvalidConfig("unbound direct outbound")
        if not isinstance(entry.get("type"), str):
            raise InvalidConfig("egress type is required")
        entries[tag] = entry
    if not entries:
        raise InvalidConfig("empty inventory")
    endpoints, outbounds = native_routes(routes)
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
    required_policy = {"defaults", "pins", "ipv6"}
    if set(policy) not in (required_policy, required_policy | {"wireguard_owners"}):
        raise InvalidConfig("policy must contain defaults, pins, ipv6 and optional WireGuard owners")
    defaults = object_at(policy["defaults"], "defaults")
    pins = object_at(policy["pins"], "pins")
    ipv6 = object_at(policy["ipv6"], "ipv6")
    owners = object_at(policy.get("wireguard_owners", {}), "WireGuard owners")
    if any(not isinstance(value, str) or value not in entries for value in defaults.values()):
        raise InvalidConfig("unknown declarative default")
    if any(host not in defaults or not isinstance(host_pins, dict) or
           any(not isinstance(app, str) or
               not re.fullmatch(r"[a-z][a-z0-9-]*", app) or
               host == socket.gethostname() and app not in registered_apps or
               not isinstance(route, str) or route not in entries
               for app, route in host_pins.items())
           for host, host_pins in pins.items()):
        raise InvalidConfig("unknown installed-app pin")
    if set(ipv6) != set(entries) or any(type(value) is not bool for value in ipv6.values()):
        raise InvalidConfig("invalid IPv6 capability map")
    wireguard_tags = {tag for tag, route in entries.items()
                      if route["type"] == "wireguard"}
    if owners and (set(owners) != wireguard_tags or
                   any(not isinstance(host, str) or host not in defaults
                       for host in owners.values())):
        raise InvalidConfig("invalid WireGuard ownership map")
    if any(route in owners and owners[route] != host
           for host, apps in pins.items() for route in apps.values()):
        raise InvalidConfig("installed-app pin uses another host's WireGuard peer")
    hostname = socket.gethostname()
    selected = defaults.get(hostname)
    if selected is None:
        raise InvalidConfig("missing hostname default")
    entry = entries[selected]
    kind = "endpoints" if entry["type"] == "wireguard" else "outbounds"
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
        for route in entries.values():
            addresses = ([peer.get("address") for peer in route.get("peers", [])]
                         if route["type"] == "wireguard" else
                         [route["server"]] if "server" in route else [])
            for address in addresses:
                try:
                    ipaddress.ip_address(address)
                except (ValueError, TypeError):
                    raise InvalidConfig("egress server hostname needs physical-route bootstrap") from None
        # A WireGuard peer cannot run on two machines: the server would move
        # its endpoint between them. Ownership is independent of the default;
        # non-WireGuard outbounds may be shared by all inventory hosts.
        if set(owners) != wireguard_tags:
            raise InvalidConfig("WireGuard peer lacks an explicit hostname owner")
        active = {tag for tag in entries if tag not in owners or owners[tag] == hostname}
        if selected not in active:
            raise InvalidConfig("hostname default is unavailable")
        if any(tag not in active for tag in pins.get(hostname, {}).values()):
            raise InvalidConfig("installed-app pin is unavailable on this host")
        active_servers = [server for server in servers if server["detour"] in active]
        missing_dns = active - {server["detour"] for server in active_servers}
        if missing_dns:
            raise InvalidConfig("egress has no DNS server")
        # The default capture and whole-host TUN keep one resolver address
        # across selector changes. Until runtime DNS follows the selector's
        # choice, reject inventories whose routes need different primaries.
        primary_dns = {tag: next(server["server"] for server in active_servers
                                 if server["detour"] == tag) for tag in active}
        if len(set(primary_dns.values())) != 1:
            raise InvalidConfig("concurrent defaults need a shared primary DNS server")
        ports = {tag: named_port(tag) for tag in active}
        if len(set(ports.values())) != len(ports):
            raise InvalidConfig("named listener port collision")
        selector = "vpn-default-selector"
        if selector in entries or selector in server_tags or "vpn-default-dns" in server_tags:
            raise InvalidConfig("reserved VPN tag in inventory")
        default_dns = {"type": "udp", "tag": "vpn-default-dns",
                       "server": selected_dns[0]["server"], "detour": selector}
        named_inbounds = {tag: "vpn-named-" + tag for tag in active}
        config["endpoints"] = [route for route in endpoints if route["tag"] in active]
        # One source list gives every egress the same tag semantics. Split
        # only when emitting sing-box's required native sections.
        config["outbounds"] = [route for route in outbounds if route["tag"] in active] + [
            {"type": "selector", "tag": selector,
                                           "outbounds": sorted(active), "default": selected,
                                           "interrupt_exist_connections": False}]
        config["inbounds"] += [
            {"type": "mixed", "tag": named_inbounds[tag],
             "listen": "127.0.0.1", "listen_port": ports[tag]}
            for tag in sorted(active)
        ]
        config["dns"] = {
            "servers": [{"type": "local", "tag": "bootstrap"}, default_dns] + active_servers,
            "final": default_dns["tag"],
            "rules": [
                {"inbound": ["mixed", "http"], "query_type": ["AAAA"],
                 "action": "predefined"},
            ] + [
                {"inbound": [named_inbounds[tag]], "query_type": ["AAAA"],
                 "action": "predefined"}
                for tag in sorted(active) if not ipv6[tag]
            ] + [
                {"inbound": [named_inbounds[tag]], "action": "route",
                "server": next(server["tag"] for server in active_servers
                                if server["detour"] == tag)}
                for tag in sorted(active)
            ],
        }
        if not any(ipv6[tag] for tag in active):
            config["dns"]["strategy"] = "ipv4_only"
        config["route"] = {
            "final": selector, "default_domain_resolver": default_dns["tag"],
            "auto_detect_interface": True,
            "rules": [
                {"inbound": ["mixed", "http"], "ip_version": 6,
                 "action": "reject"},
            ] + [
                {"inbound": [named_inbounds[tag]], "ip_version": 6,
                 "action": "reject"}
                for tag in sorted(active) if not ipv6[tag]
            ] + [
                {"inbound": [named_inbounds[tag]], "action": "route",
                 "outbound": tag}
                for tag in sorted(active)
            ],
        }
        config["experimental"] = {"clash_api": {
            "external_controller": "127.0.0.1:19090",
            "secret": secrets.token_urlsafe(32),
        }}
    return config


def main():
    if len(sys.argv) < 3 or sys.argv[1] != "--apps":
        print("usage: vpn-inventory-config --apps REGISTRY [--concurrent --bindings ABSOLUTE_LEDGER] INVENTORY POLICY ABSOLUTE_OUTPUT", file=sys.stderr)
        return 2
    app_registry = Path(sys.argv[2])
    arguments = sys.argv[3:]
    concurrent = len(arguments) == 6 and arguments[:2] == ["--concurrent", "--bindings"]
    bindings = Path(arguments[2]) if concurrent else None
    paths = arguments[3:] if concurrent else arguments
    if (len(paths) != 3 or not os.path.isabs(paths[2]) or
            concurrent and not bindings.is_absolute()):
        print("usage: vpn-inventory-config --apps REGISTRY [--concurrent --bindings ABSOLUTE_LEDGER] INVENTORY POLICY ABSOLUTE_OUTPUT", file=sys.stderr)
        return 2
    try:
        inventory_text = Path(paths[0]).read_text()
        inventory = jsonc(inventory_text)
        policy = jsonc(Path(paths[1]).read_text())
        apps = json.loads(app_registry.read_text())
        config = compile_config(inventory, policy, apps, concurrent)
    except (OSError, ValueError, InvalidConfig) as error:
        # Parser exceptions can include input fragments. Only our fixed messages
        # leave this boundary; credentials and private tags never enter logs.
        message = str(error) if isinstance(error, InvalidConfig) else "invalid JSONC or unreadable input"
        print(f"vpn-inventory-config: {message}", file=sys.stderr)
        return 1
    output = Path(paths[2])
    temporary = None
    ledger_temporary = None
    control_temporary = None
    try:
        # Check every native entry before selecting one. An inactive route with
        # malformed protocol fields must not wait until a later host switch to
        # surface its error. `check` parses the config without starting peers.
        all_endpoints, all_outbounds = native_routes(inventory["outbounds"])
        all_routes = {
            **config, "route": {"final": policy["defaults"][socket.gethostname()],
                                "auto_detect_interface": True},
            "endpoints": all_endpoints,
            "outbounds": all_outbounds,
            "dns": {"servers": [{"type": "local", "tag": "bootstrap"}] +
                    inventory["dns"]["servers"],
                    "final": inventory["dns"]["servers"][0]["tag"]},
            "inbounds": [],
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
        if concurrent:
            ledger = binding_ledger(bindings, config)
            with tempfile.NamedTemporaryFile(mode="w", dir=bindings.parent,
                                         prefix="vpn-bindings.", delete=False) as stream:
                ledger_temporary = Path(stream.name)
                json.dump(ledger, stream, separators=(",", ":"))
                stream.write("\n")
            os.replace(ledger_temporary, bindings)
            ledger_temporary = None
            control = bindings.parent / "vpn-control.json"
            with tempfile.NamedTemporaryFile(mode="w", dir=control.parent,
                                         prefix="vpn-control.", delete=False) as stream:
                control_temporary = Path(stream.name)
                json.dump({"controller": "http://127.0.0.1:19090",
                           "secret": config["experimental"]["clash_api"]["secret"],
                           "declarative_default": policy["defaults"][socket.gethostname()],
                           "names": config["outbounds"][-1]["outbounds"],
                           "apps": apps,
                           "pins": policy["pins"].get(socket.gethostname(), {}),
                           "notes": operator_notes(inventory_text)}, stream)
                stream.write("\n")
            os.replace(control_temporary, control)
            control_temporary = None
        os.replace(temporary, output)
        temporary = None
    except (OSError, InvalidConfig) as error:
        message = str(error) if isinstance(error, InvalidConfig) else "cannot write configuration"
        print(f"vpn-inventory-config: {message}", file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
        if ledger_temporary is not None:
            ledger_temporary.unlink(missing_ok=True)
        if control_temporary is not None:
            control_temporary.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
