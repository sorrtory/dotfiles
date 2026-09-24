#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo/modules/programs/sing-box/vpn-egress.py" <<'PY'
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch
from urllib.error import HTTPError, URLError

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("vpn_egress", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Opener:
    def __init__(self, error):
        self.error = error

    def open(self, request, timeout):
        raise self.error

def check(error, expected):
    with patch.object(module.urllib.request, "build_opener", return_value=Opener(error)):
        try:
            module.api({"controller": "http://127.0.0.1:19090", "secret": "test"},
                       "GET", "/proxies/example/delay?timeout=5000")
        except expected:
            return
        raise AssertionError(f"expected {expected.__name__}")

def http_error(code, message):
    return HTTPError("http://127.0.0.1/", code, "test", {},
                     io.BytesIO((f'{{"message":"{message}"}}').encode()))

check(http_error(503, "An error occurred in the delay test"), module.ProbeFailed)
check(http_error(504, "Request timeout"), module.ProbeFailed)
check(http_error(500, "internal control failure"), module.ControlError)
check(http_error(404, "route missing"), module.ControlError)
check(http_error(401, "unauthorized"), module.ControlError)
check(URLError("connection refused"), module.BackendUnavailable)

with tempfile.TemporaryDirectory() as root:
    group = Path(root) / "app.slice" / "test.scope"
    group.mkdir(parents=True)
    (group / "cgroup.procs").write_text("111\n")
    real_read_text = Path.read_text
    def read_text(path, *args, **kwargs):
        if str(path) == "/proc/111/task/111/children":
            return "222\n"
        if str(path) == "/proc/222/task/222/children":
            return ""
        return real_read_text(path, *args, **kwargs)
    relation = subprocess.CompletedProcess([], 0, "/app.slice/test.scope\n", "")
    with patch.object(module.subprocess, "run", return_value=relation), \
         patch.object(module.Path, "read_text", read_text), \
         patch.object(module.os, "readlink", side_effect=lambda path: {
             "/proc/111/ns/net": "net:[host]",
             "/proc/222/ns/net": "net:[capture]"}[path]):
        assert module.scope_namespace_matches("test.scope", "net:[capture]", Path(root))
        assert not module.scope_namespace_matches("test.scope", "net:[other]", Path(root))
print("vpn egress control errors passed")
PY
