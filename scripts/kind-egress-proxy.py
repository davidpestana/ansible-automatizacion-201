#!/usr/bin/env python3
"""HTTP CONNECT proxy bound to the kind gateway (Codespace host).

The kind Docker network has no NAT in current GitHub Codespaces (Docker 29).
containerd on the nodes can still pull images if HTTPS_PROXY points here.
"""
import select
import socket
import sys
import threading

HOST, PORT = sys.argv[1], int(sys.argv[2])


def handle(client):
    try:
        req = b""
        while b"\r\n\r\n" not in req:
            chunk = client.recv(4096)
            if not chunk:
                client.close()
                return
            req += chunk
        line = req.split(b"\r\n", 1)[0].decode("iso-8859-1", "replace")
        parts = line.split()
        if len(parts) < 2 or parts[0].upper() != "CONNECT":
            client.sendall(b"HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n")
            client.close()
            return
        host, port = parts[1].rsplit(":", 1)
        upstream = socket.create_connection((host, int(port)), timeout=20)
        client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        upstream.setblocking(False)
        client.setblocking(False)
        while True:
            ready, _, err = select.select([client, upstream], [], [client, upstream], 60)
            if err or not ready:
                break
            for src, dst in ((client, upstream), (upstream, client)):
                if src in ready:
                    data = src.recv(65536)
                    if not data:
                        upstream.close()
                        client.close()
                        return
                    dst.sendall(data)
    except Exception:
        pass
    finally:
        try:
            client.close()
        except Exception:
            pass


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(128)
    print(f"kind-egress-proxy {HOST}:{PORT}", flush=True)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
