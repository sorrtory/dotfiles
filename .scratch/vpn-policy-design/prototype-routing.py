#!/usr/bin/env python3
"""Throwaway, nonsecret sing-box routing proof. Run with python3; wipes its temp data."""
import contextlib
import atexit
import json
import os
import pathlib
import socket
import ssl
import struct
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

SING_BOX = "/home/z/.nix-profile/bin/sing-box"
TOKEN = "throwaway-control-token"
PROCESSES = []


def cleanup():
    for process in reversed(PROCESSES):
        with contextlib.suppress(Exception):
            process.terminate()
            process.wait(timeout=2)


atexit.register(cleanup)


def port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def readn(sock, count):
    result = b""
    while len(result) < count:
        part = sock.recv(count - len(result))
        if not part:
            raise EOFError()
        result += part
    return result


def dns_answer(query, label):
    qid = query[:2]
    offset = 12
    while query[offset] != 0:
        offset += 1 + query[offset]
    question = query[12:offset + 5]
    qtype = struct.unpack("!H", query[offset + 1:offset + 3])[0]
    if qtype == 28 and label == "B":
        data = socket.inet_pton(socket.AF_INET6, "2001:db8::42")
    elif qtype == 1:
        data = bytes([127, 0, 0, 41 if label == "A" else 42])
    else:
        data = b""
    answer = b"\xc0\x0c" + struct.pack("!HHIH", qtype, 1, 10, len(data)) + data if data else b""
    return qid + b"\x81\x80" + struct.pack("!HHHH", 1, 1 if data else 0, 0, 0) + question + answer


class MockSocks:
    def __init__(self, label, listen, tls):
        self.label, self.listen, self.tls = label, listen, tls
        self.events = []
        self.udp_events = []
        self.enabled = True
        self.server = socket.socket()
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind(("127.0.0.1", listen))
        self.server.listen()
        threading.Thread(target=self.loop, daemon=True).start()

    def loop(self):
        while True:
            try:
                conn, _ = self.server.accept()
            except OSError:
                return
            threading.Thread(target=self.handle, args=(conn,), daemon=True).start()

    def handle(self, conn):
        try:
            with conn:
                conn.settimeout(8)
                if not self.enabled:
                    return
                version, methods = readn(conn, 2)
                assert version == 5
                readn(conn, methods)
                conn.sendall(b"\x05\x00")
                head = readn(conn, 4)
                assert head[0] == 5 and head[2] == 0, head
                command = head[1]
                if head[3] == 1:
                    dest = socket.inet_ntop(socket.AF_INET, readn(conn, 4))
                elif head[3] == 3:
                    dest = readn(conn, readn(conn, 1)[0]).decode()
                elif head[3] == 4:
                    dest = socket.inet_ntop(socket.AF_INET6, readn(conn, 16))
                else:
                    raise AssertionError(head)
                destport = struct.unpack("!H", readn(conn, 2))[0]
                if ":" in dest and self.label == "A":
                    conn.sendall(b"\x05\x04\x00\x01\x7f\x00\x00\x01\x00\x00")
                    return
                if command == 3:
                    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
                        udp.bind(("127.0.0.1", 0))
                        udp.settimeout(4)
                        udpport = udp.getsockname()[1]
                        conn.sendall(b"\x05\x00\x00\x01\x7f\x00\x00\x01" + struct.pack("!H", udpport))
                        while self.enabled:
                            try:
                                packet, client = udp.recvfrom(4096)
                            except socket.timeout:
                                continue
                            assert packet[:4] == b"\x00\x00\x00\x01", packet[:4]
                            target = socket.inet_ntop(socket.AF_INET, packet[4:8])
                            target_port = struct.unpack("!H", packet[8:10])[0]
                            self.udp_events.append((target, target_port, packet[10:]))
                            udp.sendto(packet[:10] + self.label.encode(), client)
                    return
                assert command == 1, command
                self.events.append((dest, destport))
                conn.sendall(b"\x05\x00\x00\x01\x7f\x00\x00\x01\x00\x00")
                if destport == 18080:
                    readn(conn, 3)
                    body = (self.label + "\n").encode()
                    conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: " + str(len(body)).encode() + b"\r\nConnection: close\r\n\r\n" + body)
                elif destport == 15353:
                    length = struct.unpack("!H", readn(conn, 2))[0]
                    answer = dns_answer(readn(conn, length), self.label)
                    conn.sendall(struct.pack("!H", len(answer)) + answer)
                elif destport == 443:
                    wrapped = self.tls.wrap_socket(conn, server_side=True)
                    wrapped.recv(4096)
                    wrapped.sendall(b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
                    wrapped.close()
        except (EOFError, OSError, ssl.SSLError) as exc:
            print("mock", self.label, "connection ended:", type(exc).__name__, str(exc)[:100], flush=True)


def write(path, data):
    path.write_text(json.dumps(data, indent=2))
    path.chmod(0o600)


def check_config(path):
    result = subprocess.run([SING_BOX, "check", "-c", str(path)], capture_output=True, text=True)
    print("config", path.name, result.returncode, result.stderr.strip()[-300:], flush=True)
    assert result.returncode == 0, result.stdout + result.stderr


def api(apiport, method, path, body=None, auth=True):
    headers = {"Authorization": "Bearer " + TOKEN} if auth else {}
    if body is not None:
        headers["Content-Type"] = "application/json"
        body = json.dumps(body).encode()
    request = urllib.request.Request("http://127.0.0.1:" + str(apiport) + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()


def run_cmd(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=12)
    return result.returncode, result.stdout.strip(), result.stderr.strip()[-200:]


def capture_config(path, runtime, backendport, ipv6=False):
    write(path, {
        "log": {"level": "warn"},
        "network_namespaces": [{"type": "unshare", "tag": "apps", "pid_file": str(runtime / "namespace.pid")}],
        "inbounds": [{"type": "tun", "tag": "apps-in", "netns": "apps", "interface_name": "vpn0", "address": ["172.31.255.1/30"] + (["fd00:ffff::1/126"] if ipv6 else []), "mtu": 1400, "auto_route": True, "strict_route": True, "dns_mode": "disabled", "stack": "gvisor"}],
        "outbounds": [{"type": "socks", "tag": "proxy", "server": "127.0.0.1", "server_port": backendport, "version": "5"}],
        "dns": {"servers": [{"type": "tcp", "tag": "via-proxy", "server": "127.0.0.1", "server_port": 15353, "detour": "proxy"}], "final": "via-proxy", **({} if ipv6 else {"strategy": "ipv4_only"})},
        "route": {"rules": [{"inbound": "apps-in", "port": 53, "action": "hijack-dns"}] + ([] if ipv6 else [{"ip_version": 6, "action": "reject"}]), "final": "proxy"}
    })


def main():
    processes = PROCESSES
    with tempfile.TemporaryDirectory(prefix="vpn-routing-proof-") as temp:
        root = pathlib.Path(temp)
        cert, key = root / "cert.pem", root / "key.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(key), "-out", str(cert), "-subj", "/CN=www.gstatic.com", "-addext", "subjectAltName=DNS:www.gstatic.com", "-days", "1"], check=True, capture_output=True)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(str(cert), str(key))
        ports = {name: port() for name in ("egressA", "egressB", "default", "namedB", "missing", "api")}
        egressA = MockSocks("A", ports["egressA"], tls)
        egressB = MockSocks("B", ports["egressB"], tls)
        backend = root / "backend.json"
        write(backend, {
            "log": {"level": "warn"},
            "experimental": {"clash_api": {"external_controller": "127.0.0.1:" + str(ports["api"]), "secret": TOKEN, "access_control_allow_private_network": False}},
            "inbounds": [{"type": "mixed", "tag": "default-in", "listen": "127.0.0.1", "listen_port": ports["default"]}, {"type": "mixed", "tag": "named-B", "listen": "127.0.0.1", "listen_port": ports["namedB"]}],
            "outbounds": [{"type": "socks", "tag": "A", "server": "127.0.0.1", "server_port": ports["egressA"], "version": "5"}, {"type": "socks", "tag": "B", "server": "127.0.0.1", "server_port": ports["egressB"], "version": "5"}, {"type": "selector", "tag": "default-selector", "outbounds": ["A", "B"], "default": "A", "interrupt_exist_connections": False}],
            "route": {"rules": [{"inbound": "default-in", "ip_version": 6, "action": "reject"}, {"inbound": "named-B", "action": "route", "outbound": "B"}], "final": "default-selector"}
        })
        check_config(backend)
        env = dict(os.environ)
        env["SSL_CERT_FILE"] = str(cert)
        env.pop("http_proxy", None); env.pop("https_proxy", None); env.pop("HTTP_PROXY", None); env.pop("HTTPS_PROXY", None)
        processes.append(subprocess.Popen([SING_BOX, "run", "-c", str(backend)], stdout=(root / "backend.log").open("w"), stderr=subprocess.STDOUT, env=env))
        for _ in range(50):
            try:
                if api(ports["api"], "GET", "/proxies/default-selector")[0] == 200:
                    break
            except OSError:
                time.sleep(.1)
        print("unauthenticated API", api(ports["api"], "GET", "/proxies/default-selector", auth=False)[0], flush=True)
        print("selector initial", api(ports["api"], "GET", "/proxies/default-selector"), flush=True)
        for tag in ("default", "namedB", "missing"):
            runtime = root / tag
            runtime.mkdir()
            config = runtime / "config.json"
            capture_config(config, runtime, ports[tag], ipv6=(tag == "namedB"))
            check_config(config)
            processes.append(subprocess.Popen([SING_BOX, "run", "-c", str(config)], stdout=(runtime / "capture.log").open("w"), stderr=subprocess.STDOUT, env=env))
        for tag in ("default", "namedB", "missing"):
            pidfile = root / tag / "namespace.pid"
            for _ in range(50):
                if pidfile.exists():
                    break
                time.sleep(.1)
            if not pidfile.exists():
                print("capture did not start", tag, (root / tag / "capture.log").read_text()[-1000:], flush=True)
                raise RuntimeError("capture failed")
            print("namespace", tag, pidfile.read_text().strip(), flush=True)
        def inside(tag, *cmd):
            pid = (root / tag / "namespace.pid").read_text().strip()
            return run_cmd("nsenter", "-U", "--preserve-credentials", "--keep-caps", "-n", "-t", pid, *cmd)
        udp_client = "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(3); s.sendto(b'ping',('198.18.0.1',19090)); print(s.recvfrom(64)[0].decode())"
        print("missing listener HTTP", inside("missing", "curl", "--noproxy", "*", "-sS", "--max-time", "3", "http://198.18.0.1:18080/"), flush=True)
        print("missing listener DNS", inside("missing", "dig", "+short", "+time=1", "+tries=1", "@172.31.255.2", "route.test", "A"), flush=True)
        for tag in ("default", "namedB"):
            print("HTTP", tag, inside(tag, "curl", "--noproxy", "*", "-sS", "--max-time", "4", "http://198.18.0.1:18080/"), flush=True)
            print("DNS", tag, inside(tag, "dig", "+short", "+time=2", "+tries=1", "@172.31.255.2", "route.test", "A"), flush=True)
            print("DNS AAAA", tag, inside(tag, "dig", "+short", "+time=2", "+tries=1", "@172.31.255.2", "route.test", "AAAA"), flush=True)
            print("UDP", tag, inside(tag, "python3", "-c", udp_client), flush=True)
            print("IPv6", tag, inside(tag, "curl", "--noproxy", "*", "-6", "-sS", "--max-time", "2", "http://[2001:db8::1]:18080/"), flush=True)
        print("named HTTPS check", api(ports["api"], "GET", "/proxies/B/delay?timeout=5000"), flush=True)
        print("unknown HTTPS check", api(ports["api"], "GET", "/proxies/missing/delay?timeout=5000"), flush=True)
        print("selector change", api(ports["api"], "PUT", "/proxies/default-selector", {"name": "B"}), flush=True)
        print("selector after change", api(ports["api"], "GET", "/proxies/default-selector"), flush=True)
        print("default local proxy IPv6", run_cmd("curl", "--socks5-hostname", "127.0.0.1:" + str(ports["default"]), "--noproxy", "", "-sS", "--max-time", "2", "http://[2001:db8::1]:18080/"), flush=True)
        print("named local listener IPv6", run_cmd("curl", "--socks5-hostname", "127.0.0.1:" + str(ports["namedB"]), "--noproxy", "", "-sS", "--max-time", "2", "http://[2001:db8::1]:18080/"), flush=True)
        for tag in ("default", "namedB"):
            print("HTTP after switch", tag, inside(tag, "curl", "--noproxy", "*", "-sS", "--max-time", "4", "http://198.18.0.1:18080/"), flush=True)
            print("DNS after switch", tag, inside(tag, "dig", "+short", "+time=2", "+tries=1", "@172.31.255.2", "route.test", "A"), flush=True)
            print("DNS AAAA after switch", tag, inside(tag, "dig", "+short", "+time=2", "+tries=1", "@172.31.255.2", "route.test", "AAAA"), flush=True)
            print("UDP after switch", tag, inside(tag, "python3", "-c", udp_client), flush=True)
            print("IPv6 after switch", tag, inside(tag, "curl", "--noproxy", "*", "-6", "-sS", "--max-time", "2", "http://[2001:db8::1]:18080/"), flush=True)
        egressB.enabled = False
        print("failed B HTTP", inside("namedB", "curl", "--noproxy", "*", "-sS", "--max-time", "3", "http://198.18.0.1:18080/"), flush=True)
        print("failed B UDP", inside("namedB", "python3", "-c", udp_client), flush=True)
        print("events A", egressA.events, flush=True)
        print("events B", egressB.events, flush=True)
        print("UDP events A", egressA.udp_events, flush=True)
        print("UDP events B", egressB.udp_events, flush=True)
        processes[0].terminate()
        processes[0].wait(timeout=5)
        print("stopped backend HTTP", inside("default", "curl", "--noproxy", "*", "-sS", "--max-time", "3", "http://198.18.0.1:18080/"), flush=True)
        processes[0] = subprocess.Popen([SING_BOX, "run", "-c", str(backend)], stdout=(root / "backend-restart.log").open("w"), stderr=subprocess.STDOUT, env=env)
        time.sleep(.7)
        print("selector after backend restart", api(ports["api"], "GET", "/proxies/default-selector"), flush=True)
        print("backend log", (root / "backend.log").read_text()[-500:], flush=True)
        print("capture default log", (root / "default" / "capture.log").read_text()[-500:], flush=True)
        print("capture named log", (root / "namedB" / "capture.log").read_text()[-500:], flush=True)
        egressA.server.close()


if __name__ == "__main__":
    main()
