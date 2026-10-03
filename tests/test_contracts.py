"""Run the same contract examples through the Python worker validator."""

import json
import sys
import unittest
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services" / "worker" / "src"))
from matchlab_worker.contracts import validate_contract  # noqa: E402


class ContractCases(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = json.loads(
            (ROOT / "packages/contracts/schemas/v1.json").read_text(encoding="utf-8")
        )
        cls.cases = json.loads(
            (ROOT / "packages/contracts/examples/v1_cases.json").read_text(encoding="utf-8")
        )

    def test_valid_cases(self) -> None:
        for name, sample in self.cases["samples"].items():
            with self.subTest(name=name):
                self.assertEqual(validate_contract(self.catalog, name, sample), [])

    def test_invalid_cases(self) -> None:
        for case in self.cases["negative_cases"]:
            with self.subTest(name=case["name"]):
                sample = deepcopy(self.cases["samples"][case["contract"]])
                sample.update(case["set"])
                self.assertNotEqual(validate_contract(self.catalog, case["contract"], sample), [])


if __name__ == "__main__":
    unittest.main()
