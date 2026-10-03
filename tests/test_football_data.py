"""Offline tests for the approved football-data.org v4 adapter."""

import sys
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services" / "worker" / "src"))
from matchlab_worker.football_data import ProviderError, fetch_season  # noqa: E402


class FootballDataAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.competition = {"id": 2021, "code": "PL", "name": "Premier League"}
        self.teams = {"teams": [{"id": 1, "name": "Example Home"}]}
        self.matches = {
            "resultSet": {"count": 1},
            "matches": [{"id": 3, "competition": {"code": "PL"}}],
        }

    def test_uses_season_specific_endpoints(self) -> None:
        with patch(
            "matchlab_worker.football_data.fetch_json",
            side_effect=[self.competition, self.teams, self.matches],
        ) as fetch:
            competition, teams, matches = fetch_season(2026, "test-token")
        self.assertEqual(competition["code"], "PL")
        self.assertEqual(len(teams), 1)
        self.assertEqual(len(matches), 1)
        self.assertEqual(
            [call.args[0] for call in fetch.call_args_list],
            [
                "/competitions/PL",
                "/competitions/PL/teams?season=2026",
                "/competitions/PL/matches?season=2026",
            ],
        )

    def test_rejects_incomplete_match_list(self) -> None:
        self.matches["resultSet"]["count"] = 2
        with patch(
            "matchlab_worker.football_data.fetch_json",
            side_effect=[self.competition, self.teams, self.matches],
        ):
            with self.assertRaisesRegex(ProviderError, "count"):
                fetch_season(2026, "test-token")

    def test_rejects_other_competition(self) -> None:
        self.matches["matches"][0]["competition"]["code"] = "CL"
        with patch(
            "matchlab_worker.football_data.fetch_json",
            side_effect=[self.competition, self.teams, self.matches],
        ):
            with self.assertRaisesRegex(ProviderError, "non-EPL"):
                fetch_season(2026, "test-token")


if __name__ == "__main__":
    unittest.main()
