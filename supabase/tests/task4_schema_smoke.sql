-- Task 4 smoke test. Run the whole file in the Supabase SQL Editor.
-- All test rows are rolled back. A real Auth user must exist for the optional
-- Auth-to-app_users check; create one through Supabase Auth, not auth.users SQL.
BEGIN;

DO $test$
DECLARE
    test_auth_user_id uuid;
    test_ruleset_id uuid;
    test_competition_id uuid;
    test_home_id uuid;
    test_away_id uuid;
    test_fixture_id uuid;
    test_snapshot_id uuid;
    test_artifact_id uuid;
    test_engine_id uuid;
    test_job_id uuid;
    test_report_id uuid;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'matchlab') THEN
        RAISE EXCEPTION 'FAIL: matchlab schema is missing';
    END IF;

    IF has_schema_privilege('anon', 'matchlab', 'USAGE')
        OR has_schema_privilege('authenticated', 'matchlab', 'USAGE') THEN
        RAISE EXCEPTION 'FAIL: a browser role can use the matchlab schema';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_class AS c
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'matchlab'
          AND c.relkind IN ('r', 'p', 'v', 'm')
          AND (
              has_table_privilege('anon', c.oid, 'SELECT')
              OR has_table_privilege('anon', c.oid, 'INSERT')
              OR has_table_privilege('authenticated', c.oid, 'SELECT')
              OR has_table_privilege('authenticated', c.oid, 'INSERT')
          )
    ) THEN
        RAISE EXCEPTION 'FAIL: a browser role has app-table access';
    END IF;
    RAISE NOTICE 'PASS: anon and authenticated cannot use the private schema or read/write its tables';

    SELECT id INTO test_auth_user_id FROM auth.users ORDER BY created_at DESC LIMIT 1;
    IF test_auth_user_id IS NULL THEN
        RAISE NOTICE 'SKIP: Auth-to-app_users check; create a test user through Supabase Auth and rerun';
    ELSE
        INSERT INTO matchlab.app_users (id) VALUES (test_auth_user_id)
        ON CONFLICT (id) DO NOTHING;
        IF NOT EXISTS (SELECT 1 FROM matchlab.app_users WHERE id = test_auth_user_id) THEN
            RAISE EXCEPTION 'FAIL: Auth user cannot be read from app_users';
        END IF;
        RAISE NOTICE 'PASS: existing Auth user can be linked and read from app_users';
    END IF;

    INSERT INTO matchlab.rulesets (code, sport, version, rules)
    VALUES ('task4_smoke', 'soccer', 1, '{}') RETURNING id INTO test_ruleset_id;

    INSERT INTO matchlab.competitions (sport, name, ruleset_id)
    VALUES ('soccer', 'Task 4 smoke', test_ruleset_id) RETURNING id INTO test_competition_id;

    INSERT INTO matchlab.teams (sport, name)
    VALUES ('soccer', 'Task 4 home') RETURNING id INTO test_home_id;
    INSERT INTO matchlab.teams (sport, name)
    VALUES ('soccer', 'Task 4 away') RETURNING id INTO test_away_id;

    INSERT INTO matchlab.fixtures
        (competition_id, home_team_id, away_team_id, ruleset_id, scheduled_at)
    VALUES
        (test_competition_id, test_home_id, test_away_id, test_ruleset_id, now() + interval '1 day')
    RETURNING id INTO test_fixture_id;

    IF NOT EXISTS (SELECT 1 FROM matchlab.fixtures WHERE id = test_fixture_id) THEN
        RAISE EXCEPTION 'FAIL: fixture insert/read';
    END IF;
    RAISE NOTICE 'PASS: fixture insert/read';

    INSERT INTO matchlab.evidence_snapshots
        (fixture_id, cutoff_at, lineup_status, completeness_status, content_hash)
    VALUES
        (test_fixture_id, now() - interval '1 day', 'unknown', 'partial', gen_random_uuid()::text)
    RETURNING id INTO test_snapshot_id;

    IF NOT EXISTS (SELECT 1 FROM matchlab.evidence_snapshots WHERE id = test_snapshot_id) THEN
        RAISE EXCEPTION 'FAIL: snapshot insert/read';
    END IF;
    RAISE NOTICE 'PASS: snapshot insert/read';

    INSERT INTO matchlab.coefficient_artifacts (sport, artifact_uri, sha256)
    VALUES ('soccer', 'smoke://task4', md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text))
    RETURNING id INTO test_artifact_id;

    INSERT INTO matchlab.engine_versions
        (sport, version, code_revision, coefficient_artifact_id, transform_version, rng_name, rng_version)
    VALUES
        ('soccer', 'task4-' || gen_random_uuid()::text, 'smoke', test_artifact_id, 'smoke', 'smoke', '1')
    RETURNING id INTO test_engine_id;

    INSERT INTO matchlab.simulation_jobs
        (fixture_id, snapshot_id, engine_version_id, kind, mode, target_runs, root_seed, cache_key)
    VALUES
        (test_fixture_id, test_snapshot_id, test_engine_id, 'official', 'quick', 10000, 'smoke', gen_random_uuid()::text)
    RETURNING id INTO test_job_id;

    IF NOT EXISTS (SELECT 1 FROM matchlab.simulation_jobs WHERE id = test_job_id) THEN
        RAISE EXCEPTION 'FAIL: job insert/read';
    END IF;
    RAISE NOTICE 'PASS: job insert/read';

    INSERT INTO matchlab.forecast_reports
        (job_id, fixture_id, snapshot_id, engine_version_id, kind, scope, forecast_horizon,
         completed_runs, root_seed, summary_schema_version, summary)
    VALUES
        (test_job_id, test_fixture_id, test_snapshot_id, test_engine_id, 'official',
         'soccer_regulation', 'H24', 10000, 'smoke', 1, '{}')
    RETURNING id INTO test_report_id;

    IF NOT EXISTS (SELECT 1 FROM matchlab.forecast_reports WHERE id = test_report_id) THEN
        RAISE EXCEPTION 'FAIL: report insert/read';
    END IF;
    RAISE NOTICE 'PASS: report insert/read';
END;
$test$;

ROLLBACK;

-- The SQL Editor commonly shows only the last statement's result. This row
-- appears only after the assertions above completed without an exception.
SELECT
    'PASS: fixture, snapshot, job, report, and private-role checks' AS smoke_test,
    CASE WHEN EXISTS (SELECT 1 FROM auth.users)
        THEN 'PASS: Auth user link checked'
        ELSE 'SKIP: create a test Auth user and rerun'
    END AS auth_user_check;
