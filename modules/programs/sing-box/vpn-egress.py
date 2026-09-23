#!/usr/bin/env python3
"""Read and change the live sing-box default through its private Clash API."""

import json
import os
from pathlib import Path
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
        if "/delay?" in path and error.code not in (401, 403):
            raise ProbeFailed("named HTTPS probe failed") from None
        raise ControlError(f"control API returned HTTP {error.code}") from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise BackendUnavailable("backend control API is unavailable") from None
    except ValueError:
        raise ControlError("invalid backend control response") from None


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "list"
    arguments = sys.argv[2:]
    if command not in ("list", "status", "use", "default", "check") or len(arguments) != (1 if command in ("use", "check") else 0):
        print("usage: vpn-egress [list|status|use NAME|default|check NAME]", file=sys.stderr)
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
        if not isinstance(names, list) or default not in names:
            raise ControlError("invalid control metadata")
    except (OSError, ValueError, KeyError, TypeError, ControlError) as error:
        print(f"vpn-egress: {error if isinstance(error, ControlError) else 'cannot read private control file'}", file=sys.stderr)
        return 4
    if command in ("use", "check") and arguments[0] not in names:
        print("vpn-egress: unknown egress name", file=sys.stderr)
        return 3
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
