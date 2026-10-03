"""Generate the Task 5 seed from the frozen candidate tables in MATCHLAB_SPEC.md.

Uses only Python's standard library. Run from the repository root:
    python scripts/generate_factor_seed.py
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "MATCHLAB_SPEC.md"
OUTPUT = ROOT / "supabase" / "seed.sql"
ROW = re.compile(r"^\| ([SB]\d{2}) \| (.*?) \| (.*?) \|$")
APPROVED = {"S01", "S02", "S36"}


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def classify(code: str) -> tuple[str, str]:
    number = int(code[1:])
    if code[0] == "S":
        if number in {11, 25, 36, 41, 42, 43, 44, 45, 48, 49, 50}:
            scope = "fixture"
        elif number in {9, 10, 12, 13, 14, 15, 16, 20, 21, 22}:
            scope = "player"
        else:
            scope = "team"
        if number <= 10:
            group = "team_scoring"
        elif number <= 22:
            group = "roster_and_player"
        elif number <= 35:
            group = "tactics_and_matchups"
        elif number <= 45:
            group = "venue_schedule_context"
        else:
            group = "events_and_interactions"
    else:
        if number in {25, 26, 29, 41, 46, 49}:
            scope = "fixture"
        elif number in {30, 31, 32, 33, 37, 38, 39, 40}:
            scope = "player"
        else:
            scope = "team"
        if number <= 24:
            group = "team_efficiency_and_possessions"
        elif number <= 28:
            group = "play_type_and_lineup_fit"
        elif number <= 40:
            group = "roster_and_player"
        else:
            group = "venue_schedule_context"
    return scope, group


rows = []
for line in SPEC.read_text(encoding="utf-8").splitlines():
    match = ROW.fullmatch(line)
    if match:
        code, title, direction = match.groups()
        scope, group = classify(code)
        rows.append((code, title, direction, scope, group))

codes = [row[0] for row in rows]
expected = [f"S{i:02d}" for i in range(1, 51)] + [f"B{i:02d}" for i in range(1, 51)]
if sorted(codes) != sorted(expected) or len(codes) != 100:
    raise ValueError("Expected exactly S01-S50 and B01-B50 once each in MATCHLAB_SPEC.md")

values = ",\n".join(
    "    (" + ", ".join(sql_literal(part) for part in row) + ")" for row in rows
)

sql = f"""-- Task 5: first ruleset and candidate factor registry.
-- Generated from MATCHLAB_SPEC.md by scripts/generate_factor_seed.py.
-- Safe to rerun: existing version-1 definitions and ruleset are preserved.
-- 'active' means approved for the first baseline; no engine has been fitted yet.
-- All basketball factors and unsupported soccer factors remain candidates.
BEGIN;

INSERT INTO matchlab.rulesets (code, sport, version, rules)
VALUES (
    'epl_regular_season', 'soccer', 1,
    '{{"duration_minutes":90,"stoppage_time_included":true,"draw_allowed":true,"extra_time":false,"shootout":false}}'::jsonb
)
ON CONFLICT (sport, code, version) DO NOTHING;

WITH catalog (code, title, direction, scope, dependency_group) AS (
    VALUES
{values}
)
INSERT INTO matchlab.feature_definitions
    (code, version, sport, definition, unit, scope, lookback, availability_rule,
     transformation, dependency_group, missing_policy, uncertainty_method, lifecycle)
SELECT
    code,
    1,
    CASE WHEN code LIKE 'S%' THEN 'soccer' ELSE 'basketball' END,
    CASE code
        WHEN 'S01' THEN 'Long-term attack strength: opponent-adjusted goals scored from eligible earlier EPL matches, shrunk toward the league average.'
        WHEN 'S02' THEN 'Long-term defensive strength: opponent-adjusted goals conceded from eligible earlier EPL matches, shrunk toward the league average.'
        ELSE title || ': ' || direction
    END,
    CASE code WHEN 'S01' THEN 'goals per match' WHEN 'S02' THEN 'goals conceded per match' WHEN 'S36' THEN 'home indicator' ELSE NULL END,
    scope,
    CASE WHEN code IN ('S01', 'S02', 'S36')
        THEN '{{"policy":"eligible_prior_EPL_results"}}'::jsonb
        ELSE '{{"status":"undefined_until_activation"}}'::jsonb END,
    CASE WHEN code IN ('S01', 'S02')
        THEN '{{"source":"football-data.org v4 PL final scores","horizon":"H24","historical_result_lag_hours":48}}'::jsonb
        WHEN code = 'S36'
        THEN '{{"source":"football-data.org v4 PL fixture home/away roles and prior final scores","horizon":"H24","historical_result_lag_hours":48}}'::jsonb
        ELSE '{{"status":"source_and_cutoff_not_approved"}}'::jsonb END,
    CASE WHEN code IN ('S01', 'S02', 'S36')
        THEN '{{"protocol":"EVALUATION_PROTOCOL_v1.md","status":"pending_engine_implementation"}}'::jsonb
        ELSE '{{"status":"not_implemented"}}'::jsonb END,
    dependency_group,
    CASE WHEN code IN ('S01', 'S02') THEN 'prior' WHEN code = 'S36' THEN 'block' ELSE 'disable' END,
    CASE WHEN code IN ('S01', 'S02', 'S36')
        THEN '{{"status":"to_be_estimated_with_baseline"}}'::jsonb
        ELSE '{{"status":"not_defined"}}'::jsonb END,
    CASE WHEN code IN ('S01', 'S02', 'S36') THEN 'active' ELSE 'candidate' END
FROM catalog
ON CONFLICT (code, version) DO NOTHING;

DO $check$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM matchlab.rulesets
        WHERE sport = 'soccer' AND code = 'epl_regular_season' AND version = 1
          AND rules->>'duration_minutes' = '90'
          AND rules->>'draw_allowed' = 'true'
          AND rules->>'extra_time' = 'false'
    ) THEN
        RAISE EXCEPTION 'Task 5 seed: EPL ruleset missing or incompatible';
    END IF;
    IF (SELECT count(*) FROM matchlab.feature_definitions
        WHERE version = 1 AND code ~ '^S(0[1-9]|[1-4][0-9]|50)$') <> 50
       OR (SELECT count(*) FROM matchlab.feature_definitions
        WHERE version = 1 AND code ~ '^B(0[1-9]|[1-4][0-9]|50)$') <> 50 THEN
        RAISE EXCEPTION 'Task 5 seed: expected 50 soccer and 50 basketball definitions';
    END IF;
    IF EXISTS (
        SELECT 1 FROM matchlab.feature_definitions
        WHERE version = 1 AND code ~ '^[SB](0[1-9]|[1-4][0-9]|50)$'
          AND (sport <> CASE WHEN code LIKE 'S%' THEN 'soccer' ELSE 'basketball' END
               OR lifecycle <> CASE WHEN code IN ('S01','S02','S36') THEN 'active' ELSE 'candidate' END)
    ) THEN
        RAISE EXCEPTION 'Task 5 seed: sport or lifecycle mismatch';
    END IF;
END;
$check$;

COMMIT;

SELECT sport, lifecycle, count(*) AS factor_count
FROM matchlab.feature_definitions
WHERE version = 1 AND code ~ '^[SB](0[1-9]|[1-4][0-9]|50)$'
GROUP BY sport, lifecycle
ORDER BY sport, lifecycle;
"""

OUTPUT.write_text(sql, encoding="utf-8")
print(f"Wrote {OUTPUT.relative_to(ROOT)} with {len(rows)} factor definitions")
