#!/usr/bin/env python3
import json
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class HealthHandler(BaseHTTPRequestHandler):
    server_version = "OracleHostPlatformHealth/1.0"

    def do_GET(self):
        if self.path not in ("/health", "/api/health"):
            self.send_response(404)
            self.end_headers()
            return

        body = json.dumps(
            {
                "ok": True,
                "service": "oracle-host-platform",
                "host": socket.gethostname(),
                "timestamp": int(time.time()),
            },
            separators=(",", ":"),
        ).encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 3500), HealthHandler)
    server.serve_forever()
