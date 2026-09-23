#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo/modules/programs/sing-box/vpn-egress.py" <<'PY'
import importlib.util
import io
import sys
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
print("vpn egress control errors passed")
PY
