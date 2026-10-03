-- MatchLab application schema for Supabase PostgreSQL 15+.
-- Supabase Auth owns credentials. MatchLab data is in a private, unexposed schema.
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA IF NOT EXISTS matchlab;
SET search_path TO matchlab, public, extensions;

CREATE TABLE app_users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
    role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'analyst', 'admin')),
    created_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE data_providers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    license_reference text,
    active boolean NOT NULL DEFAULT true
);

CREATE TABLE rulesets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL,
    sport text NOT NULL CHECK (sport IN ('soccer', 'basketball')),
    version integer NOT NULL CHECK (version > 0),
    rules jsonb NOT NULL CHECK (jsonb_typeof(rules) = 'object'),
    UNIQUE (sport, code, version)
);

CREATE TABLE competitions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sport text NOT NULL CHECK (sport IN ('soccer', 'basketball')),
    name text NOT NULL,
    country text,
    ruleset_id uuid NOT NULL REFERENCES rulesets(id),
    coverage_status text NOT NULL DEFAULT 'experimental'
        CHECK (coverage_status IN ('supported', 'experimental', 'unsupported')),
    active boolean NOT NULL DEFAULT true
);

CREATE TABLE provider_coverage (
    provider_id uuid NOT NULL REFERENCES data_providers(id),
    competition_id uuid NOT NULL REFERENCES competitions(id),
    data_category text NOT NULL,
    historical_from date,
    live_available boolean NOT NULL DEFAULT false,
    expected_delay_minutes integer CHECK (expected_delay_minutes >= 0),
    permitted_use text NOT NULL,
    checked_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (provider_id, competition_id, data_category)
);

CREATE TABLE teams (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sport text NOT NULL CHECK (sport IN ('soccer', 'basketball')),
    name text NOT NULL,
    short_name text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE players (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sport text NOT NULL CHECK (sport IN ('soccer', 'basketball')),
    name text NOT NULL,
    birth_date date,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE team_memberships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id uuid NOT NULL REFERENCES players(id),
    team_id uuid NOT NULL REFERENCES teams(id),
    valid_from date NOT NULL,
    valid_to date,
    source_record_id uuid,
    CHECK (valid_to IS NULL OR valid_to >= valid_from),
    UNIQUE (player_id, team_id, valid_from)
);

CREATE TABLE provider_competition_ids (
    provider_id uuid NOT NULL REFERENCES data_providers(id),
    external_id text NOT NULL,
    competition_id uuid NOT NULL REFERENCES competitions(id),
    PRIMARY KEY (provider_id, external_id),
    UNIQUE (provider_id, competition_id)
);

CREATE TABLE provider_team_ids (
    provider_id uuid NOT NULL REFERENCES data_providers(id),
    external_id text NOT NULL,
    team_id uuid NOT NULL REFERENCES teams(id),
    PRIMARY KEY (provider_id, external_id),
    UNIQUE (provider_id, team_id)
);

CREATE TABLE provider_player_ids (
    provider_id uuid NOT NULL REFERENCES data_providers(id),
    external_id text NOT NULL,
    player_id uuid NOT NULL REFERENCES players(id),
    PRIMARY KEY (provider_id, external_id),
    UNIQUE (provider_id, player_id)
);

CREATE TABLE fixtures (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id uuid NOT NULL REFERENCES competitions(id),
    home_team_id uuid NOT NULL REFERENCES teams(id),
    away_team_id uuid NOT NULL REFERENCES teams(id),
    ruleset_id uuid NOT NULL REFERENCES rulesets(id),
    scheduled_at timestamptz NOT NULL,
    venue_name text,
    neutral_venue boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'in_progress', 'completed', 'postponed', 'cancelled', 'abandoned')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (home_team_id <> away_team_id)
);

CREATE TABLE provider_fixture_ids (
    provider_id uuid NOT NULL REFERENCES data_providers(id),
    external_id text NOT NULL,
    fixture_id uuid NOT NULL REFERENCES fixtures(id),
    PRIMARY KEY (provider_id, external_id),
    UNIQUE (provider_id, fixture_id)
);

CREATE TABLE source_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id uuid NOT NULL REFERENCES data_providers(id),
    external_record_id text NOT NULL,
    record_type text NOT NULL,
    revision text NOT NULL,
    source_url text,
    event_at timestamptz,
    published_at timestamptz,
    available_at timestamptz,
    retrieved_at timestamptz NOT NULL DEFAULT now(),
    payload_hash text NOT NULL,
    payload jsonb,
    artifact_uri text,
    UNIQUE (provider_id, external_record_id, revision)
);

ALTER TABLE team_memberships ADD CONSTRAINT team_memberships_source_fk
    FOREIGN KEY (source_record_id) REFERENCES source_records(id);

CREATE TABLE fixture_revisions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id uuid NOT NULL REFERENCES fixtures(id),
    source_record_id uuid NOT NULL UNIQUE REFERENCES source_records(id),
    revision_number integer NOT NULL CHECK (revision_number > 0),
    scheduled_at timestamptz NOT NULL,
    status text NOT NULL CHECK (status IN ('scheduled', 'in_progress', 'completed', 'postponed', 'cancelled', 'abandoned')),
    venue_name text,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (fixture_id, revision_number)
);

CREATE TABLE observed_results (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id uuid NOT NULL REFERENCES fixtures(id),
    source_record_id uuid NOT NULL UNIQUE REFERENCES source_records(id),
    revision_number integer NOT NULL CHECK (revision_number > 0),
    result_status text NOT NULL CHECK (result_status IN ('provisional', 'confirmed', 'void')),
    home_score integer NOT NULL CHECK (home_score >= 0),
    away_score integer NOT NULL CHECK (away_score >= 0),
    regulation_home_score integer CHECK (regulation_home_score >= 0),
    regulation_away_score integer CHECK (regulation_away_score >= 0),
    overtime_count integer NOT NULL DEFAULT 0 CHECK (overtime_count >= 0),
    recorded_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (fixture_id, revision_number),
    CHECK ((regulation_home_score IS NULL) = (regulation_away_score IS NULL))
);

CREATE TABLE match_statistics (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id uuid NOT NULL REFERENCES fixtures(id),
    team_id uuid REFERENCES teams(id),
    player_id uuid REFERENCES players(id),
    source_record_id uuid NOT NULL REFERENCES source_records(id),
    stat_code text NOT NULL,
    value numeric NOT NULL,
    unit text NOT NULL,
    period text NOT NULL DEFAULT 'full_game',
    status text NOT NULL CHECK (status IN ('complete', 'partial', 'corrected')),
    CHECK (num_nonnulls(team_id, player_id) = 1),
    UNIQUE NULLS NOT DISTINCT (source_record_id, fixture_id, team_id, player_id, stat_code, period)
);

CREATE TABLE research_claims (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id uuid REFERENCES fixtures(id),
    team_id uuid REFERENCES teams(id),
    player_id uuid REFERENCES players(id),
    claim_type text NOT NULL,
    extracted_value jsonb NOT NULL,
    rubric_version text NOT NULL,
    review_status text NOT NULL DEFAULT 'pending'
        CHECK (review_status IN ('pending', 'approved', 'rejected', 'conflict')),
    available_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (num_nonnulls(fixture_id, team_id, player_id) = 1)
);

CREATE TABLE research_claim_sources (
    claim_id uuid NOT NULL REFERENCES research_claims(id),
    source_record_id uuid NOT NULL REFERENCES source_records(id),
    PRIMARY KEY (claim_id, source_record_id)
);

CREATE TABLE feature_definitions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL,
    version integer NOT NULL CHECK (version > 0),
    sport text NOT NULL CHECK (sport IN ('soccer', 'basketball')),
    definition text NOT NULL,
    unit text,
    scope text NOT NULL CHECK (scope IN ('fixture', 'team', 'player')),
    lookback jsonb NOT NULL DEFAULT '{}'::jsonb,
    availability_rule jsonb NOT NULL DEFAULT '{}'::jsonb,
    transformation jsonb NOT NULL DEFAULT '{}'::jsonb,
    dependency_group text NOT NULL,
    missing_policy text NOT NULL CHECK (missing_policy IN ('prior', 'disable', 'block')),
    uncertainty_method jsonb NOT NULL DEFAULT '{}'::jsonb,
    lifecycle text NOT NULL DEFAULT 'candidate'
        CHECK (lifecycle IN ('candidate', 'experimental', 'active', 'retired')),
    UNIQUE (code, version),
    CHECK ((sport = 'soccer' AND code ~ '^S[0-9]{2}$') OR
           (sport = 'basketball' AND code ~ '^B[0-9]{2}$'))
);

CREATE TABLE coefficient_artifacts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sport text NOT NULL CHECK (sport IN ('soccer', 'basketball')),
    artifact_uri text NOT NULL,
    sha256 text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    training_cutoff timestamptz,
    rationale_uri text
);

CREATE TABLE engine_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sport text NOT NULL CHECK (sport IN ('soccer', 'basketball')),
    version text NOT NULL,
    code_revision text NOT NULL,
    coefficient_artifact_id uuid NOT NULL REFERENCES coefficient_artifacts(id),
    transform_version text NOT NULL,
    rng_name text NOT NULL,
    rng_version text NOT NULL,
    model_config jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (sport, version)
);

CREATE TABLE engine_features (
    engine_version_id uuid NOT NULL REFERENCES engine_versions(id),
    feature_definition_id uuid NOT NULL REFERENCES feature_definitions(id),
    enabled boolean NOT NULL,
    PRIMARY KEY (engine_version_id, feature_definition_id)
);

CREATE TABLE active_engines (
    competition_id uuid PRIMARY KEY REFERENCES competitions(id),
    engine_version_id uuid NOT NULL REFERENCES engine_versions(id),
    activated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE derived_states (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    feature_definition_id uuid NOT NULL REFERENCES feature_definitions(id),
    team_id uuid REFERENCES teams(id),
    player_id uuid REFERENCES players(id),
    as_of timestamptz NOT NULL,
    data_cutoff timestamptz NOT NULL,
    value jsonb NOT NULL,
    uncertainty jsonb NOT NULL DEFAULT '{}'::jsonb,
    calculation_version text NOT NULL,
    input_manifest_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (num_nonnulls(team_id, player_id) = 1),
    CHECK (data_cutoff <= as_of),
    UNIQUE NULLS NOT DISTINCT (feature_definition_id, team_id, player_id, as_of, calculation_version, input_manifest_hash)
);

CREATE TABLE evidence_snapshots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id uuid NOT NULL REFERENCES fixtures(id),
    cutoff_at timestamptz NOT NULL,
    lineup_status text NOT NULL CHECK (lineup_status IN ('unknown', 'projected', 'confirmed')),
    completeness_status text NOT NULL CHECK (completeness_status IN ('complete', 'partial', 'blocked')),
    content_hash text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (created_at >= cutoff_at)
);

CREATE TABLE snapshot_features (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_id uuid NOT NULL REFERENCES evidence_snapshots(id),
    feature_definition_id uuid NOT NULL REFERENCES feature_definitions(id),
    fixture_id uuid REFERENCES fixtures(id),
    team_id uuid REFERENCES teams(id),
    player_id uuid REFERENCES players(id),
    raw_value jsonb,
    transformed_value jsonb,
    unit text,
    status text NOT NULL CHECK (status IN ('observed', 'estimated', 'imputed', 'unavailable', 'conflict', 'experimental')),
    uncertainty jsonb NOT NULL DEFAULT '{}'::jsonb,
    available_at timestamptz,
    retrieved_at timestamptz,
    transform_version text,
    CHECK (num_nonnulls(fixture_id, team_id, player_id) = 1),
    UNIQUE NULLS NOT DISTINCT (snapshot_id, feature_definition_id, fixture_id, team_id, player_id)
);

CREATE TABLE snapshot_feature_sources (
    snapshot_feature_id uuid NOT NULL REFERENCES snapshot_features(id),
    source_record_id uuid NOT NULL REFERENCES source_records(id),
    PRIMARY KEY (snapshot_feature_id, source_record_id)
);

CREATE TABLE scenario_overlays (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id uuid NOT NULL REFERENCES app_users(id),
    base_snapshot_id uuid NOT NULL REFERENCES evidence_snapshots(id),
    title text,
    overlay jsonb NOT NULL CHECK (jsonb_typeof(overlay) = 'object'),
    content_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (owner_user_id, base_snapshot_id, content_hash)
);

CREATE TABLE simulation_jobs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id uuid NOT NULL REFERENCES fixtures(id),
    snapshot_id uuid NOT NULL REFERENCES evidence_snapshots(id),
    engine_version_id uuid NOT NULL REFERENCES engine_versions(id),
    scenario_id uuid REFERENCES scenario_overlays(id),
    requested_by_user_id uuid REFERENCES app_users(id),
    kind text NOT NULL CHECK (kind IN ('official', 'scenario', 'shadow')),
    mode text NOT NULL CHECK (mode IN ('quick', 'deep')),
    target_runs bigint NOT NULL CHECK (target_runs IN (10000, 1000000)),
    completed_runs bigint NOT NULL DEFAULT 0 CHECK (completed_runs >= 0 AND completed_runs <= target_runs),
    root_seed text NOT NULL,
    cache_key text NOT NULL UNIQUE,
    continuation_of_job_id uuid REFERENCES simulation_jobs(id),
    status text NOT NULL DEFAULT 'preparing'
        CHECK (status IN ('preparing', 'queued', 'running', 'aggregating', 'completed', 'failed', 'cancel_requested', 'cancelled')),
    lease_owner text,
    lease_expires_at timestamptz,
    checkpoint_uri text,
    error_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    CHECK ((kind = 'scenario') = (scenario_id IS NOT NULL)),
    CHECK (kind <> 'scenario' OR requested_by_user_id IS NOT NULL),
    CHECK (mode <> 'quick' OR continuation_of_job_id IS NULL)
);

CREATE TABLE api_idempotency_keys (
    user_id uuid NOT NULL REFERENCES app_users(id),
    request_key text NOT NULL,
    job_id uuid NOT NULL REFERENCES simulation_jobs(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, request_key)
);

CREATE TABLE simulation_batches (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id uuid NOT NULL REFERENCES simulation_jobs(id),
    first_run bigint NOT NULL CHECK (first_run >= 0),
    run_count integer NOT NULL CHECK (run_count > 0),
    result_hash text NOT NULL,
    aggregate jsonb NOT NULL CHECK (jsonb_typeof(aggregate) = 'object'),
    committed_at timestamptz NOT NULL DEFAULT now(),
    EXCLUDE USING gist (job_id WITH =, int8range(first_run, first_run + run_count, '[)') WITH &&)
);

CREATE TABLE forecast_reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id uuid NOT NULL UNIQUE REFERENCES simulation_jobs(id),
    fixture_id uuid NOT NULL REFERENCES fixtures(id),
    snapshot_id uuid NOT NULL REFERENCES evidence_snapshots(id),
    engine_version_id uuid NOT NULL REFERENCES engine_versions(id),
    scenario_id uuid REFERENCES scenario_overlays(id),
    kind text NOT NULL CHECK (kind IN ('official', 'scenario', 'shadow')),
    scope text NOT NULL,
    forecast_horizon text NOT NULL,
    completed_runs bigint NOT NULL CHECK (completed_runs > 0),
    root_seed text NOT NULL,
    summary_schema_version integer NOT NULL CHECK (summary_schema_version > 0),
    summary jsonb NOT NULL CHECK (jsonb_typeof(summary) = 'object'),
    artifact_uri text,
    published_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((kind = 'scenario') = (scenario_id IS NOT NULL))
);

CREATE TABLE forecast_score_counts (
    report_id uuid NOT NULL REFERENCES forecast_reports(id),
    home_score integer NOT NULL CHECK (home_score >= 0),
    away_score integer NOT NULL CHECK (away_score >= 0),
    sample_count bigint NOT NULL CHECK (sample_count > 0),
    PRIMARY KEY (report_id, home_score, away_score)
);

CREATE TABLE forecast_distribution_bins (
    report_id uuid NOT NULL REFERENCES forecast_reports(id),
    metric text NOT NULL CHECK (metric IN ('home_score', 'away_score', 'total', 'margin')),
    bin_lower numeric NOT NULL,
    bin_upper numeric NOT NULL,
    sample_count bigint NOT NULL CHECK (sample_count >= 0),
    PRIMARY KEY (report_id, metric, bin_lower, bin_upper),
    CHECK (bin_upper > bin_lower)
);

CREATE TABLE forecast_settlements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id uuid NOT NULL REFERENCES forecast_reports(id),
    observed_result_id uuid NOT NULL REFERENCES observed_results(id),
    metrics jsonb NOT NULL CHECK (jsonb_typeof(metrics) = 'object'),
    settled_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (report_id, observed_result_id)
);

CREATE TABLE evaluation_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id uuid NOT NULL REFERENCES competitions(id),
    engine_version_id uuid NOT NULL REFERENCES engine_versions(id),
    kind text NOT NULL CHECK (kind IN ('historical', 'prospective', 'shadow')),
    horizon text NOT NULL,
    period_start timestamptz NOT NULL,
    period_end timestamptz NOT NULL,
    inclusion_rules jsonb NOT NULL,
    benchmark jsonb,
    aggregate_metrics jsonb NOT NULL,
    coverage jsonb NOT NULL,
    artifact_uri text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (period_end > period_start)
);

CREATE TABLE evaluation_items (
    evaluation_run_id uuid NOT NULL REFERENCES evaluation_runs(id),
    fixture_id uuid NOT NULL REFERENCES fixtures(id),
    report_id uuid REFERENCES forecast_reports(id),
    settlement_id uuid REFERENCES forecast_settlements(id),
    inclusion_status text NOT NULL CHECK (inclusion_status IN ('included', 'excluded', 'missing')),
    reason text,
    PRIMARY KEY (evaluation_run_id, fixture_id),
    CHECK (inclusion_status <> 'included' OR report_id IS NOT NULL)
);

CREATE TABLE saved_teams (
    user_id uuid NOT NULL REFERENCES app_users(id),
    team_id uuid NOT NULL REFERENCES teams(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, team_id)
);

CREATE TABLE saved_fixtures (
    user_id uuid NOT NULL REFERENCES app_users(id),
    fixture_id uuid NOT NULL REFERENCES fixtures(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, fixture_id)
);

CREATE TABLE saved_forecasts (
    user_id uuid NOT NULL REFERENCES app_users(id),
    report_id uuid NOT NULL REFERENCES forecast_reports(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, report_id)
);

CREATE TABLE saved_scenarios (
    user_id uuid NOT NULL REFERENCES app_users(id),
    scenario_id uuid NOT NULL REFERENCES scenario_overlays(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, scenario_id)
);

CREATE TABLE ingestion_cursors (
    provider_id uuid NOT NULL REFERENCES data_providers(id),
    stream_name text NOT NULL,
    cursor_value text,
    watermark_at timestamptz,
    last_success_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (provider_id, stream_name)
);

CREATE TABLE ingestion_batches (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id uuid NOT NULL REFERENCES data_providers(id),
    stream_name text NOT NULL,
    requested_fixture_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
    received_fixture_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
    status text NOT NULL CHECK (status IN ('running', 'complete', 'partial', 'failed')),
    error_code text,
    started_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    CHECK (jsonb_typeof(requested_fixture_ids) = 'array'),
    CHECK (jsonb_typeof(received_fixture_ids) = 'array')
);

CREATE TABLE pipeline_jobs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    kind text NOT NULL CHECK (kind IN ('fixture_sync', 'result_fetch', 'stats_retry', 'reconcile', 'refresh_state', 'build_snapshot', 'settle', 'fit_candidate', 'evaluate', 'promote', 'rollback')),
    idempotency_key text NOT NULL UNIQUE,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'running', 'completed', 'failed', 'cancelled')),
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    lease_owner text,
    lease_expires_at timestamptz,
    error_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE promotion_policies (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id uuid NOT NULL REFERENCES competitions(id),
    version integer NOT NULL CHECK (version > 0),
    minimum_new_matches integer NOT NULL CHECK (minimum_new_matches > 0),
    minimum_validation_matches integer NOT NULL CHECK (minimum_validation_matches > 0),
    primary_metric text NOT NULL,
    minimum_improvement numeric NOT NULL,
    maximum_allowed_regressions jsonb NOT NULL,
    shadow_minimum_matches integer NOT NULL CHECK (shadow_minimum_matches > 0),
    data_quality_thresholds jsonb NOT NULL,
    rollback_triggers jsonb NOT NULL,
    enabled boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (competition_id, version)
);

CREATE TABLE learning_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id uuid NOT NULL REFERENCES competitions(id),
    policy_id uuid NOT NULL REFERENCES promotion_policies(id),
    incumbent_engine_id uuid NOT NULL REFERENCES engine_versions(id),
    candidate_engine_id uuid REFERENCES engine_versions(id),
    data_cutoff timestamptz NOT NULL,
    fit_start timestamptz NOT NULL,
    fit_end timestamptz NOT NULL,
    validation_start timestamptz NOT NULL,
    validation_end timestamptz NOT NULL,
    input_manifest_uri text,
    input_manifest_hash text,
    offline_metrics jsonb,
    shadow_metrics jsonb,
    status text NOT NULL CHECK (status IN ('skipped', 'fitting', 'offline_rejected', 'shadow', 'shadow_rejected', 'promoted', 'failed')),
    decision_reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    CHECK (fit_start < fit_end AND fit_end <= validation_start AND validation_start < validation_end),
    CHECK (validation_end <= data_cutoff)
);

CREATE TABLE engine_promotion_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id uuid NOT NULL REFERENCES competitions(id),
    learning_run_id uuid REFERENCES learning_runs(id),
    previous_engine_id uuid NOT NULL REFERENCES engine_versions(id),
    next_engine_id uuid NOT NULL REFERENCES engine_versions(id),
    event_type text NOT NULL CHECK (event_type IN ('promotion', 'rollback', 'manual_release')),
    reason text NOT NULL,
    affected_forecast_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    CHECK (previous_engine_id <> next_engine_id),
    CHECK (jsonb_typeof(affected_forecast_ids) = 'array')
);

CREATE INDEX fixtures_competition_schedule_idx ON fixtures (competition_id, scheduled_at);
CREATE INDEX fixtures_status_schedule_idx ON fixtures (status, scheduled_at);
CREATE INDEX fixture_revisions_fixture_idx ON fixture_revisions (fixture_id, revision_number DESC);
CREATE INDEX observed_results_fixture_idx ON observed_results (fixture_id, revision_number DESC);
CREATE INDEX source_records_availability_idx ON source_records (available_at, provider_id);
CREATE INDEX match_statistics_fixture_idx ON match_statistics (fixture_id, stat_code);
CREATE INDEX research_claims_review_idx ON research_claims (review_status, created_at);
CREATE INDEX derived_states_team_idx ON derived_states (team_id, feature_definition_id, as_of DESC) WHERE team_id IS NOT NULL;
CREATE INDEX derived_states_player_idx ON derived_states (player_id, feature_definition_id, as_of DESC) WHERE player_id IS NOT NULL;
CREATE INDEX snapshots_fixture_cutoff_idx ON evidence_snapshots (fixture_id, cutoff_at DESC);
CREATE INDEX scenario_owner_idx ON scenario_overlays (owner_user_id, created_at DESC);
CREATE INDEX simulation_jobs_status_idx ON simulation_jobs (status, created_at);
CREATE INDEX simulation_jobs_fixture_idx ON simulation_jobs (fixture_id, created_at DESC);
CREATE INDEX reports_fixture_published_idx ON forecast_reports (fixture_id, published_at DESC);
CREATE INDEX reports_snapshot_engine_idx ON forecast_reports (snapshot_id, engine_version_id);
CREATE INDEX evaluation_items_report_idx ON evaluation_items (report_id);
CREATE INDEX pipeline_jobs_claim_idx ON pipeline_jobs (status, next_attempt_at) WHERE status IN ('queued', 'failed');
CREATE INDEX learning_runs_competition_idx ON learning_runs (competition_id, created_at DESC);

-- Browser roles use Supabase Auth only. Application data is accessed by the
-- trusted Next.js API and Python worker through server-side DB connections.
REVOKE ALL ON SCHEMA matchlab FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA matchlab FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA matchlab FROM PUBLIC, anon, authenticated;
