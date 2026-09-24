#!/usr/bin/env python3
"""Stop only VPN scopes whose route or app pin changes on HM activation."""

import json
from pathlib import Path
import re
import subprocess
import sys


def read_json(path):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return None


def named_tags(config):
    if not config:
        return set()
    return {inbound["tag"].removeprefix("vpn-named-")
            for inbound in config.get("inbounds", [])
            if inbound.get("tag", "").startswith("vpn-named-")}


def signature(config, tag):
    inbound = "vpn-named-" + tag
    return {
        "route": [item for kind in ("endpoints", "outbounds")
                  for item in config.get(kind, []) if item.get("tag") == tag],
        "listener": [item for item in config.get("inbounds", [])
                     if item.get("tag") == inbound],
        "dns_servers": [item for item in config.get("dns", {}).get("servers", [])
                        if item.get("detour") == tag],
        "dns_rules": [item for item in config.get("dns", {}).get("rules", [])
                      if inbound in item.get("inbound", [])],
        "route_rules": [item for item in config.get("route", {}).get("rules", [])
                        if inbound in item.get("inbound", [])],
    }


def systemctl(*args):
    result = subprocess.run(["systemctl", "--user", *args], capture_output=True,
                            text=True, check=False)
    if result.returncode:
        raise RuntimeError("cannot inspect or stop VPN scopes")
    return result.stdout


def main():
    if len(sys.argv) != 5:
        print("usage: vpn-reconcile OLD_CONFIG NEW_CONFIG OLD_CONTROL NEW_CONTROL", file=sys.stderr)
        return 2
    old = read_json(sys.argv[1])
    new = read_json(sys.argv[2])
    old_control = read_json(sys.argv[3]) or {}
    new_control = read_json(sys.argv[4])
    if not new or not new_control:
        print("vpn-reconcile: missing validated incoming configuration", file=sys.stderr)
        return 1
    old_tags = named_tags(old) or set(old_control.get("names", []))
    new_tags = named_tags(new)
    changed = {tag for tag in old_tags
               if tag not in new_tags or old is None or
               signature(old, tag) != signature(new, tag)}
    old_pins = old_control.get("pins", {})
    new_pins = new_control.get("pins", {})
    pin_changes = {app for app in set(old_pins) | set(new_pins)
                   if old_pins.get(app) != new_pins.get(app)}
    legacy_scopes = "pins" not in old_control
    try:
        scopes = systemctl("list-units", "--all", "--type=scope", "--plain",
                           "--no-legend", "vpn-app-*.scope")
        for line in scopes.splitlines():
            unit = line.split()[0] if line.split() else ""
            if not unit:
                continue
            requires = systemctl("show", unit, "-p", "Requires", "--value").split()
            capture_units = [item for item in requires
                             if item == "vpn-capture.service" or
                             re.fullmatch(r"vpn-capture@[0-9a-f]+\.service", item)]
            if len(capture_units) != 1:
                raise RuntimeError("VPN scope has an unknown capture dependency")
            attached = capture_units[0]
            tag = (bytes.fromhex(attached.removeprefix("vpn-capture@")
                                 .removesuffix(".service")).decode()
                   if attached.startswith("vpn-capture@") else "default")
            app = next((key for key in ("vesktop", "ayugram")
                        if unit.startswith("vpn-app-" + key + "-")), "one-off")
            reason = ("pre-pin scope identity unknown" if legacy_scopes else
                      "app pin changed" if app in pin_changes else
                      "named route definition changed or removed" if tag in changed else
                      None)
            if reason:
                print(f"Stopping {app} scope on {tag}: {reason}")
                systemctl("stop", unit)
        for tag in sorted(changed):
            unit = "vpn-capture@" + tag.encode().hex() + ".service"
            state = subprocess.run(["systemctl", "--user", "is-active", unit],
                                   capture_output=True, text=True, check=False)
            if state.stdout.strip() == "active":
                systemctl("stop", unit)
    except (RuntimeError, ValueError, UnicodeError) as error:
        print(f"vpn-reconcile: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
