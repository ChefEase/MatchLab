-- Run the whole file after the Task 7 migration. All synthetic rows roll back.
BEGIN;

DO $test$
DECLARE
    v_match jsonb;
    v_outcome text;
    v_fixture uuid;
    v_original uuid;
    v_revision integer;
    v_provider uuid;
    v_seen timestamptz := now();
BEGIN
    PERFORM * FROM matchlab.fd_catalog(
        '{"id":987654321,"code":"PL","name":"Task 7 Test League"}'::jsonb,
        '[{"id":987654322,"name":"Task 7 Home",
           "squad":[{"id":987654325,"name":"Task 7 Player"}]},
          {"id":987654323,"name":"Task 7 Away"}]'::jsonb,
        v_seen
    );
    SELECT id INTO v_provider FROM matchlab.data_providers WHERE code = 'football-data-org-v4';
    IF NOT EXISTS (
        SELECT 1 FROM matchlab.provider_player_ids
        WHERE provider_id = v_provider AND external_id = '987654325'
    ) THEN
        RAISE EXCEPTION 'FAIL: supplied player ID was not mapped';
    END IF;
    v_match := jsonb_build_object(
        'id', 987654324, 'competition', jsonb_build_object('id', 987654321, 'code', 'PL'),
        'homeTeam', jsonb_build_object('id', 987654322),
        'awayTeam', jsonb_build_object('id', 987654323),
        'utcDate', '2026-11-01T15:00:00Z', 'status', 'SCHEDULED', 'venue', 'Test Ground',
        'lastUpdated', '2026-10-03T12:00:00Z'
    );

    SELECT outcome, fixture_id, revision_number
    INTO v_outcome, v_fixture, v_revision FROM matchlab.fd_fixture(v_match, v_seen);
    IF v_outcome <> 'created' OR v_revision <> 1 THEN
        RAISE EXCEPTION 'FAIL: initial fixture creation';
    END IF;
    v_original := v_fixture;

    SELECT outcome, fixture_id, revision_number
    INTO v_outcome, v_fixture, v_revision FROM matchlab.fd_fixture(v_match, v_seen);
    IF v_outcome <> 'unchanged' OR v_fixture <> v_original OR v_revision <> 1 THEN
        RAISE EXCEPTION 'FAIL: duplicate feed created another fixture or revision';
    END IF;
    IF (SELECT count(*) FROM matchlab.source_records
        WHERE provider_id = v_provider AND record_type = 'fixture'
          AND external_record_id = '987654324') <> 1 THEN
        RAISE EXCEPTION 'FAIL: duplicate source record';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM matchlab.source_records
        WHERE provider_id = v_provider AND external_record_id = '987654324'
          AND event_at = '2026-11-01T15:00:00Z'::timestamptz
          AND available_at = v_seen AND retrieved_at = v_seen AND published_at IS NULL
    ) THEN
        RAISE EXCEPTION 'FAIL: fixture provenance timestamps';
    END IF;

    v_match := jsonb_set(v_match, '{lastUpdated}', '"2026-10-03T13:00:00Z"'::jsonb);
    SELECT outcome, fixture_id, revision_number
    INTO v_outcome, v_fixture, v_revision FROM matchlab.fd_fixture(v_match, v_seen);
    IF v_outcome <> 'unchanged' OR v_revision <> 1 OR v_fixture <> v_original THEN
        RAISE EXCEPTION 'FAIL: irrelevant payload update changed the fixture revision';
    END IF;

    v_match := jsonb_set(v_match, '{utcDate}', '"2026-11-02T15:00:00Z"'::jsonb);
    SELECT outcome, fixture_id, revision_number
    INTO v_outcome, v_fixture, v_revision FROM matchlab.fd_fixture(v_match, v_seen);
    IF v_outcome <> 'revised' OR v_fixture <> v_original OR v_revision <> 2 THEN
        RAISE EXCEPTION 'FAIL: schedule correction did not version the fixture';
    END IF;
    IF (SELECT count(*) FROM matchlab.fixture_revisions WHERE fixture_id = v_original) <> 2 THEN
        RAISE EXCEPTION 'FAIL: earlier fixture revision was lost';
    END IF;

    v_match := jsonb_set(v_match, '{awayTeam,id}', '987654399'::jsonb);
    SELECT outcome INTO v_outcome FROM matchlab.fd_fixture(v_match, v_seen);
    IF v_outcome <> 'review_required' OR NOT EXISTS (
        SELECT 1 FROM matchlab.entity_mapping_reviews
        WHERE provider_id = v_provider AND entity_type = 'team'
          AND external_id = '987654399' AND fixture_external_id = '987654324'
          AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'FAIL: unmapped team did not enter review';
    END IF;
    IF (SELECT count(*) FROM matchlab.fixtures WHERE id = v_original) <> 1 THEN
        RAISE EXCEPTION 'FAIL: fixture duplicated after unknown team';
    END IF;
END;
$test$;

ROLLBACK;
SELECT 'PASS: replay, schedule revision, and unknown-team review' AS task7_smoke;
