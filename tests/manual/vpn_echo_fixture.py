import socket
import threading

def udp_echo():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('127.0.0.1', 18453))
    while True:
        data, peer = sock.recvfrom(4096)
        sock.sendto(data, peer)

threading.Thread(target=udp_echo, daemon=True).start()
server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('127.0.0.1', 18453))
server.listen()
while True:
    client, _ = server.accept()
    with client:
        client.sendall(client.recv(4096))
