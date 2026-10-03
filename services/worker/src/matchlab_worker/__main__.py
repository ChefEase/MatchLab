"""Command-line entry point for the worker scaffold."""

import argparse
import json

from matchlab_worker.health import health_payload, serve_health


def main() -> int:
    parser = argparse.ArgumentParser(description="MatchLab worker scaffold")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("health", help="print process health as JSON")
    server = commands.add_parser("serve-health", help="serve GET /health")
    server.add_argument("--host", default="127.0.0.1")
    server.add_argument("--port", type=int, default=8001)
    args = parser.parse_args()

    if args.command == "health":
        print(json.dumps(health_payload()))
        return 0

    serve_health(args.host, args.port)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
