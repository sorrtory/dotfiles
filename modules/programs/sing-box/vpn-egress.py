#!/usr/bin/env python3
"""Read and change the live sing-box default through its private Clash API."""

import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


class ControlError(Exception):
    pass


class BackendUnavailable(Exception):
    pass


class ProbeFailed(Exception):
    pass


def api(control, method, path, body=None):
    request = urllib.request.Request(
        control["controller"] + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + control["secret"],
                 "Content-Type": "application/json"},
        method=method,
    )
    try:
        with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(
                request, timeout=7) as response:
            data = response.read()
        return json.loads(data) if data else {}
    except urllib.error.HTTPError as error:
        # sing-box reports a failed delay test as 503 and its five-second
        # deadline as 504. Other statuses indicate a control/API problem.
        if "/delay?" in path and error.code in (503, 504):
            raise ProbeFailed("named HTTPS probe failed") from None
        raise ControlError(f"control API returned HTTP {error.code}") from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise BackendUnavailable("backend control API is unavailable") from None
    except ValueError:
        raise ControlError("invalid backend control response") from None


def unit_active(unit):
    try:
        result = subprocess.run(["systemctl", "--user", "is-active", unit],
                                capture_output=True, text=True, check=False)
        return result.stdout.strip() == "active"
    except OSError:
        return False


def scope_namespace_matches(scope, inode, cgroup_root=Path("/sys/fs/cgroup")):
    """Find a payload process in this scope's capture namespace."""
    relation = subprocess.run(
        ["systemctl", "--user", "show", scope, "-p", "ControlGroup", "--value"],
        capture_output=True, text=True, check=False)
    group = relation.stdout.strip()
    if relation.returncode or not group.startswith("/"):
        return False
    cgroup = (cgroup_root / group.lstrip("/")).resolve()
    if not cgroup.is_relative_to(cgroup_root):
        return False
    try:
        pending = [int(pid) for pid in (cgroup / "cgroup.procs").read_text().split()]
    except (OSError, ValueError):
        return False
    seen = set()
    while pending:
        pid = pending.pop()
        if pid in seen:
            continue
        seen.add(pid)
        try:
            if os.readlink(f"/proc/{pid}/ns/net") == inode:
                return True
            # Electron can move a child to its own cgroup; it remains a
            # descendant of the launcher while vpn-enter waits for it.
            children = Path(f"/proc/{pid}/task/{pid}/children").read_text()
            pending.extend(int(child) for child in children.split())
        except (OSError, ValueError):
            continue
    return False


def inspect_capture(runtime, name):
    encoded = name.encode().hex()
    unit = f"vpn-capture@{encoded}.service"
    backend = Path(runtime) / "sing-box/config.json"
    capture = Path(runtime) / f"vpn-capture-{encoded}"
    try:
        config = json.loads(backend.read_text())
        ports = [item["listen_port"] for item in config["inbounds"]
                 if item.get("tag") == "vpn-named-" + name]
        port = ports[0] if len(ports) == 1 else None
        routes = [rule.get("outbound") for rule in config["route"]["rules"]
                  if rule.get("inbound") == ["vpn-named-" + name]
                  and rule.get("action") == "route"]
        routing_matches = routes == [name]
    except (OSError, ValueError, KeyError, TypeError):
        port = None
        routing_matches = False
    backend_up = unit_active("sing-box.service")
    capture_up = unit_active(unit)
    listener_up = False
    if port is not None and backend_up:
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=.3):
                listener_up = True
        except OSError:
            pass
    try:
        adapter = json.loads((capture / "config.json").read_text())
        binding_matches = adapter["outbounds"][0]["server_port"] == port
        pid = int((capture / "namespace.pid").read_text().strip())
        inode = os.readlink(f"/proc/{pid}/ns/net")
        isolated = inode != os.readlink("/proc/self/ns/net")
    except (OSError, ValueError, KeyError, IndexError, TypeError):
        binding_matches, pid, inode, isolated = False, None, None, False
    scopes = subprocess.run(
        ["systemctl", "--user", "list-units", "--all", "--type=scope",
         "--plain", "--no-legend", "vpn-app-*.scope"],
        capture_output=True, text=True, check=False)
    attached = []
    if scopes.returncode == 0:
        for line in scopes.stdout.splitlines():
            scope = line.split()[0] if line.split() else ""
            if not scope:
                continue
            relation = subprocess.run(
                ["systemctl", "--user", "show", scope, "-p", "Requires", "--value"],
                capture_output=True, text=True, check=False)
            if relation.returncode == 0 and unit in relation.stdout.split():
                attached.append(scope)
    scope_matches = {scope: scope_namespace_matches(scope, inode)
                     for scope in attached} if inode else {}
    if not attached and not capture_up:
        state = "idle"
    elif not backend_up:
        state = "backend-outage"
    elif (capture_up and attached and listener_up and binding_matches and
          routing_matches and isolated and all(scope_matches.values())):
        state = "attached"
    else:
        state = "mismatch"
    print(f"route: {name}")
    print(f"backend: {'active' if backend_up else 'inactive'}")
    print(f"listener: 127.0.0.1:{port if port is not None else 'missing'} ({'up' if listener_up else 'down'})")
    print(f"routing: {'matched' if routing_matches else 'mismatch'}")
    print(f"capture: {'active' if capture_up else 'inactive'}")
    print(f"namespace: {pid if pid is not None else 'missing'} {inode or ''}".rstrip())
    print(f"scopes: {len(attached)}")
    for scope, matches in sorted(scope_matches.items()):
        print(f"scope: {scope} namespace: {'matched' if matches else 'mismatch'}")
    print(f"state: {state}")
    return {"attached": 0, "idle": 0, "backend-outage": 7, "mismatch": 8}[state]


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "list"
    arguments = sys.argv[2:]
    if command not in ("list", "status", "use", "default", "check", "inspect", "resolve") or len(arguments) != (1 if command in ("use", "check", "inspect", "resolve") else 0):
        print("usage: vpn-egress [list|status|use NAME|default|check NAME|inspect NAME|resolve APP]", file=sys.stderr)
        return 2
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        print("vpn-egress: XDG_RUNTIME_DIR is required", file=sys.stderr)
        return 4
    try:
        path = Path(runtime) / "vpn-control.json"
        if path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o077:
            raise ControlError("private control file has unsafe ownership or mode")
        control = json.loads(path.read_text())
        names = control["names"]
        default = control["declarative_default"]
        if (not isinstance(names, list) or default not in names or
                not isinstance(control.get("pins", {}), dict)):
            raise ControlError("invalid control metadata")
    except (OSError, ValueError, KeyError, TypeError, ControlError) as error:
        print(f"vpn-egress: {error if isinstance(error, ControlError) else 'cannot read private control file'}", file=sys.stderr)
        return 4
    if command == "resolve":
        app = arguments[0]
        if app not in ("vesktop", "ayugram"):
            print("vpn-egress: unknown app key", file=sys.stderr)
            return 3
        pin = control.get("pins", {}).get(app)
        if pin is not None and pin not in names:
            print("vpn-egress: invalid installed-app pin", file=sys.stderr)
            return 4
        print("named:" + pin if pin is not None else "default")
        return 0
    if command in ("use", "check", "inspect") and arguments[0] not in names:
        print("vpn-egress: unknown egress name", file=sys.stderr)
        return 3
    if command == "inspect":
        return inspect_capture(runtime, arguments[0])
    try:
        selector = api(control, "GET", "/proxies/vpn-default-selector")
        active = selector["now"]
        if active not in names:
            raise ControlError("selector returned an unknown egress")
        if command == "list":
            for name in names:
                marks = []
                if name == active:
                    marks.append("active")
                if name == default:
                    marks.append("declarative")
                print(name + (" (" + ", ".join(marks) + ")" if marks else ""))
            for note in control.get("notes", []):
                print("note: " + note)
        elif command == "status":
            print(f"active: {active}")
            print(f"declarative: {default}")
            print("state: " + ("declarative" if active == default else "temporary"))
        elif command in ("use", "default"):
            chosen = arguments[0] if command == "use" else default
            if chosen != active:
                api(control, "PUT", "/proxies/vpn-default-selector", {"name": chosen})
                readback = api(control, "GET", "/proxies/vpn-default-selector")
                if readback.get("now") != chosen:
                    raise ControlError("selector change did not take effect")
            print(chosen)
        else:
            name = urllib.parse.quote(arguments[0], safe="")
            url = urllib.parse.quote("https://www.gstatic.com/generate_204", safe="")
            result = api(control, "GET", f"/proxies/{name}/delay?timeout=5000&url={url}")
            if not isinstance(result.get("delay"), (int, float)):
                raise ProbeFailed("named HTTPS probe failed")
            print(f"{arguments[0]}: HTTPS reachable ({result['delay']} ms)")
    except BackendUnavailable as error:
        print(f"vpn-egress: {error}", file=sys.stderr)
        return 6
    except ProbeFailed as error:
        print(f"vpn-egress: {error}", file=sys.stderr)
        return 5
    except ControlError as error:
        print(f"vpn-egress: {error}", file=sys.stderr)
        return 4
    except (KeyError, TypeError):
        print("vpn-egress: invalid backend control response", file=sys.stderr)
        return 4
    return 0


if __name__ == "__main__":
    sys.exit(main())
