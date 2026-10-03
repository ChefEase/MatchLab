"""Command-line entry point for the worker scaffold."""

import argparse
import json

from matchlab_worker.health import health_payload, serve_health
from matchlab_worker.football_data import sync_from_environment


def main() -> int:
    parser = argparse.ArgumentParser(description="MatchLab worker scaffold")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("health", help="print process health as JSON")
    server = commands.add_parser("serve-health", help="serve GET /health")
    server.add_argument("--host", default="127.0.0.1")
    server.add_argument("--port", type=int, default=8001)
    fixture_sync = commands.add_parser("sync-fixtures", help="reconcile an EPL season")
    fixture_sync.add_argument("--season", type=int, required=True)
    args = parser.parse_args()

    if args.command == "health":
        print(json.dumps(health_payload()))
        return 0

    if args.command == "sync-fixtures":
        print(json.dumps(sync_from_environment(args.season), sort_keys=True))
        return 0

    serve_health(args.host, args.port)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
