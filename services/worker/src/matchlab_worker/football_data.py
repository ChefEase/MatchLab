"""football-data.org v4 fixture ingestion for the EPL.

The provider URL is fixed. The token is read from the environment and never
logged. The database functions own mapping, source history and revisions.
"""

import json
import os
from datetime import datetime, timezone
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


BASE_URL = "https://api.football-data.org/v4"


class ProviderError(RuntimeError):
    """A provider response cannot safely be used for ingestion."""


def fetch_json(path: str, token: str) -> dict[str, Any]:
    if not token or not path.startswith("/") or ".." in path or path.startswith("//"):
        raise ValueError("Invalid provider request")
    request = Request(
        BASE_URL + path,
        headers={"X-Auth-Token": token, "Accept": "application/json"},
        method="GET",
    )
    try:
        with urlopen(request, timeout=30) as response:
            document = json.load(response)
    except HTTPError as exc:
        raise ProviderError(f"football-data.org HTTP {exc.code}") from exc
    except URLError as exc:
        raise ProviderError("football-data.org request failed") from exc
    if not isinstance(document, dict):
        raise ProviderError("football-data.org returned a non-object response")
    return document


def fetch_season(
    season: int, token: str
) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    if season < 2000 or season > 2100:
        raise ValueError("Season must be a four-digit starting year")
    competition = fetch_json("/competitions/PL", token)
    team_response = fetch_json(f"/competitions/PL/teams?season={season}", token)
    match_response = fetch_json(f"/competitions/PL/matches?season={season}", token)
    if competition.get("code") != "PL":
        raise ProviderError("Expected Premier League competition")
    teams = team_response.get("teams")
    matches = match_response.get("matches")
    if not isinstance(teams, list) or not teams or not isinstance(matches, list):
        raise ProviderError("Incomplete EPL team or match response")
    if any(not isinstance(item, dict) for item in teams + matches):
        raise ProviderError("Invalid EPL team or match item")
    result_set = match_response.get("resultSet")
    reported_count = result_set.get("count") if isinstance(result_set, dict) else None
    if reported_count is not None and reported_count != len(matches):
        raise ProviderError("EPL match response count does not match its resultSet")
    if any(
        not isinstance(match.get("competition"), dict)
        or match["competition"].get("code") != "PL"
        for match in matches
    ):
        raise ProviderError("Match response contains a non-EPL fixture")
    return competition, teams, matches


def sync_season(season: int, token: str, database_url: str) -> dict[str, int]:
    """Fetch one season and commit catalog plus fixture reconciliation atomically."""
    competition, teams, matches = fetch_season(season, token)
    try:
        import psycopg  # Imported only for an actual database sync.
    except ImportError as exc:
        raise RuntimeError("Database sync requires the worker's optional db dependency") from exc

    seen_at = datetime.now(timezone.utc)
    counts = {"created": 0, "revised": 0, "unchanged": 0, "review_required": 0}
    with psycopg.connect(database_url) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT * FROM matchlab.fd_catalog(%s::jsonb, %s::jsonb, %s)",
                (json.dumps(competition), json.dumps(teams), seen_at),
            )
            cursor.fetchone()
            for match in matches:
                cursor.execute(
                    "SELECT * FROM matchlab.fd_fixture(%s::jsonb, %s)",
                    (json.dumps(match), seen_at),
                )
                row = cursor.fetchone()
                if row is None or row[0] not in counts:
                    raise RuntimeError("Fixture ingestion returned an unknown outcome")
                counts[row[0]] += 1
    return counts


def sync_from_environment(season: int) -> dict[str, int]:
    token = os.environ.get("FOOTBALL_DATA_API_TOKEN", "")
    database_url = os.environ.get("DATABASE_URL", "")
    if not token or not database_url:
        raise RuntimeError("FOOTBALL_DATA_API_TOKEN and DATABASE_URL are required")
    return sync_season(season, token, database_url)
