#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo/scripts/bin/mirror-website.sh" <<'PY'
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

script = sys.argv[1]
requests = []


class Site(BaseHTTPRequestHandler):
    def do_GET(self):
        requests.append((self.headers.get("Host"), self.path))
        port = self.server.server_port
        pages = {
            "/robots.txt": ("text/plain", b"User-agent: *\nDisallow: /blocked.html\n"),
            "/": ("text/html", f'''<html><body>
                <a href="/article.html">Article</a>
                <a href="/blocked.html">Blocked</a>
                <a href="http://127.0.0.1:{port}/outside.html">Outside</a>
                <img src="/local.png">
                <img src="http://127.0.0.1:{port}/external.png">
                </body></html>'''.encode()),
            "/article.html": ("text/html", b'<a href="/deep.html">Deep</a>'),
            "/deep.html": ("text/html", b"Deep article"),
            "/outside.html": ("text/html", b'<a href="/further.html">Further</a>'),
            "/further.html": ("text/html", b"Further external article"),
            "/blocked.html": ("text/html", b"Robots-excluded article"),
            "/local.png": ("image/png", b"local image fixture"),
            "/external.png": ("image/png", b"external image fixture"),
        }
        kind, data = pages.get(self.path, ("text/plain", b"Not found"))
        self.send_response(200 if self.path in pages else 404)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Last-Modified", "Wed, 14 Oct 2026 08:00:00 GMT")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Site)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
port = server.server_port
url = f"http://localhost:{port}/"
env = os.environ.copy()
for key in list(env):
    if key.lower().endswith("_proxy") or key == "PROXY":
        env.pop(key)
env["PROXY"] = ""


def run(*args, success=True, environment=None):
    result = subprocess.run(
        ["bash", script, *args], env=env if environment is None else environment, text=True,
        capture_output=True, timeout=30,
    )
    assert (result.returncode == 0) == success, result.stderr
    return result


try:
    with tempfile.TemporaryDirectory(prefix="mirror-website-test-") as root:
        root = Path(root)

        def mirror(name, *options):
            requests.clear()
            destination = root / name
            run("--to", str(destination), *options, url, "--", "--wait=0")
            return destination, destination / f"localhost:{port}"

        destination, host = mirror("default")
        assert (host / "deep.html").is_file(), "default did not crawl the whole host"
        assert (host / "local.png").read_bytes() == b"local image fixture"
        assert not any(h.startswith("127.0.0.1:") for h, _ in requests), requests
        assert (host / "blocked.html").exists(), "default still obeyed robots rules"
        assert not any(p == "/robots.txt" for _, p in requests), requests
        html = (host / "index.html").read_text()
        assert 'href="article.html"' in html, "downloaded link wasn't localized"
        assert f'http://127.0.0.1:{port}/outside.html' in html
        assert (host / "index.html.orig").exists(), "original HTML wasn't retained"
        # The converted mirror must remain usable after a timestamped rerun.
        run("--to", str(destination), url, "--", "--wait=0")
        assert 'href="article.html"' in (host / "index.html").read_text()

        _, host = mirror("depth", "--depth", "1")
        assert (host / "article.html").exists()
        assert not (host / "deep.html").exists(), "depth limit was ignored"

        destination, host = mirror("domains with spaces", "--domains", "127.0.0.1")
        external = destination / f"127.0.0.1:{port}"
        assert (host / "article.html").exists(), "allowlist lost seed host"
        assert (external / "further.html").exists(), "external domain wasn't crawled"
        assert (external / "external.png").read_bytes() == b"external image fixture"
        assert f'../127.0.0.1:{port}/outside.html' in (host / "index.html").read_text()

        destination, host = mirror("page", "--page")
        assert (host / "index.html").exists()
        assert not (host / "article.html").exists(), "page mode followed a page link"
        assert (destination / f"127.0.0.1:{port}" / "external.png").exists()
        assert not any(p == "/outside.html" for _, p in requests), requests

        requests.clear()
        destination = root / "dry-run"
        result = run("--dry-run", "--to", str(destination), url)
        assert "wget " in result.stdout
        assert "--no-proxy" in result.stdout
        assert not requests and not destination.exists()

        proxied = run("--dry-run", url,
                      environment={**env, "PROXY": "http://proxy.invalid:3128"})
        assert "http_proxy=http://proxy.invalid:3128" in proxied.stdout
        assert "https_proxy=http://proxy.invalid:3128" in proxied.stdout
        inherited = env.copy()
        inherited.pop("PROXY")
        assert "--no-proxy" not in run("--dry-run", url, environment=inherited).stdout

        for args in [(), ("--depth", "-1", url), ("--to=", url),
                     ("--domains=", url), ("--domains", "https://other.org", url),
                     ("--page", "--domains", "other.org", url),
                     ("--page", "--depth", "2", url), (url, url),
                     ("file:///tmp/example",)]:
            run(*args, success=False)

        # Explicit backend overrides survive, while Wget failures propagate.
        run("--to", str(root / "override"), url, "--",
            "--wait=0", "--execute=robots=on")
        respected = root / "override" / f"localhost:{port}"
        assert (respected / "article.html").exists()
        assert not (respected / "blocked.html").exists(), "robots override was ignored"
        run("--to", str(root / "failure"), url, "--",
            "--definitely-not-a-wget-option", success=False)
finally:
    server.shutdown()
    server.server_close()

print("mirror-website: local crawl, assets, link conversion, scope, and CLI checks passed")
PY
