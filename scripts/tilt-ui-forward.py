#!/usr/bin/env python3
"""Let the cluster's gateway reach the Tilt UI, for https://tilt.localhost.

Tilt runs on the host and listens on localhost only, which the gateway pod
cannot reach. Rather than `tilt up --host 0.0.0.0` - on a Linux or macOS
laptop that is every interface, LAN included, for an unauthenticated UI that
can trigger the Tiltfile's commands - this relays one address the cluster can
reach, the kind network's gateway on the host, to Tilt's localhost port.

What that still exposes, deliberately: any pod in a kind cluster can reach
the Tilt UI at that address. On a single-user teaching cluster that is the
learner's own code.

Needs the kind network's gateway to be an address on this host, which holds
for Docker or Podman on Linux and in WSL. Docker Desktop on Windows or macOS
keeps that network inside its VM; there the bind fails, loudly, and the Tilt
UI is still at http://localhost:<TILT_PORT>.

Usage: tilt-ui-forward.py <bind-ip> <port>   (listens on bind-ip:port,
forwards to 127.0.0.1:port)
"""
import socket
import sys
import threading


def pump(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        # Half-close so the other direction can finish: a websocket or a long
        # response keeps flowing after the request side is done.
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def handle(client, port):
    try:
        upstream = socket.create_connection(("127.0.0.1", port), timeout=5)
    except OSError as e:
        print(f"Tilt is not answering on 127.0.0.1:{port}: {e}", flush=True)
        client.close()
        return
    upstream.settimeout(None)
    t = threading.Thread(target=pump, args=(upstream, client), daemon=True)
    t.start()
    pump(client, upstream)
    t.join()
    client.close()
    upstream.close()


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    bind_ip, port = sys.argv[1], int(sys.argv[2])
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind((bind_ip, port))
    except OSError as e:
        sys.exit(f"cannot listen on {bind_ip}:{port} ({e}). The kind network's "
                 "gateway must be an address on this host; under Docker Desktop "
                 f"it is not. Use http://localhost:{port} instead.")
    server.listen(64)
    print(f"relaying {bind_ip}:{port} -> 127.0.0.1:{port} for tilt.localhost", flush=True)
    while True:
        client, _ = server.accept()
        threading.Thread(target=handle, args=(client, port), daemon=True).start()


if __name__ == "__main__":
    main()
