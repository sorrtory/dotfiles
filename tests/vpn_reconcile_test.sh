#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo/modules/programs/vpnized-apps/reconcile.py" <<'PY'
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("reconcile", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def config(a_server=15001, include_a=True):
    routes = ([{"type": "socks", "tag": "route-a", "server": "127.0.0.1",
                "server_port": a_server}] if include_a else []) + [
                    {"type": "socks", "tag": "route-b", "server": "127.0.0.1",
                     "server_port": 15002}]
    return {"outbounds": routes,
            "inbounds": [{"tag": "vpn-named-" + route["tag"],
                          "listen_port": 20001 if route["tag"] == "route-a" else 20002}
                         for route in routes],
            "dns": {"servers": [{"tag": "dns-" + route["tag"],
                                  "detour": route["tag"]} for route in routes],
                    "rules": []},
            "route": {"rules": [{"inbound": ["vpn-named-" + route["tag"]],
                                 "action": "route", "outbound": route["tag"]}
                                for route in routes]}}

scopes = {
    "vpn-app-vesktop-1.scope": "vpn-capture@" + "route-a".encode().hex() + ".service",
    "vpn-app-ayugram-2.scope": "vpn-capture@" + "route-b".encode().hex() + ".service",
    "vpn-app-3.scope": "vpn-capture@" + "route-a".encode().hex() + ".service",
}

def scenario(old, new, old_pins, new_pins, expected):
    stopped = []
    def systemctl(*args):
        if args[0] == "list-units":
            return "".join(unit + " loaded active running\n" for unit in scopes)
        if args[0] == "show":
            return "app.slice " + scopes[args[1]] + "\n"
        if args[0] == "stop":
            stopped.append(args[1])
            return ""
        raise AssertionError(args)
    with tempfile.TemporaryDirectory() as root:
        paths = [Path(root) / part for part in ("old", "new", "old-control", "new-control")]
        for path, value in zip(paths, (old, new,
                                       {"names": ["route-a", "route-b"], "pins": old_pins},
                                       {"names": ["route-a", "route-b"], "pins": new_pins})):
            path.write_text(json.dumps(value))
        with patch.object(module, "systemctl", side_effect=systemctl), \
             patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 3, "inactive", "")), \
             patch.object(sys, "argv", ["vpn-reconcile", *map(str, paths)]):
            assert module.main() == 0
    assert stopped == expected, (stopped, expected)

same = config()
scenario(same, same, {"vesktop": "route-a"}, {"vesktop": "route-b"},
         ["vpn-app-vesktop-1.scope"])
scenario(same, config(a_server=15003), {}, {},
         ["vpn-app-vesktop-1.scope", "vpn-app-3.scope"])
scenario(same, config(include_a=False), {}, {},
         ["vpn-app-vesktop-1.scope", "vpn-app-3.scope"])
scenario(same, same, {"vesktop": "route-a"}, {},
         ["vpn-app-vesktop-1.scope"])
print("vpn selective reconciliation passed")
PY
