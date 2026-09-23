#!/usr/bin/env python3
"""THROWAWAY staging-only TUN proof. Run on disposable Fedora VM as user z.

Requires SUDO_ASKPASS for the VM's intentionally public sudo password.
Creates no provider credentials. The root TUN is a transient systemd unit.
"""
import json
import os
import pathlib
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def run(*args, timeout=12):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    print("$", " ".join(args), "=>", result.returncode, flush=True)
    if result.stdout.strip():
        print(result.stdout.strip()[-700:], flush=True)
    if result.stderr.strip():
        print(result.stderr.strip()[-700:], flush=True)
    return result


def choose_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def write(path, obj):
    path.write_text(json.dumps(obj, indent=2))
    path.chmod(0o600)


def main():
    found = shutil.which("sing-box")
    singbox = os.path.realpath(found) if found else None
    assert singbox and os.environ.get("SUDO_ASKPASS"), "need sing-box and SUDO_ASKPASS"
    proxy_port = choose_port()
    named_port = choose_port()
    api_port = choose_port()
    backend = None
    tun_started = False
    capture = None
    with tempfile.TemporaryDirectory(prefix="vpn-whole-proof-") as temp:
        root = pathlib.Path(temp)
        backend_config = root / "backend.json"
        tun_config = root / "tun.json"
        capture_config = root / "capture.json"
        capture_runtime = root / "named-capture"
        capture_runtime.mkdir()
        write(backend_config, {
            "log": {"level": "info"},
            "inbounds": [{"type": "mixed", "tag": "default-in", "listen": "127.0.0.1", "listen_port": proxy_port}, {"type": "mixed", "tag": "named-b", "listen": "127.0.0.1", "listen_port": named_port}],
            "outbounds": [{"type": "direct", "tag": "physical-a", "bind_interface": "enp1s0"}, {"type": "direct", "tag": "physical-b", "bind_interface": "enp1s0"}, {"type": "block", "tag": "failed"}, {"type": "selector", "tag": "default-selector", "outbounds": ["physical-a", "physical-b", "failed"], "default": "physical-a"}],
            "route": {"rules": [{"inbound": "named-b", "action": "route", "outbound": "physical-b"}], "final": "default-selector"},
            "experimental": {"clash_api": {"external_controller": "127.0.0.1:" + str(api_port), "secret": "throwaway-control-token"}}
        })
        write(tun_config, {
            "log": {"level": "info"},
            "inbounds": [{"type": "tun", "tag": "host-tun", "interface_name": "vpnproof0", "address": ["172.31.254.1/30", "fd00:ffff:fe::1/126"], "mtu": 1400, "auto_route": True, "strict_route": False, "dns_mode": "hijack", "stack": "gvisor", "route_exclude_address": ["192.168.122.0/24", "192.168.123.0/24", "127.0.0.0/8", "::1/128", "fe80::/10", "fc00::/7"]}],
            "outbounds": [{"type": "socks", "tag": "backend", "server": "127.0.0.1", "server_port": proxy_port, "version": "5"}],
            "dns": {"servers": [{"type": "udp", "tag": "via-backend", "server": "192.168.122.1", "detour": "backend"}], "final": "via-backend", "strategy": "ipv4_only"},
            "route": {"rules": [{"inbound": "host-tun", "port": 53, "action": "hijack-dns"}, {"ip_version": 6, "action": "reject"}], "final": "backend"}
        })
        write(capture_config, {
            "log": {"level": "warn"},
            "network_namespaces": [{"type": "unshare", "tag": "apps", "pid_file": str(capture_runtime / "namespace.pid")}],
            "inbounds": [{"type": "tun", "tag": "apps-in", "netns": "apps", "interface_name": "vpn0", "address": ["172.31.253.1/30", "fd00:ffff:fd::1/126"], "mtu": 1400, "auto_route": True, "strict_route": True, "dns_mode": "disabled", "stack": "gvisor"}],
            "outbounds": [{"type": "socks", "tag": "named", "server": "127.0.0.1", "server_port": named_port, "version": "5"}],
            "dns": {"servers": [{"type": "udp", "tag": "via-named", "server": "192.168.122.1", "detour": "named"}], "final": "via-named"},
            "route": {"rules": [{"inbound": "apps-in", "port": 53, "action": "hijack-dns"}], "final": "named"}
        })
        assert run(singbox, "check", "-c", str(backend_config)).returncode == 0
        assert run(singbox, "check", "-c", str(tun_config)).returncode == 0
        assert run(singbox, "check", "-c", str(capture_config)).returncode == 0
        backend_log = (root / "backend.log").open("w")
        backend = subprocess.Popen([singbox, "run", "-c", str(backend_config)], stdout=backend_log, stderr=subprocess.STDOUT)
        try:
            for _ in range(30):
                if run("ss", "-ltn", timeout=3).stdout.find(":" + str(proxy_port)) >= 0:
                    break
                time.sleep(.1)
            resolved = run("getent", "ahostsv4", "www.gstatic.com")
            assert resolved.returncode == 0
            remote_ip = resolved.stdout.split()[0]
            print("public target", remote_ip, flush=True)
            run("ip", "route", "get", remote_ip)
            run("ip", "route", "get", "192.168.122.1")
            run("curl", "--noproxy", "*", "--socks5-hostname", "127.0.0.1:" + str(proxy_port), "--resolve", "www.gstatic.com:443:" + remote_ip, "-I", "--max-time", "6", "https://www.gstatic.com/generate_204")
            assert run("sudo", "-A", "systemd-run", "--unit=vpn-proof-tun", "--collect", "--property=Type=exec", "--property=RuntimeMaxSec=65", "/usr/bin/env", singbox, "run", "-c", str(tun_config)).returncode == 0
            tun_started = True
            for _ in range(30):
                if subprocess.run(["ip", "link", "show", "vpnproof0"], capture_output=True).returncode == 0:
                    break
                time.sleep(.1)
            else:
                run("sudo", "-A", "journalctl", "-u", "vpn-proof-tun.service", "-n", "30", "--no-pager")
                raise RuntimeError("TUN did not start")
            print("TUN active", flush=True)
            print("policy rules", run("ip", "rule", "show").stdout, flush=True)
            print("TUN table", run("ip", "route", "show", "table", "2022").stdout, flush=True)
            run("ip", "route", "get", remote_ip)
            run("ip", "route", "get", "192.168.122.1")
            run("ip", "route", "get", "192.168.123.1")
            run("ping", "-c", "1", "-W", "1", "192.168.122.1")
            run("curl", "--noproxy", "*", "--resolve", "www.gstatic.com:443:" + remote_ip, "-I", "--max-time", "8", "https://www.gstatic.com/generate_204")
            run("dig", "+short", "+time=2", "+tries=1", "@172.31.254.2", "www.gstatic.com", "A")
            run("dig", "+short", "+time=2", "+tries=1", "@172.31.254.2", "www.gstatic.com", "AAAA")
            run("resolvectl", "status", "vpnproof0")
            run("sudo", "-A", "resolvectl", "flush-caches")
            run("resolvectl", "query", "www.gstatic.com")
            capture_log = (root / "capture.log").open("w")
            capture = subprocess.Popen([singbox, "run", "-c", str(capture_config)], stdout=capture_log, stderr=subprocess.STDOUT)
            for _ in range(30):
                if (capture_runtime / "namespace.pid").exists():
                    break
                time.sleep(.1)
            else:
                print("capture log", (root / "capture.log").read_text()[-1000:], flush=True)
                raise RuntimeError("named capture did not start")
            holder = (capture_runtime / "namespace.pid").read_text().strip()
            named_curl = ("nsenter", "-U", "--preserve-credentials", "--keep-caps", "-n", "-t", holder, "curl", "--noproxy", "*", "--resolve", "www.gstatic.com:443:" + remote_ip, "-I", "--max-time", "6", "https://www.gstatic.com/generate_204")
            run(*named_curl)
            def select(name):
                request = urllib.request.Request("http://127.0.0.1:" + str(api_port) + "/proxies/default-selector", data=json.dumps({"name": name}).encode(), headers={"Authorization": "Bearer throwaway-control-token", "Content-Type": "application/json"}, method="PUT")
                try:
                    with urllib.request.urlopen(request, timeout=4) as response:
                        print("selector", name, response.status, flush=True)
                except urllib.error.HTTPError as error:
                    print("selector", name, error.code, flush=True)
            select("physical-b")
            run("curl", "--noproxy", "*", "--resolve", "www.gstatic.com:443:" + remote_ip, "-I", "--max-time", "6", "https://www.gstatic.com/generate_204")
            run(*named_curl)
            select("failed")
            run("curl", "--noproxy", "*", "--resolve", "www.gstatic.com:443:" + remote_ip, "-I", "--max-time", "3", "https://www.gstatic.com/generate_204")
            run(*named_curl)
            select("physical-a")
            run("sudo", "-A", "ip", "-6", "route", "replace", "default", "via", "fe80::dead", "dev", "enp1s0", "metric", "9999")
            run("ip", "-6", "route", "get", "2001:db8::1")
            run("curl", "--noproxy", "*", "-6", "-I", "--max-time", "3", "http://[2001:db8::1]/")
            backend.terminate()
            backend.wait(timeout=3)
            run("curl", "--noproxy", "*", "--resolve", "www.gstatic.com:443:" + remote_ip, "-I", "--max-time", "4", "https://www.gstatic.com/generate_204")
            backend = subprocess.Popen([singbox, "run", "-c", str(backend_config)], stdout=backend_log, stderr=subprocess.STDOUT)
            time.sleep(.3)
            run("curl", "--noproxy", "*", "--resolve", "www.gstatic.com:443:" + remote_ip, "-I", "--max-time", "6", "https://www.gstatic.com/generate_204")
            run(*named_curl)
            print("backend log tail", (root / "backend.log").read_text()[-1400:], flush=True)
            run("sudo", "-A", "journalctl", "-u", "vpn-proof-tun.service", "-n", "30", "--no-pager")
        finally:
            if capture is not None:
                capture.terminate()
                capture.wait(timeout=3)
                capture_log.close()
            if tun_started:
                run("sudo", "-A", "systemctl", "stop", "vpn-proof-tun.service")
            run("sudo", "-A", "ip", "-6", "route", "del", "default", "via", "fe80::dead", "dev", "enp1s0", "metric", "9999")
            if backend.poll() is None:
                backend.terminate()
                backend.wait(timeout=3)
            backend_log.close()
            run("ip", "link", "show", "vpnproof0")
            run("ip", "route", "get", "1.1.1.1")


if __name__ == "__main__":
    main()
