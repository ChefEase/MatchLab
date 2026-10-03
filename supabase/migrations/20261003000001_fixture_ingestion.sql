-- Task 7. Run after 20261003000000_initial.sql and the EPL ruleset seed.
-- Provider payloads are retained as source records; first retrieval is the
-- conservative availability time. Provider lastUpdated is not first-seen time.
CREATE TABLE matchlab.entity_mapping_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id uuid NOT NULL REFERENCES matchlab.data_providers(id),
    entity_type text NOT NULL CHECK (entity_type IN ('competition', 'team', 'player', 'fixture')),
    external_id text NOT NULL,
    fixture_external_id text NOT NULL DEFAULT '',
    reason text NOT NULL,
    source_record_id uuid REFERENCES matchlab.source_records(id),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'rejected')),
    first_seen_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL,
    UNIQUE (provider_id, entity_type, external_id, fixture_external_id, reason)
);

REVOKE ALL ON matchlab.entity_mapping_reviews FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION matchlab.fd_source_record(
    p_provider_id uuid, p_type text, p_external_id text, p_payload jsonb,
    p_event_at timestamptz, p_seen_at timestamptz
) RETURNS uuid LANGUAGE plpgsql SET search_path = matchlab, public AS $$
DECLARE v_id uuid; v_hash text;
BEGIN
    v_hash := md5(p_payload::text);
    INSERT INTO source_records
        (provider_id, external_record_id, record_type, revision, source_url,
         event_at, available_at, retrieved_at, payload_hash, payload)
    VALUES
        (p_provider_id, p_external_id, p_type, v_hash,
         'https://api.football-data.org/v4/' ||
             CASE p_type WHEN 'fixture' THEN 'matches/' WHEN 'team' THEN 'teams/' WHEN 'player' THEN 'persons/' ELSE 'competitions/' END || p_external_id,
         p_event_at, p_seen_at, p_seen_at, v_hash, p_payload)
    ON CONFLICT (provider_id, external_record_id, revision)
    DO UPDATE SET external_record_id = EXCLUDED.external_record_id
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION matchlab.fd_catalog(
    p_competition jsonb, p_teams jsonb, p_seen_at timestamptz
) RETURNS TABLE(competition_id uuid, team_count integer, player_count integer)
LANGUAGE plpgsql SET search_path = matchlab, public AS $$
DECLARE
    v_provider uuid; v_ruleset uuid; v_competition uuid; v_team uuid; v_player uuid;
    v_comp_external text; v_team_external text; v_player_external text;
    v_team_row jsonb; v_player_row jsonb;
    v_teams integer := 0; v_players integer := 0;
BEGIN
    IF p_competition->>'code' IS DISTINCT FROM 'PL'
       OR jsonb_typeof(p_teams) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Expected EPL competition and team array';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended('fd_catalog:PL', 0));
    v_comp_external := p_competition->>'id';
    IF v_comp_external IS NULL OR v_comp_external !~ '^[0-9]+$' THEN
        RAISE EXCEPTION 'Missing provider competition ID';
    END IF;
    SELECT id INTO v_ruleset FROM rulesets
    WHERE sport = 'soccer' AND code = 'epl_regular_season' AND version = 1;
    IF v_ruleset IS NULL THEN RAISE EXCEPTION 'EPL ruleset seed is missing'; END IF;
    INSERT INTO data_providers (code, name, license_reference)
    VALUES ('football-data-org-v4', 'football-data.org v4', 'DATA_PROVIDER_DECISION.md')
    ON CONFLICT (code) DO UPDATE SET code = EXCLUDED.code RETURNING id INTO v_provider;
    PERFORM fd_source_record(v_provider, 'competition', v_comp_external, p_competition, NULL, p_seen_at);
    SELECT pc.competition_id INTO v_competition FROM provider_competition_ids pc
    WHERE pc.provider_id = v_provider AND pc.external_id = v_comp_external;
    IF v_competition IS NULL THEN
        INSERT INTO competitions (sport, name, country, ruleset_id, coverage_status)
        VALUES ('soccer', p_competition->>'name', 'England', v_ruleset, 'supported')
        RETURNING id INTO v_competition;
        INSERT INTO provider_competition_ids VALUES (v_provider, v_comp_external, v_competition);
    END IF;
    FOR v_team_row IN SELECT value FROM jsonb_array_elements(p_teams) LOOP
        v_team_external := v_team_row->>'id';
        IF v_team_external IS NULL OR v_team_external !~ '^[0-9]+$'
           OR NULLIF(v_team_row->>'name', '') IS NULL THEN
            RAISE EXCEPTION 'Invalid team in EPL catalog';
        END IF;
        PERFORM fd_source_record(v_provider, 'team', v_team_external, v_team_row, NULL, p_seen_at);
        SELECT pt.team_id INTO v_team FROM provider_team_ids pt
        WHERE pt.provider_id = v_provider AND pt.external_id = v_team_external;
        IF v_team IS NULL THEN
            INSERT INTO teams (sport, name, short_name)
            VALUES ('soccer', v_team_row->>'name', v_team_row->>'shortName')
            RETURNING id INTO v_team;
            INSERT INTO provider_team_ids VALUES (v_provider, v_team_external, v_team);
        END IF;
        v_teams := v_teams + 1;
        -- Squad is optional on this provider tier. Never invent absent players.
        IF jsonb_typeof(v_team_row->'squad') = 'array' THEN
            FOR v_player_row IN SELECT value FROM jsonb_array_elements(v_team_row->'squad') LOOP
                v_player_external := v_player_row->>'id';
                IF v_player_external IS NULL OR v_player_external !~ '^[0-9]+$'
                   OR NULLIF(v_player_row->>'name', '') IS NULL THEN CONTINUE; END IF;
                PERFORM fd_source_record(v_provider, 'player', v_player_external, v_player_row, NULL, p_seen_at);
                SELECT pp.player_id INTO v_player FROM provider_player_ids pp
                WHERE pp.provider_id = v_provider AND pp.external_id = v_player_external;
                IF v_player IS NULL THEN
                    INSERT INTO players (sport, name)
                    VALUES ('soccer', v_player_row->>'name') RETURNING id INTO v_player;
                    INSERT INTO provider_player_ids VALUES (v_provider, v_player_external, v_player);
                END IF;
                v_players := v_players + 1;
            END LOOP;
        END IF;
    END LOOP;
    RETURN QUERY SELECT v_competition, v_teams, v_players;
END;
$$;

CREATE OR REPLACE FUNCTION matchlab.fd_fixture(p_match jsonb, p_seen_at timestamptz)
RETURNS TABLE(outcome text, fixture_id uuid, revision_number integer)
LANGUAGE plpgsql SET search_path = matchlab, public AS $$
DECLARE
    v_provider uuid; v_source uuid; v_competition uuid; v_home uuid; v_away uuid;
    v_ruleset uuid; v_fixture uuid; v_external text; v_comp_external text;
    v_home_external text; v_away_external text; v_kickoff timestamptz;
    v_status text; v_venue text; v_prior matchlab.fixtures%ROWTYPE; v_rev integer;
BEGIN
    SELECT id INTO v_provider FROM data_providers WHERE code = 'football-data-org-v4';
    IF v_provider IS NULL THEN RAISE EXCEPTION 'Run fd_catalog before fixtures'; END IF;
    v_external := p_match->>'id';
    v_comp_external := p_match->'competition'->>'id';
    v_home_external := p_match->'homeTeam'->>'id';
    v_away_external := p_match->'awayTeam'->>'id';
    IF v_external IS NULL OR v_external !~ '^[0-9]+$'
       OR v_comp_external IS NULL OR v_comp_external !~ '^[0-9]+$'
       OR NULLIF(p_match->>'utcDate', '') IS NULL THEN
        RAISE EXCEPTION 'Invalid fixture identity or kickoff';
    END IF;
    IF p_match->'competition'->>'code' IS DISTINCT FROM 'PL' THEN
        RAISE EXCEPTION 'Expected an EPL fixture';
    END IF;
    v_kickoff := (p_match->>'utcDate')::timestamptz;
    v_status := CASE p_match->>'status'
        WHEN 'SCHEDULED' THEN 'scheduled' WHEN 'TIMED' THEN 'scheduled'
        WHEN 'LIVE' THEN 'in_progress' WHEN 'IN_PLAY' THEN 'in_progress'
        WHEN 'PAUSED' THEN 'in_progress' WHEN 'FINISHED' THEN 'completed'
        WHEN 'POSTPONED' THEN 'postponed' WHEN 'CANCELLED' THEN 'cancelled'
        ELSE NULL END;
    v_venue := NULLIF(p_match->>'venue', '');
    PERFORM pg_advisory_xact_lock(hashtextextended(v_provider::text || ':' || v_external, 0));
    v_source := fd_source_record(v_provider, 'fixture', v_external, p_match, v_kickoff, p_seen_at);
    IF v_status IS NULL THEN
        INSERT INTO entity_mapping_reviews
            (provider_id, entity_type, external_id, fixture_external_id, reason,
             source_record_id, first_seen_at, last_seen_at)
        VALUES (v_provider, 'fixture', v_external, v_external, 'unsupported_status',
                v_source, p_seen_at, p_seen_at)
        ON CONFLICT (provider_id, entity_type, external_id, fixture_external_id, reason)
        DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at,
            source_record_id = EXCLUDED.source_record_id, status = 'pending';
        RETURN QUERY SELECT 'review_required'::text, NULL::uuid, NULL::integer;
        RETURN;
    END IF;
    SELECT pc.competition_id INTO v_competition FROM provider_competition_ids pc
    WHERE pc.provider_id = v_provider AND pc.external_id = v_comp_external;
    SELECT pt.team_id INTO v_home FROM provider_team_ids pt
    WHERE pt.provider_id = v_provider AND pt.external_id = v_home_external;
    SELECT pt.team_id INTO v_away FROM provider_team_ids pt
    WHERE pt.provider_id = v_provider AND pt.external_id = v_away_external;
    IF v_competition IS NULL OR v_home IS NULL OR v_away IS NULL OR v_home = v_away THEN
        IF v_competition IS NULL THEN
            INSERT INTO entity_mapping_reviews
                (provider_id, entity_type, external_id, fixture_external_id, reason,
                 source_record_id, first_seen_at, last_seen_at)
            VALUES (v_provider, 'competition', v_comp_external, v_external, 'unmapped_competition',
                    v_source, p_seen_at, p_seen_at)
            ON CONFLICT (provider_id, entity_type, external_id, fixture_external_id, reason)
            DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at,
                source_record_id = EXCLUDED.source_record_id, status = 'pending';
        END IF;
        IF v_home IS NULL AND v_home_external IS NOT NULL THEN
            INSERT INTO entity_mapping_reviews
                (provider_id, entity_type, external_id, fixture_external_id, reason,
                 source_record_id, first_seen_at, last_seen_at)
            VALUES (v_provider, 'team', v_home_external, v_external, 'unmapped_home_team',
                    v_source, p_seen_at, p_seen_at)
            ON CONFLICT (provider_id, entity_type, external_id, fixture_external_id, reason)
            DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at,
                source_record_id = EXCLUDED.source_record_id, status = 'pending';
        END IF;
        IF v_away IS NULL AND v_away_external IS NOT NULL THEN
            INSERT INTO entity_mapping_reviews
                (provider_id, entity_type, external_id, fixture_external_id, reason,
                 source_record_id, first_seen_at, last_seen_at)
            VALUES (v_provider, 'team', v_away_external, v_external, 'unmapped_away_team',
                    v_source, p_seen_at, p_seen_at)
            ON CONFLICT (provider_id, entity_type, external_id, fixture_external_id, reason)
            DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at,
                source_record_id = EXCLUDED.source_record_id, status = 'pending';
        END IF;
        IF v_home_external IS NULL OR v_away_external IS NULL OR v_home = v_away THEN
            INSERT INTO entity_mapping_reviews
                (provider_id, entity_type, external_id, fixture_external_id, reason,
                 source_record_id, first_seen_at, last_seen_at)
            VALUES (v_provider, 'fixture', v_external, v_external, 'unmapped_or_invalid_teams',
                    v_source, p_seen_at, p_seen_at)
            ON CONFLICT (provider_id, entity_type, external_id, fixture_external_id, reason)
            DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at,
                source_record_id = EXCLUDED.source_record_id, status = 'pending';
        END IF;
        RETURN QUERY SELECT 'review_required'::text, NULL::uuid, NULL::integer;
        RETURN;
    END IF;
    UPDATE entity_mapping_reviews SET status = 'resolved', last_seen_at = p_seen_at
    WHERE provider_id = v_provider AND fixture_external_id = v_external
      AND status = 'pending'
      AND reason IN ('unmapped_competition', 'unmapped_home_team',
                     'unmapped_away_team', 'unmapped_or_invalid_teams', 'unsupported_status');
    SELECT c.ruleset_id INTO v_ruleset FROM competitions c WHERE c.id = v_competition;
    SELECT pf.fixture_id INTO v_fixture FROM provider_fixture_ids pf
    WHERE pf.provider_id = v_provider AND pf.external_id = v_external;
    IF v_fixture IS NULL THEN
        INSERT INTO fixtures
            (competition_id, home_team_id, away_team_id, ruleset_id, scheduled_at, venue_name, status)
        VALUES (v_competition, v_home, v_away, v_ruleset, v_kickoff, v_venue, v_status)
        RETURNING id INTO v_fixture;
        INSERT INTO provider_fixture_ids VALUES (v_provider, v_external, v_fixture);
        INSERT INTO fixture_revisions
            (fixture_id, source_record_id, revision_number, scheduled_at, status, venue_name)
        VALUES (v_fixture, v_source, 1, v_kickoff, v_status, v_venue);
        RETURN QUERY SELECT 'created'::text, v_fixture, 1;
        RETURN;
    END IF;
    SELECT * INTO v_prior FROM fixtures WHERE id = v_fixture FOR UPDATE;
    IF (v_prior.competition_id, v_prior.home_team_id, v_prior.away_team_id)
       IS DISTINCT FROM (v_competition, v_home, v_away) THEN
        INSERT INTO entity_mapping_reviews
            (provider_id, entity_type, external_id, fixture_external_id, reason,
             source_record_id, first_seen_at, last_seen_at)
        VALUES (v_provider, 'fixture', v_external, v_external, 'mapped_identity_changed',
                v_source, p_seen_at, p_seen_at)
        ON CONFLICT (provider_id, entity_type, external_id, fixture_external_id, reason)
        DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at,
            source_record_id = EXCLUDED.source_record_id, status = 'pending';
        RETURN QUERY SELECT 'review_required'::text, v_fixture, NULL::integer;
        RETURN;
    END IF;
    IF (v_prior.scheduled_at, v_prior.status, v_prior.venue_name)
       IS NOT DISTINCT FROM (v_kickoff, v_status, v_venue) THEN
        RETURN QUERY SELECT 'unchanged'::text, v_fixture,
            (SELECT max(fr.revision_number) FROM fixture_revisions fr WHERE fr.fixture_id = v_fixture);
        RETURN;
    END IF;
    SELECT coalesce(max(fr.revision_number), 0) + 1 INTO v_rev FROM fixture_revisions fr
    WHERE fr.fixture_id = v_fixture;
    UPDATE fixtures SET scheduled_at = v_kickoff, status = v_status,
        venue_name = v_venue, updated_at = p_seen_at WHERE id = v_fixture;
    INSERT INTO fixture_revisions
        (fixture_id, source_record_id, revision_number, scheduled_at, status, venue_name)
    VALUES (v_fixture, v_source, v_rev, v_kickoff, v_status, v_venue);
    RETURN QUERY SELECT 'revised'::text, v_fixture, v_rev;
END;
$$;

-- Keep all ingestion functions server-only, even if a future API setting changes.
REVOKE ALL ON FUNCTION matchlab.fd_source_record(uuid,text,text,jsonb,timestamptz,timestamptz)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION matchlab.fd_catalog(jsonb,jsonb,timestamptz)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION matchlab.fd_fixture(jsonb,timestamptz)
    FROM PUBLIC, anon, authenticated;
