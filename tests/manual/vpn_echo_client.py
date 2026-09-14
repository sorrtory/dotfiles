import socket

for family, address in ((socket.AF_INET, '192.0.2.1'),
                        (socket.AF_INET6, '2001:db8::1')):
    for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
        with socket.socket(family, kind) as sock:
            sock.settimeout(3)
            sock.connect((address, 18453))
            sock.sendall(b'vpn-capture-probe')
            assert sock.recv(4096) == b'vpn-capture-probe'
            print('PASS:', 'IPv4' if family == socket.AF_INET else 'IPv6',
                  'TCP' if kind == socket.SOCK_STREAM else 'UDP', flush=True)
