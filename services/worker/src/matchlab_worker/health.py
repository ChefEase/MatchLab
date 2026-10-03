"""Dependency-free process health checks for the worker scaffold."""

import json
from http.server import BaseHTTPRequestHandler, HTTPServer


def health_payload() -> dict[str, str]:
    return {"status": "ok", "service": "worker", "mode": "scaffold"}


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        if self.path != "/health":
            self.send_error(404)
            return

        body = json.dumps(health_payload()).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def serve_health(host: str, port: int) -> None:
    server = HTTPServer((host, port), HealthHandler)
    print(f"Worker health endpoint: http://{host}:{port}/health", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
