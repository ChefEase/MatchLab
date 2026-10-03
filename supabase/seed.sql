-- Task 5: first ruleset and candidate factor registry.
-- Generated from MATCHLAB_SPEC.md by scripts/generate_factor_seed.py.
-- Safe to rerun: existing version-1 definitions and ruleset are preserved.
-- 'active' means approved for the first baseline; no engine has been fitted yet.
-- All basketball factors and unsupported soccer factors remain candidates.
BEGIN;

INSERT INTO matchlab.rulesets (code, sport, version, rules)
VALUES (
    'epl_regular_season', 'soccer', 1,
    '{"duration_minutes":90,"stoppage_time_included":true,"draw_allowed":true,"extra_time":false,"shootout":false}'::jsonb
)
ON CONFLICT (sport, code, version) DO NOTHING;

WITH catalog (code, title, direction, scope, dependency_group) AS (
    VALUES
    ('S01', 'Long-term attack strength', 'Opponent-adjusted scoring or chance production, shrunk toward league average.', 'team', 'team_scoring'),
    ('S02', 'Long-term defensive strength', 'Opponent-adjusted goals or chances conceded.', 'team', 'team_scoring'),
    ('S03', 'Recent chance creation', 'Time-weighted non-penalty xG per 90 from pre-match history.', 'team', 'team_scoring'),
    ('S04', 'Recent chance prevention', 'Time-weighted non-penalty xG conceded per 90.', 'team', 'team_scoring'),
    ('S05', 'Shot volume', 'Shots per possession or per 90.', 'team', 'team_scoring'),
    ('S06', 'Shot quality', 'xG per shot, accounting for overlap with S03 and S05.', 'team', 'team_scoring'),
    ('S07', 'Creation concentration', 'Share of chance creation attributable to likely available or absent players.', 'team', 'team_scoring'),
    ('S08', 'Chances conceded quality', 'Opponent shot quality, separated from volume where identifiable.', 'team', 'team_scoring'),
    ('S09', 'Finishing ability', 'Long-term player finishing residual with strong small-sample shrinkage.', 'player', 'team_scoring'),
    ('S10', 'Goalkeeping shot stopping', 'Post-shot goals prevented where reliable data exists.', 'player', 'team_scoring'),
    ('S11', 'Expected starting lineup', 'Valid combinations with supported availability probabilities.', 'fixture', 'roster_and_player'),
    ('S12', 'Attacker availability', 'Contribution relative to the actual replacement.', 'player', 'roster_and_player'),
    ('S13', 'Creator availability', 'Creation and progression relative to replacement.', 'player', 'roster_and_player'),
    ('S14', 'Defender availability', 'Defensive contribution and role relative to replacement.', 'player', 'roster_and_player'),
    ('S15', 'Goalkeeper availability', 'Starter versus replacement estimate.', 'player', 'roster_and_player'),
    ('S16', 'Expected playing time', 'Minutes conditional on lineup and substitution scenario.', 'player', 'roster_and_player'),
    ('S17', 'Bench attacking strength', 'Feasible substitutes and expected entry time.', 'team', 'roster_and_player'),
    ('S18', 'Bench defensive strength', 'Feasible defensive substitutions.', 'team', 'roster_and_player'),
    ('S19', 'Lineup continuity', 'Recent shared minutes, without unsupported “chemistry” scores.', 'team', 'roster_and_player'),
    ('S20', 'Individual creation form', 'Recent player creation blended with longer history.', 'player', 'roster_and_player'),
    ('S21', 'Individual progression', 'Possession value or progression, with overlap controls.', 'player', 'roster_and_player'),
    ('S22', 'One-on-one threat', 'Adjusted dribbling success and subsequent chance value.', 'player', 'roster_and_player'),
    ('S23', 'Set-piece attack', 'Chance creation per attacking set piece.', 'team', 'tactics_and_matchups'),
    ('S24', 'Set-piece defence', 'Chances conceded per defended set piece.', 'team', 'tactics_and_matchups'),
    ('S25', 'Aerial matchup', 'Relevant aerial contests and role or height data, if validated.', 'fixture', 'tactics_and_matchups'),
    ('S26', 'Transition attack', 'Chance production after turnovers.', 'team', 'tactics_and_matchups'),
    ('S27', 'Transition vulnerability', 'Chances conceded after lost possession.', 'team', 'tactics_and_matchups'),
    ('S28', 'Pressing intensity', 'Consistent pressing metric adjusted for game state.', 'team', 'tactics_and_matchups'),
    ('S29', 'Press resistance', 'Retention and progression under pressure.', 'team', 'tactics_and_matchups'),
    ('S30', 'Defensive line and space', 'Structured tactical or event proxy; inactive if unsupported.', 'team', 'tactics_and_matchups'),
    ('S31', 'Width and crossing matchup', 'Attacking preferences against opponent weaknesses.', 'team', 'tactics_and_matchups'),
    ('S32', 'Central access matchup', 'Central progression against opponent resistance.', 'team', 'tactics_and_matchups'),
    ('S33', 'Possession and tempo', 'Possession and attacking sequence characteristics.', 'team', 'tactics_and_matchups'),
    ('S34', 'Response to score', 'Historical changes when leading or trailing.', 'team', 'tactics_and_matchups'),
    ('S35', 'Manager or system change', 'Dated regime change with wider uncertainty until effects are established.', 'team', 'tactics_and_matchups'),
    ('S36', 'Home advantage', 'League-adjusted effect, distinguishing neutral venues.', 'fixture', 'venue_schedule_context'),
    ('S37', 'Home/away residual', 'Additional team effect only with enough data; avoid duplicating S36.', 'team', 'venue_schedule_context'),
    ('S38', 'Rest days', 'Time since the previous match.', 'team', 'venue_schedule_context'),
    ('S39', 'Recent workload', 'Team and player minutes over defined windows.', 'team', 'venue_schedule_context'),
    ('S40', 'Travel burden', 'Distance and relevant time-zone changes.', 'team', 'venue_schedule_context'),
    ('S41', 'Heat', 'Weather forecast available at the cutoff, not observed weather added later.', 'fixture', 'venue_schedule_context'),
    ('S42', 'Wind and rain', 'Supported forecast categories with calibrated effects.', 'fixture', 'venue_schedule_context'),
    ('S43', 'Altitude and surface', 'Venue facts and established effects only.', 'fixture', 'venue_schedule_context'),
    ('S44', 'Rotation context', 'Schedule and competition effects on the lineup distribution.', 'fixture', 'venue_schedule_context'),
    ('S45', 'Tie and competition state', 'Leg, aggregate score, and knockout or league incentives; no vague motivation rating.', 'fixture', 'venue_schedule_context'),
    ('S46', 'Red-card risk', 'Shrunk discipline event rate, not a predetermined red card.', 'team', 'events_and_interactions'),
    ('S47', 'Penalty risk', 'Supported foul and penalty event rates.', 'team', 'events_and_interactions'),
    ('S48', 'Referee tendency', 'Adjusted event rates if identity is known and sample adequate.', 'fixture', 'events_and_interactions'),
    ('S49', 'Attacker–opponent fit', 'Selected interactions beyond aggregate strength.', 'fixture', 'events_and_interactions'),
    ('S50', 'Defender–opponent fit', 'Selected interactions beyond aggregate strength.', 'fixture', 'events_and_interactions'),
    ('B01', 'Long-term offensive efficiency', 'Opponent-adjusted points per possession.', 'team', 'team_efficiency_and_possessions'),
    ('B02', 'Long-term defensive efficiency', 'Opponent-adjusted points conceded per possession.', 'team', 'team_efficiency_and_possessions'),
    ('B03', 'Recent offensive form', 'Time-weighted efficiency blended with long-term strength.', 'team', 'team_efficiency_and_possessions'),
    ('B04', 'Recent defensive form', 'Time-weighted defensive efficiency.', 'team', 'team_efficiency_and_possessions'),
    ('B05', 'Pace', 'Possessions per game adjusted for duration.', 'team', 'team_efficiency_and_possessions'),
    ('B06', 'Pace matchup', 'One shared expected possession count for both teams.', 'team', 'team_efficiency_and_possessions'),
    ('B07', 'Rim attempt share', 'Shot-location mix.', 'team', 'team_efficiency_and_possessions'),
    ('B08', 'Rim finishing', 'Shrunk player and team conversion estimates.', 'team', 'team_efficiency_and_possessions'),
    ('B09', 'Midrange attempt share', 'Shot-location mix.', 'team', 'team_efficiency_and_possessions'),
    ('B10', 'Midrange efficiency', 'Shrunk conversion estimate.', 'team', 'team_efficiency_and_possessions'),
    ('B11', 'Three-point attempt share', 'Shot-location mix.', 'team', 'team_efficiency_and_possessions'),
    ('B12', 'Three-point ability', 'Long-term estimate adjusted for players and roles.', 'team', 'team_efficiency_and_possessions'),
    ('B13', 'Free-throw attempt rate', 'Fouls and free-throw trips per possession.', 'team', 'team_efficiency_and_possessions'),
    ('B14', 'Free-throw accuracy', 'Expected shooters and conversion.', 'team', 'team_efficiency_and_possessions'),
    ('B15', 'Turnover rate', 'Turnovers per possession.', 'team', 'team_efficiency_and_possessions'),
    ('B16', 'Turnover pressure', 'Forced turnover rate adjusted for opponents.', 'team', 'team_efficiency_and_possessions'),
    ('B17', 'Offensive rebounding', 'Rebound probability conditional on a missed shot.', 'team', 'team_efficiency_and_possessions'),
    ('B18', 'Defensive rebounding', 'Opponent second-chance prevention.', 'team', 'team_efficiency_and_possessions'),
    ('B19', 'Transition attack', 'Frequency and efficiency.', 'team', 'team_efficiency_and_possessions'),
    ('B20', 'Transition defence', 'Allowed transition frequency and efficiency.', 'team', 'team_efficiency_and_possessions'),
    ('B21', 'Half-court attack', 'Half-court possession efficiency.', 'team', 'team_efficiency_and_possessions'),
    ('B22', 'Half-court defence', 'Half-court efficiency conceded.', 'team', 'team_efficiency_and_possessions'),
    ('B23', 'Rim protection', 'Opponent rim attempts and conversion suppression.', 'team', 'team_efficiency_and_possessions'),
    ('B24', 'Perimeter prevention', 'Allowed three-point quality and frequency.', 'team', 'team_efficiency_and_possessions'),
    ('B25', 'Pick-and-roll matchup', 'Validated play-type interaction.', 'fixture', 'play_type_and_lineup_fit'),
    ('B26', 'Switching mismatches', 'Supported lineup or play-type proxy.', 'fixture', 'play_type_and_lineup_fit'),
    ('B27', 'Spacing', 'Lineup shooting threat and role interaction.', 'team', 'play_type_and_lineup_fit'),
    ('B28', 'Ball movement', 'Creation and assist metrics without duplicating efficiency.', 'team', 'play_type_and_lineup_fit'),
    ('B29', 'Expected starting lineup', 'Feasible combinations under availability uncertainty.', 'fixture', 'roster_and_player'),
    ('B30', 'Star scorer availability', 'Contribution relative to replacement.', 'player', 'roster_and_player'),
    ('B31', 'Primary creator availability', 'Creation and usage redistribution.', 'player', 'roster_and_player'),
    ('B32', 'Defensive anchor availability', 'Rim, coverage, and rebounding replacement effect.', 'player', 'roster_and_player'),
    ('B33', 'Expected minutes', 'Valid roster minute allocation.', 'player', 'roster_and_player'),
    ('B34', 'Usage redistribution', 'Shot and creation shares when players are absent.', 'team', 'roster_and_player'),
    ('B35', 'Bench strength', 'Expected bench combinations and minutes.', 'team', 'roster_and_player'),
    ('B36', 'Lineup continuity', 'Shared minutes and uncertainty of new combinations.', 'team', 'roster_and_player'),
    ('B37', 'Individual scoring form', 'Recent performance blended with longer history.', 'player', 'roster_and_player'),
    ('B38', 'Individual creation form', 'Recent creation and turnover performance.', 'player', 'roster_and_player'),
    ('B39', 'Individual defence', 'Adjusted estimate acknowledging noisy attribution.', 'player', 'roster_and_player'),
    ('B40', 'Foul trouble risk', 'Player foul event rates and substitution effects.', 'player', 'roster_and_player'),
    ('B41', 'Home advantage', 'League-adjusted home effect.', 'fixture', 'venue_schedule_context'),
    ('B42', 'Rest days', 'Recovery interval.', 'team', 'venue_schedule_context'),
    ('B43', 'Back-to-back schedule', 'Dated indicator, accounting for overlap with rest.', 'team', 'venue_schedule_context'),
    ('B44', 'Recent minutes workload', 'Player workload over defined windows.', 'team', 'venue_schedule_context'),
    ('B45', 'Travel and time zones', 'Travel context known before tipoff.', 'team', 'venue_schedule_context'),
    ('B46', 'Altitude', 'Venue and acclimatisation context where supported.', 'fixture', 'venue_schedule_context'),
    ('B47', 'Rotation policy', 'Rest patterns, minute restrictions, and reliable announcements.', 'team', 'venue_schedule_context'),
    ('B48', 'Coach or system change', 'Regime indicator with wider uncertainty.', 'team', 'venue_schedule_context'),
    ('B49', 'Referee foul tendency', 'Adjusted crew effects if known and reliable.', 'fixture', 'venue_schedule_context'),
    ('B50', 'Late-game strategy', 'Intentional fouling, close-game use of possessions, and blowout substitutions.', 'team', 'venue_schedule_context')
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
        THEN '{"policy":"eligible_prior_EPL_results"}'::jsonb
        ELSE '{"status":"undefined_until_activation"}'::jsonb END,
    CASE WHEN code IN ('S01', 'S02')
        THEN '{"source":"football-data.org v4 PL final scores","horizon":"H24","historical_result_lag_hours":48}'::jsonb
        WHEN code = 'S36'
        THEN '{"source":"football-data.org v4 PL fixture home/away roles and prior final scores","horizon":"H24","historical_result_lag_hours":48}'::jsonb
        ELSE '{"status":"source_and_cutoff_not_approved"}'::jsonb END,
    CASE WHEN code IN ('S01', 'S02', 'S36')
        THEN '{"protocol":"EVALUATION_PROTOCOL_v1.md","status":"pending_engine_implementation"}'::jsonb
        ELSE '{"status":"not_implemented"}'::jsonb END,
    dependency_group,
    CASE WHEN code IN ('S01', 'S02') THEN 'prior' WHEN code = 'S36' THEN 'block' ELSE 'disable' END,
    CASE WHEN code IN ('S01', 'S02', 'S36')
        THEN '{"status":"to_be_estimated_with_baseline"}'::jsonb
        ELSE '{"status":"not_defined"}'::jsonb END,
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
