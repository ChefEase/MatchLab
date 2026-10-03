# MatchLab: Product and Engineering Specification

**Working title:** MatchLab (name availability unverified)  
**Version:** 1.0 — 3 October 2026  
**Audience:** Product design, frontend, backend, data, and forecasting teams  
**Status:** Implementation specification and experiment plan. No prediction engine has been built or tested for this document, and no accuracy claim is made.

**Developer context:** The proposed repository layout and full Supabase PostgreSQL schema are in [CONTEXT.md](CONTEXT.md), with executable DDL in [supabase/migrations/20261003000000_initial.sql](supabase/migrations/20261003000000_initial.sql).

## 1. Product overview

MatchLab is a responsive web app for forecasting soccer and basketball games. A user selects a scheduled match, inspects the evidence available before it begins, and views outcome probabilities and score distributions. The user can then change a supported assumption, such as a player's availability, and compare that scenario with the official forecast. After the match, the app records how the forecast performed.

The proposed approach is to:

1. Define roughly 50 candidate conditions for each sport.
2. Use AI for constrained research, extraction, and explanation.
3. Apply developer controlled, versioned mathematical rules to the resulting inputs.
4. Run 10,000 simulated matches for the initial forecast.
5. Offer a deeper run of up to 1,000,000 total simulations for more precise estimates of the model's probabilities.
6. Make inputs, assumptions, calculations, and historical performance inspectable.

The numerical engine owns the forecast. AI assists with evidence; it does not choose the winner or write a distinct story for every simulation.

### What a simulation represents

Each run draws a plausible set of uncertain pre-match conditions, then samples match events or scores under that scenario. The exact mechanics depend on the sport engine and its version.

- **Fixed facts stay fixed:** teams, venue, known suspensions, and competition rules.
- **Uncertain inputs vary within supported distributions:** projected lineups, playing time, performance estimates, and tempo.
- **Dependent inputs remain consistent:** an absent player receives no minutes, and both basketball teams share the same possession count.
- **Outcomes may repeat:** identical scenarios and scores are valid observations. Never discard or deduplicate them.

If a 2–1 score occurs in 1,240 of 10,000 runs, its estimated probability is 12.4%. More runs reduce Monte Carlo sampling noise; they cannot fix poor data, flawed rules, or unpredictable real events. The interface must explain that distinction.

## 2. Scope and release plan

### Long-term scope

- Separate soccer and basketball engines behind shared application contracts.
- Approximately 50 defined candidate conditions per sport, activated only when supported.
- Evidence backed forecasts, outcome and score distributions, and quick and deep simulation modes.
- Lineup and condition scenarios, saved content, and a public performance record.

### First usable release

Build the shared web flow for **one selected soccer league** first. Basketball follows through the same app contracts with its own rules and engine. The first release includes:

- Real scheduled fixtures from an approved source.
- A simple, explainable baseline engine using only reliable conditions.
- An evidence panel that distinguishes active, unavailable, and experimental factors.
- A 10,000-run forecast and an asynchronous option for 1,000,000 total runs.
- Immutable forecasts, result settlement, and an evaluation dashboard.
- A small scenario editor for valid player availability and lineup changes.

The feature registry can contain all 50 conditions from the start. A condition becomes active only after its measurement, effect, uncertainty, and validation are implemented. Do not invent values to fill a “50/50” display.

### Deferred

Live forecasting; full event or possession level engines; broadcast video analysis; arbitrary historical or cross-era fixtures; social leagues; wagering, payments, and subscriptions; and native mobile apps. The initial product provides forecasts and analysis, not bets or guaranteed returns.

## 3. Users and access

| Role | Capabilities |
| --- | --- |
| Guest | Browse fixtures and published forecasts; inspect methodology and public performance. |
| Registered user | Save teams and matches; request permitted simulations; create private scenarios; view personal history. |
| Analyst or admin | Review research, resolve entity conflicts, approve factors, run evaluations, and manage competitions. |
| Background worker | Ingest data, create snapshots, run simulations, aggregate results, and settle outcomes. |

Viewing a published forecast does not require registration. Persistent personal scenarios and costly user requested jobs require an account. Admin controls require separate authorization.

## 4. Navigation and routes

Primary navigation: **Matches**, **Saved**, **My scenarios**, **Track record**, and **How it works**. Admin navigation is separate.

| Route | Purpose |
| --- | --- |
| `/` | Product introduction and upcoming matches. |
| `/matches?sport=soccer&date=...&league=...` | Filtered fixture list. |
| `/matches/:matchId` | Fixture details and latest eligible forecast. |
| `/forecasts/:forecastId` | Immutable forecast report. |
| `/matches/:matchId/scenarios/new` | Scenario editor. |
| `/scenarios/:scenarioId` | Private scenario report. |
| `/saved` | Personal saved content. |
| `/track-record` | Official forecast performance. |
| `/methodology` | Plain language methodology and limits. |
| `/admin/research` | Evidence review queue. |
| `/admin/evaluations` | Offline testing and release gates. |

Persist filters in URL parameters. A forecast link always resolves to a specific version, even when newer evidence becomes available.

## 5. Core user flows

### Find a match

1. Select a sport, league, and date.
2. Browse fixture cards showing teams, local start time, match status, and forecast availability.
3. Open a fixture to inspect evidence status, lineup status, and the latest forecast.
4. Open an existing forecast or request a 10,000-run forecast.

Reuse a completed forecast or active job with the same inputs. A second click must not trigger duplicate work.

### Run and refine a forecast

1. Validate the fixture, user permissions, data freshness, and supported engine.
2. If retrievable evidence is missing, start an acquisition job and show **Updating match information**.
3. Freeze a versioned evidence snapshot with a prediction cutoff.
4. Validate active factors and construct parameter distributions.
5. Queue the simulation and return a job ID.
6. Show actual states: **preparing**, **queued**, **running**, **aggregating**, **completed**, or **failed**.
7. Open the immutable report when complete.
8. Optionally extend the run to 1,000,000 total simulations.

Where the engine supports continuation, deep mode extends the same indexed random sample sequence. Keep the original 10,000-run artifact. Every panel in a report must use the same snapshot, engine version, and completed run count.

### Compare assumptions

1. Open **Change assumptions** from a forecast.
2. Copy the baseline snapshot into a private scenario overlay.
3. Change a supported input, such as a doubtful player to unavailable.
4. Label the edit **Your assumption** and validate lineup and minute constraints.
5. Recalculate dependent inputs, simulate the alternative, and show changes in outcome probability and score distributions.
6. Save or discard the scenario.

Personal assumptions never overwrite source evidence or official forecasts. Exclude scenario runs from the official track record.

### Review the result

After a result is confirmed under the correct ruleset, settle the official forecast. Show the original forecast, actual score, score error, and how common the observed outcome was under the forecast distribution. Label any post-match explanation as retrospective; it cannot modify the prediction.

## 6. Screen requirements

### Fixture list and match overview

Each fixture card shows sport, league, teams, local start time, status, and a compact preview when available. Soccer previews include draw probability. Basketball previews state whether overtime is included. Support sport, league, date, and followed-team filters, plus team search using internal IDs. Distinguish **no fixtures**, **unsupported competition**, and **provider unavailable** empty states.

The match page shows venue, competition, local start time, market scope, evidence update time, prediction cutoff, confirmed or projected lineup status, factor status, the primary forecast action, and links to current and prior official versions. Soccer scope is regulation plus stoppage time. Basketball scope is the full game including overtime by default.

Do not display an undefined “AI confidence” score. Data completeness, Monte Carlo precision, and forecast uncertainty are different measures.

### Forecast report

- **Outcome:** Home/draw/away probabilities for soccer; home/away for basketball. Show one decimal place by default and provide accessible labels. “Favourite” means highest model probability, not certainty.
- **Scores:** Expected goals or points, leading integer scorelines, and score distributions. Explain that a fractional expected score is an average, not a literal possible score. For basketball, prioritise margin and total distributions over a huge exact-score table.
- **Ranges:** Configurable central 50% and 80% *prediction intervals*, labelled by team score, total, or margin. Distinguish these from confidence intervals on estimated probabilities. Separate team intervals do not imply the same joint coverage.
- **Soccer score matrix:** Home goals by away goals, with an overflow category beyond displayed bounds and an accessible data table. Keep high-scoring runs in the calculations.
- **Sparse exact scores:** Display counts and sampling uncertainty for rare basketball scores; do not imply a stable ranking from a few occurrences.
- **Influences:** A short list of quantified engine sensitivities that AI may explain in prose. Label them model sensitivities, not proven causal effects. Do not add interacting effects as though they were independent.
- **Evidence:** Expandable factors with value, unit, measurement period, source, source time, retrieval time, status, and uncertainty.
- **Run details:** An expandable section with simulation count, snapshot ID, engine version, seed reference, and completion time.

### Scenario editor

Initially support eligible player availability, valid alternative starting lineups, and expected minutes within sport-specific constraints. Add predefined tactical, venue, or weather scenarios only when the engine can model them. Avoid arbitrary “increase team power” sliders.

Use equal run counts and matched random streams for comparisons where practical. Differences remain conditional on the model; they are not proof that an intervention would cause the same real-world effect.

### Saved content and track record

Users can follow teams, save fixtures, and revisit scenarios. Show badges for newer evidence or a newer forecast without silently replacing a saved version. Notifications can follow later with user opt-in.

The public track record shows evaluation period, sport, league, sample size, forecast horizon, engine version, inclusion rules, predictions, outcomes, and downloadable aggregate results where data rights permit. Separate chronological historical tests from prospectively published forecasts, and projected-lineup forecasts from confirmed-lineup forecasts. Exclude personal scenarios.

## 7. Data and evidence pipeline

### Sources and timestamps

Use approved structured feeds for fixtures, results, player statistics, injuries, lineups, and relevant events. Use authoritative team or competition reports for context when needed. Choose providers after checking coverage, historical availability, timestamp quality, commercial rights, and access to the same factors for both training and future inference.

Every record needs internal and provider entity IDs, event time, publication or availability time where known, retrieval time, and a source reference. Version schedule changes and corrected results. Store times in UTC; render them in the user's timezone.

### AI's role

AI may extract supported claims from retrieved sources, propose entity matches for validation, classify evidence against a versioned rubric, flag research gaps, and explain engine outputs using supplied evidence.

AI must not invent statistics or source URLs, set coefficients during a forecast, treat self-reported confidence as a calibrated probability, make per-simulation calls, use post-cutoff evidence in historical tests, change fixed facts to make runs differ, or produce numbers that contradict the engine.

Treat external pages as untrusted data. Ignore instructions embedded in them. Validate extraction against a strict schema containing only approved fields. Conflicting sources create a conflict or review state under a documented policy.

### Factor contract

Define each active factor through five separate components:

1. **Measurement:** observed statistic or rubric classification.
2. **Transformation:** normalisation, time decay, shrinkage, and opponent adjustment.
3. **Effect:** coefficient or rule connecting the transformed value to model parameters.
4. **Uncertainty:** unknown quantities and their sampling method.
5. **Evidence:** source records and rationale for the effect.

General research can support a hypothesis, such as home advantage, but it does not justify an arbitrary universal multiplier. Estimate or defensibly specify effects for the relevant sport, league, and outcome, then evaluate them on unseen games.

## 8. Candidate factor registries

These are **candidate inputs**, not independent bonuses. Several may inform one group estimate, and some are alternatives. A factor requires a source and historical validation before activation.

Registry fields: `feature_id`, definition, unit, scope, lookback, availability cutoff, transformation, dependency group, missing-data policy, uncertainty method, and enabled engine versions.

### Soccer: 50 candidate conditions

| ID | Condition | Measurement or implementation direction |
| --- | --- | --- |
| S01 | Long-term attack strength | Opponent-adjusted scoring or chance production, shrunk toward league average. |
| S02 | Long-term defensive strength | Opponent-adjusted goals or chances conceded. |
| S03 | Recent chance creation | Time-weighted non-penalty xG per 90 from pre-match history. |
| S04 | Recent chance prevention | Time-weighted non-penalty xG conceded per 90. |
| S05 | Shot volume | Shots per possession or per 90. |
| S06 | Shot quality | xG per shot, accounting for overlap with S03 and S05. |
| S07 | Creation concentration | Share of chance creation attributable to likely available or absent players. |
| S08 | Chances conceded quality | Opponent shot quality, separated from volume where identifiable. |
| S09 | Finishing ability | Long-term player finishing residual with strong small-sample shrinkage. |
| S10 | Goalkeeping shot stopping | Post-shot goals prevented where reliable data exists. |
| S11 | Expected starting lineup | Valid combinations with supported availability probabilities. |
| S12 | Attacker availability | Contribution relative to the actual replacement. |
| S13 | Creator availability | Creation and progression relative to replacement. |
| S14 | Defender availability | Defensive contribution and role relative to replacement. |
| S15 | Goalkeeper availability | Starter versus replacement estimate. |
| S16 | Expected playing time | Minutes conditional on lineup and substitution scenario. |
| S17 | Bench attacking strength | Feasible substitutes and expected entry time. |
| S18 | Bench defensive strength | Feasible defensive substitutions. |
| S19 | Lineup continuity | Recent shared minutes, without unsupported “chemistry” scores. |
| S20 | Individual creation form | Recent player creation blended with longer history. |
| S21 | Individual progression | Possession value or progression, with overlap controls. |
| S22 | One-on-one threat | Adjusted dribbling success and subsequent chance value. |
| S23 | Set-piece attack | Chance creation per attacking set piece. |
| S24 | Set-piece defence | Chances conceded per defended set piece. |
| S25 | Aerial matchup | Relevant aerial contests and role or height data, if validated. |
| S26 | Transition attack | Chance production after turnovers. |
| S27 | Transition vulnerability | Chances conceded after lost possession. |
| S28 | Pressing intensity | Consistent pressing metric adjusted for game state. |
| S29 | Press resistance | Retention and progression under pressure. |
| S30 | Defensive line and space | Structured tactical or event proxy; inactive if unsupported. |
| S31 | Width and crossing matchup | Attacking preferences against opponent weaknesses. |
| S32 | Central access matchup | Central progression against opponent resistance. |
| S33 | Possession and tempo | Possession and attacking sequence characteristics. |
| S34 | Response to score | Historical changes when leading or trailing. |
| S35 | Manager or system change | Dated regime change with wider uncertainty until effects are established. |
| S36 | Home advantage | League-adjusted effect, distinguishing neutral venues. |
| S37 | Home/away residual | Additional team effect only with enough data; avoid duplicating S36. |
| S38 | Rest days | Time since the previous match. |
| S39 | Recent workload | Team and player minutes over defined windows. |
| S40 | Travel burden | Distance and relevant time-zone changes. |
| S41 | Heat | Weather forecast available at the cutoff, not observed weather added later. |
| S42 | Wind and rain | Supported forecast categories with calibrated effects. |
| S43 | Altitude and surface | Venue facts and established effects only. |
| S44 | Rotation context | Schedule and competition effects on the lineup distribution. |
| S45 | Tie and competition state | Leg, aggregate score, and knockout or league incentives; no vague motivation rating. |
| S46 | Red-card risk | Shrunk discipline event rate, not a predetermined red card. |
| S47 | Penalty risk | Supported foul and penalty event rates. |
| S48 | Referee tendency | Adjusted event rates if identity is known and sample adequate. |
| S49 | Attacker–opponent fit | Selected interactions beyond aggregate strength. |
| S50 | Defender–opponent fit | Selected interactions beyond aggregate strength. |

### Basketball: 50 candidate conditions

The NBA is the initial basketball target. Other leagues require separate rules, timings, and baselines.

| ID | Condition | Measurement or implementation direction |
| --- | --- | --- |
| B01 | Long-term offensive efficiency | Opponent-adjusted points per possession. |
| B02 | Long-term defensive efficiency | Opponent-adjusted points conceded per possession. |
| B03 | Recent offensive form | Time-weighted efficiency blended with long-term strength. |
| B04 | Recent defensive form | Time-weighted defensive efficiency. |
| B05 | Pace | Possessions per game adjusted for duration. |
| B06 | Pace matchup | One shared expected possession count for both teams. |
| B07 | Rim attempt share | Shot-location mix. |
| B08 | Rim finishing | Shrunk player and team conversion estimates. |
| B09 | Midrange attempt share | Shot-location mix. |
| B10 | Midrange efficiency | Shrunk conversion estimate. |
| B11 | Three-point attempt share | Shot-location mix. |
| B12 | Three-point ability | Long-term estimate adjusted for players and roles. |
| B13 | Free-throw attempt rate | Fouls and free-throw trips per possession. |
| B14 | Free-throw accuracy | Expected shooters and conversion. |
| B15 | Turnover rate | Turnovers per possession. |
| B16 | Turnover pressure | Forced turnover rate adjusted for opponents. |
| B17 | Offensive rebounding | Rebound probability conditional on a missed shot. |
| B18 | Defensive rebounding | Opponent second-chance prevention. |
| B19 | Transition attack | Frequency and efficiency. |
| B20 | Transition defence | Allowed transition frequency and efficiency. |
| B21 | Half-court attack | Half-court possession efficiency. |
| B22 | Half-court defence | Half-court efficiency conceded. |
| B23 | Rim protection | Opponent rim attempts and conversion suppression. |
| B24 | Perimeter prevention | Allowed three-point quality and frequency. |
| B25 | Pick-and-roll matchup | Validated play-type interaction. |
| B26 | Switching mismatches | Supported lineup or play-type proxy. |
| B27 | Spacing | Lineup shooting threat and role interaction. |
| B28 | Ball movement | Creation and assist metrics without duplicating efficiency. |
| B29 | Expected starting lineup | Feasible combinations under availability uncertainty. |
| B30 | Star scorer availability | Contribution relative to replacement. |
| B31 | Primary creator availability | Creation and usage redistribution. |
| B32 | Defensive anchor availability | Rim, coverage, and rebounding replacement effect. |
| B33 | Expected minutes | Valid roster minute allocation. |
| B34 | Usage redistribution | Shot and creation shares when players are absent. |
| B35 | Bench strength | Expected bench combinations and minutes. |
| B36 | Lineup continuity | Shared minutes and uncertainty of new combinations. |
| B37 | Individual scoring form | Recent performance blended with longer history. |
| B38 | Individual creation form | Recent creation and turnover performance. |
| B39 | Individual defence | Adjusted estimate acknowledging noisy attribution. |
| B40 | Foul trouble risk | Player foul event rates and substitution effects. |
| B41 | Home advantage | League-adjusted home effect. |
| B42 | Rest days | Recovery interval. |
| B43 | Back-to-back schedule | Dated indicator, accounting for overlap with rest. |
| B44 | Recent minutes workload | Player workload over defined windows. |
| B45 | Travel and time zones | Travel context known before tipoff. |
| B46 | Altitude | Venue and acclimatisation context where supported. |
| B47 | Rotation policy | Rest patterns, minute restrictions, and reliable announcements. |
| B48 | Coach or system change | Regime indicator with wider uncertainty. |
| B49 | Referee foul tendency | Adjusted crew effects if known and reliable. |
| B50 | Late-game strategy | Intentional fouling, close-game use of possessions, and blowout substitutions. |

### Registry rules

- Define lookback windows in configuration and select them using training and validation data.
- Store raw and transformed values; avoid hiding inputs behind arbitrary ratings out of 100.
- Fit standardisation on past training data and freeze transformations per engine version.
- Shrink unstable estimates toward documented population values.
- Never treat missing data as zero. Use an explicit prior, disable the factor, or block the forecast according to its importance.
- Require evidence for tactical labels and news extraction. Exclude vague “desire,” “aura,” or “must win” bonuses.
- Use ablation by dependency group to find redundant or harmful factors.

## 9. Forecasting engines

### Engine tiers

**Tier A — baseline:** Start with simple, testable sport-specific score distributions and a small number of identifiable effects. It supports the full product flow and establishes a benchmark.

**Tier B — richer simulation:** Add player, tactical, and event-level mechanics only when they improve held-out forecasting or support validated scenario analysis. Version every addition. A dependency graph must specify where each factor enters so related inputs are not counted in both score parameters and event adjustments.

### Soccer baseline

A possible starting model is:

```text
log(lambda_home) = league_intercept + home_effect
                 + attack_home - defence_away
                 + approved_context_home

log(lambda_away) = league_intercept
                 + attack_away - defence_home
                 + approved_context_away
```

Higher defensive strength lowers the opponent's expected goals. Exponentiation keeps scoring rates positive. Every term needs a defined scale and coefficient; raw xG, rest days, and ratings cannot simply be added together.

Begin with independent Poisson scores as a deliberately simple benchmark. Evaluate a properly normalised low-score dependence correction or another joint distribution before adopting it. The baseline is a scoring model, not a full tactical match simulation.

If parameter uncertainty is supported, draw strengths from an estimated joint distribution, calculate scoring rates for that scenario, then sample scores. If parameters are fixed, use the analytic distribution to verify the Monte Carlo result. Later event-level versions may model chances, substitutions, cards, and score-dependent behaviour; they must remain coherent and pass the same evaluation gates.

### Basketball baseline

Estimate a shared expected possession count and each team's points per possession from adjusted strengths, roster, and approved context:

```text
mean_home_points = expected_possessions * expected_home_points_per_possession
mean_away_points = expected_possessions * expected_away_points_per_possession
```

Fit a joint residual distribution using earlier games so scores retain realistic variance and correlation. Use a documented method for converting draws to nonnegative integer scores. For a full-game forecast, simulate overtime after a regulation tie until a winner exists.

A later possession engine may simulate turnovers, shot types, shooting fouls, makes, free throws, rebounds, and clock use. It must account correctly for offensive rebounds and fouls within possessions. Validate roster minutes against five players times regulation duration, plus overtime. NBA regulation is 240 player-minutes per team; keep league rules in configuration.

### Coefficients and versioning

- Store coefficient sets and transformations as immutable, versioned artifacts.
- Fit effects on historical data or label initial research-informed values as provisional.
- Keep functional rules explicit even when coefficients are fitted statistically.
- Use regularisation, shrinkage, and limited predeclared interactions.
- Never let an AI model silently edit coefficients for an individual match.
- Retire factors that fail validation or cannot be observed at prediction time.

## 10. Simulation design

### Three uncertainty layers

1. **Fixed match facts:** teams, venue, rules, and confirmed information.
2. **Unknown pre-match conditions and parameters:** sampled from a specified joint scenario distribution.
3. **Match randomness:** events or scores sampled conditional on that scenario.

Different seeds alone do not justify arbitrary parameter changes. Specify and estimate distribution families, variance, correlations, and constraints. The report must say which layers the current engine includes.

### Algorithm contract

```python
def simulate(snapshot, engine, scenario_overlay, target_count, root_seed):
    validated = validate_and_resolve(snapshot, scenario_overlay)
    scenario_distribution = engine.build_scenario_distribution(validated)
    accumulator = restore_checkpoint_or_create()

    for run_index in range(accumulator.completed, target_count):
        rng = make_indexed_random_stream(root_seed, run_index)
        scenario = scenario_distribution.sample(rng)
        engine.validate_scenario(scenario)

        parameters = engine.calculate_parameters(scenario)
        result = engine.sample_match(parameters, scenario, rng)
        engine.validate_result(result)
        accumulator.add(result)

        if checkpoint_due(run_index):
            persist_checkpoint_and_progress(accumulator)

    return engine.summarise(accumulator)
```

Use a supported RNG with deterministic indexed substreams, not time-based seeds. Give parallel workers disjoint run-index ranges and record the RNG implementation and version needed for reproduction.

Construct valid scenarios directly when possible. If rejection sampling is necessary, define the target distribution and rejection rules, monitor rejection rates, and fail after persistent invalidity. Never reject a valid but inconvenient score.

| Mode | Run count | Purpose |
| --- | ---: | --- |
| Quick | 10,000 | Initial outcome and score distribution. |
| Deep | 1,000,000 total | Lower Monte Carlo noise, including for scoreline probabilities. |

Both modes estimate winners and scores from the same model. For a simulated event with probability near 50%, ideal independent-run Monte Carlo standard error is about **0.5 percentage points** at 10,000 runs and **0.05 percentage points** at 1,000,000. These figures describe numerical sampling precision, not real-world accuracy. Show counts and sampling uncertainty for rare scorelines. Check key outputs across deterministic checkpoints and independent test seeds.

### Performance and cost

- Run simulations in the dedicated Python worker, outside Vercel request functions and the browser main thread.
- Batch or vectorise baseline calculations and aggregate counts incrementally.
- Store only a small diagnostic sample of event traces when needed, not a million narratives.
- Checkpoint batches with atomic completion counters.
- Research once per evidence snapshot; make no external web or AI calls inside the simulation loop.
- Coalesce identical official jobs and apply configurable quotas to personal jobs.
- Derive queue position and ETA from actual state and measured throughput.
- Benchmark runtime and hosting cost before promising public deep-run limits.

## 11. Application architecture and deployment

### Required stack

| Layer | Technology | Responsibility |
| --- | --- | --- |
| Web app | Next.js, React, TypeScript, and Tailwind CSS | Responsive pages, accessible reports, and scenario editor. Deploy on Vercel. |
| Request API | Next.js Route Handlers in the Node.js runtime | Authentication, fixture and forecast reads, job submission, ownership checks, and progress endpoints. Deploy with the web app on Vercel. |
| Forecast engine | Python with NumPy and SciPy where useful | Sport-specific scoring models, indexed simulations, aggregation, and evaluation. Run in a separately deployed worker process. |
| Durable data and job queue | Supabase PostgreSQL | Fixtures, evidence, users, immutable reports, job leases, checkpoints, and transactional job claims. |
| Authentication | Supabase Auth | Sign-in and account identity; `app_users.id` references `auth.users.id`. |
| Large artifacts | Private Supabase Storage bucket | Immutable result artifacts and diagnostic samples when they do not belong in PostgreSQL. |
| External data | Approved sports-data providers | Fixtures, results, lineups, statistics, and source records under agreed rights. |

Use one repository with `apps/web`, `services/worker`, and shared, versioned API schemas. The worker may be deployed to a container host selected during implementation; that host must support an always-on process and access to PostgreSQL and artifact storage. A Python FastAPI service is optional if the worker later needs its own HTTP endpoints. The Next.js API remains the public application API.

Keep provider integrations, AI extraction, numerical engines, evaluation, and presentation separate. Do not place coefficients in UI components or prompts. Each sport engine implements:

```text
validate_snapshot()
build_scenario_distribution()
calculate_parameters()
sample_match()
validate_result()
summarise()
settle_observed_result()
```

### Vercel deployment contract

1. Connect `apps/web` to a Vercel project. Configure Preview and Production environments separately; deploy the production branch to the public domain.
2. Connect a Supabase project to Vercel. Use the Supabase transaction pooler for short-lived Vercel functions and an appropriate direct or session connection for the persistent worker. Apply reviewed migrations before deploying code that requires them.
3. Keep provider keys, database passwords, Supabase secret keys, and worker credentials server-side. The Supabase project URL and publishable key may be exposed as `NEXT_PUBLIC_` variables for authentication; they are not secrets.
4. A forecast request creates or reuses a durable job and returns promptly. The Python worker claims indexed batches, checkpoints progress, and publishes the finished artifact. The browser reads progress and results through the Vercel API.
5. Make deployment independent of simulation duration. Vercel Functions have execution limits, so a million-run forecast must not rely on one function invocation completing the entire job.
6. Verify Preview against test data, then Production against approved live feeds. Add health checks and error monitoring for both the Vercel app and the worker.

The deployment is **Vercel for the web app and public API**, with managed data services and a separate simulation worker. This is the release architecture unless measured batch performance shows that a simpler bounded worker arrangement satisfies the same retry and checkpoint requirements.

Current platform references: [Next.js on Vercel](https://vercel.com/docs/frameworks/full-stack/nextjs), [Supabase on Vercel](https://vercel.com/marketplace/supabase/supabase), [Supabase database connections](https://supabase.com/docs/guides/database/connecting-to-postgres), and [Vercel Function limits](https://vercel.com/docs/functions/limitations). Recheck plan limits and pricing before implementation.

### Core data entities

| Entity | Required fields or relationships |
| --- | --- |
| Competition | Sport, ruleset, provider mappings, coverage status. |
| Team / Player | Internal ID, provider mappings, dated team membership. |
| Fixture | Competition, teams, venue, scheduled time, status, ruleset. |
| SourceRecord | Source reference, payload hash, event/publication/retrieval times. |
| ResearchClaim | Entity, claim type, value, sources, rubric version, review status. |
| FeatureDefinition | Measurement, units, transforms, dependencies, missing policy, supported versions. |
| EvidenceSnapshot | Fixture, cutoff, source IDs, feature values, statuses, content hash. |
| EngineVersion | Sport, code and coefficient versions, transforms, RNG version, evaluation reference. |
| Scenario | Owner, base snapshot, constrained overlay, creation time. |
| SimulationJob | Scope, seed, target and completed counts, checkpoint, status, error code. |
| Forecast | Immutable snapshot, engine, run references, distributions, summaries, publication time. |
| ObservedResult | Scope, score, completion state, source and version. |
| EvaluationRun | Dates, horizon, included forecasts, metrics, benchmark results. |
| SavedItem | User and team, fixture, forecast, or scenario reference. |

Use foreign keys, ownership checks, and indexes for fixture/date/version lookups. Respect provider retention and redistribution terms.

Example feature record:

```json
{
  "feature_id": "S38",
  "entity_id": "example_team_home",
  "raw_value": 4,
  "unit": "days",
  "status": "observed",
  "source_ids": ["example_source_01"],
  "available_at": "2026-10-01T12:00:00Z",
  "retrieved_at": "2026-10-02T09:00:00Z",
  "transform_version": "rest_days_v1",
  "uncertainty": { "kind": "fixed" }
}
```

These IDs and times are illustrative. A real feature resolves to stored source records. Fixed observations do not need artificial randomness.

### API outline

| Method and path | Behaviour |
| --- | --- |
| `GET /api/fixtures` | Filter and paginate supported fixtures. |
| `GET /api/fixtures/:id` | Return match metadata and forecast references. |
| `GET /api/fixtures/:id/evidence` | Return permitted source summaries and factor status. |
| `POST /api/forecasts` | Request or reuse an official forecast for an eligible snapshot. |
| `GET /api/jobs/:id` | Return authorised job status and progress. |
| `GET /api/jobs/:id/events` | Optionally stream progress events. |
| `POST /api/jobs/:id/cancel` | Cancel an owned job; shared official jobs require admin authority. |
| `GET /api/forecasts/:id` | Return an immutable report. |
| `POST /api/scenarios` | Validate and save an owned overlay. |
| `POST /api/scenarios/:id/simulations` | Queue a scenario run. |
| `GET /api/evaluations` | Return filtered public track-record aggregates. |
| `POST /api/saved-items` | Save an owned reference. |
| `DELETE /api/saved-items/:id` | Remove an owned reference. |

A create-job request includes `fixture_id`, mode, and an idempotency key. The server selects approved official seeds and configuration; users cannot reroll official forecasts until they like an answer. Admin experiments may supply seeds explicitly.

Use `202` for queued jobs, `200` for reused completed results, `422` for invalid assumptions, `409` for incompatible or stale dependencies, `429` for quota limits, and `503` for unavailable dependencies. Return stable error codes and readable messages.

### Job lifecycle and cache identity

Job states: `preparing`, `queued`, `running`, `aggregating`, `completed`, `failed`, `cancel_requested`, and `cancelled`.

Workers heartbeat and timed-out leases can be reclaimed. Resume only from a verified checkpoint with the same snapshot, seed, and configuration. Commit each batch exactly once so retries cannot double-count runs. Label partial outputs; a partial run cannot appear as a completed million-run report.

Cache identity includes fixture, prediction scope, evidence hash, engine version, ruleset, scenario hash, RNG and seed identity, and target count. New evidence creates a new report instead of changing an old one.

## 12. Evaluation and first experiment

### Define accuracy before testing

The proposed targets of approximately **0.4 soccer goals** or **5 basketball points** of error are hypotheses, not launch promises. For `N` games, define per-team score mean absolute error as:

```text
team_score_MAE = Σ(|pred_home − actual_home| + |pred_away − actual_away|) / (2N)
```

Measure total-score and margin MAE separately: an accurate margin can hide poor team-score predictions. Specify in advance whether the point prediction is a mean or median. For integer soccer score picks, being within 0.4 of an integer actual score means an exact hit; a fractional expected-goals estimate has a different “within 0.4” meaning. Label each target precisely.

### Required metrics

- Soccer home/draw/away multiclass log loss and Brier score; basketball binary equivalents.
- Reliability plots comparing stated probabilities with observed frequencies over adequate samples.
- Winner accuracy, with a defined draw policy and always-pick-favourite baseline.
- Team-score, total-score, and margin MAE and RMSE.
- Exact-score top-one and top-three hit rates without guarantees.
- Prediction interval coverage and width.
- A proper score-distribution metric, such as log likelihood or ranked probability score, with a documented zero-probability policy.
- For “within 5” claims, separate per-team, both-team, and margin hit rates.

Use analytic or predeclared smoothed probabilities for evaluation so finite Monte Carlo counts do not create false zero probabilities for possible outcomes. Fit any smoothing on training or validation data and disclose it.

### Chronological historical test

1. Select one league with licensed historical results and reconstructible pre-match inputs.
2. Split by date: earlier seasons for fitting, the next for validation, and a later untouched season for testing where data permits. Document actual dates.
3. Keep future data out of strengths, scalers, availability, and coefficients.
4. Establish a league/home baseline and a simple sport-specific strength baseline.
5. Add factor groups incrementally and compare on validation data.
6. Freeze the chosen engine before testing the untouched period.
7. Run quick forecasts for the test set and deep forecasts for a predeclared subset to measure convergence and cost.
8. Report paired performance differences with uncertainty across matches or date blocks. Simulated runs are not additional real matches.
9. Compare with an archived, cutoff-matched external probability benchmark if available, documenting its origin and normalisation.

Historical AI extraction is a leakage risk because a present-day model may know old results. Restrict it to archived pre-cutoff records and deterministic extraction where possible. Exclude inputs that cannot be reconstructed without hindsight, or clearly label that evaluation retrospective and unsuitable as production evidence.

### Prospective test

Publish timestamped forecasts before every eligible fixture over a predefined window, such as eight consecutive matchweeks. Keep failed and unavailable forecasts in the coverage report. Define official selection rules for each horizon in advance, for example 24 hours before kickoff and after confirmed lineups. A postponed fixture receives a new snapshot for its rescheduled time; retain the superseded record.

### Engineering acceptance checks

- Identical snapshot, seed, and engine reproduce outputs in the supported environment.
- Distinct indexed streams create variation without forced uniqueness.
- Scores are valid; NBA full-game results cannot finish tied.
- Soccer outcome probabilities sum to one within numeric tolerance.
- An absent player receives zero minutes, with feasible replacement minutes.
- Deep continuation preserves the quick run's first sample indices.
- Parallel and single-worker aggregation agree within declared tolerance.
- Poisson baseline simulation agrees with its analytic distribution within expected sampling error across fixed test seeds.
- Missing data never silently becomes zero or an AI-invented value.
- Cutoff checks reject later evidence.
- Retry, cancellation, and reconnection cannot corrupt counts or lose reports.
- A scenario or corrected result cannot overwrite an official forecast.

Implementation checks do not establish predictive value. Promote a richer engine only after it meets a predeclared improvement criterion on validation and passes untouched or prospective checks; otherwise label it experimental. Keep the stronger baseline if a 50-factor version fails to beat it.

## 13. Reliability, privacy, and accessibility

### Failure behaviour

| Situation | Required behaviour |
| --- | --- |
| Source unavailable | Show the last valid data time; forecast only if freshness policy allows. |
| Lineups unknown | Model supported lineup uncertainty and label lineups projected. |
| Injury reports conflict | Flag the conflict and follow a documented review or conservative policy. |
| Sparse or new team history | Shrink to a documented prior and show wider uncertainty. |
| Tactical data unsupported | Disable the factor and explain why. |
| Fixture already started | Reject new pre-match official forecasts; separately label hypothetical runs. |
| Cancelled, postponed, or abandoned match | Do not settle it as a normal completed match. |
| Worker failure | Resume or retry safely and show a visible retry path. |
| Deep job still running | Keep the completed quick report available with its own run count. |
| Corrected final result | Version settlement and recompute evaluation without losing the audit trail. |

Keep API and provider credentials server-side. Enforce account ownership for scenarios and jobs. Fetch sources only from approved providers and domains. Validate AI output, rate-limit job and research requests, minimise stored user data, offer deletion controls, and avoid logging secrets or private account data.

Use mobile-first layouts with keyboard support, visible focus, screen-reader labels, and reduced-motion support. Provide tables or text alternatives for charts and avoid colour-only distinctions. Show explicit local dates and timezones. Progress indicators must reflect real job progress.

Prefer clear primary labels such as **Home win 58%**, **Expected goals**, **Most likely scorelines**, **Lineup not confirmed**, and **Based on information available at [time]**. Avoid unsupported claims such as “guaranteed winner,” “a million simulations means near-perfect accuracy,” or “always within 0.4 goals.”

## 14. Delivery sequence

| Phase | Work | Completion evidence |
| --- | --- | --- |
| 1. Data feasibility | Choose first league and provider; verify rights, coverage, and historical timestamps. | Coverage matrix and source-to-factor map. |
| 2. Baseline engine | Implement rules, score distributions, RNG, and aggregation. | Reproducible output and analytic checks. |
| 3. Evidence system | Version snapshots, registry, and constrained AI extraction. | Traceable records and explicit missing/conflict states. |
| 4. Web flow | Build and deploy the Next.js app on Vercel with fixtures, match page, progress, report, and saved links. | User completes a forecast on a Preview deployment without developer help. |
| 5. Quick and deep jobs | Add queue, cache, continuation, checkpoints, and quotas. | Verified 10,000 and 1,000,000 runs with measured time and cost. |
| 6. Scenarios | Add availability and lineup editor with paired comparison. | Private assumptions and enforced constraints. |
| 7. Evaluation | Run chronological tests, settlement, and track record. | Baseline comparison accounting for every eligible fixture. |
| 8. Factor expansion | Add supported groups and interactions. | Ablation results and versioned coefficient rationale. |
| 9. Basketball | Add a separate engine and NBA ruleset. | Sport-specific tests and independent performance report. |
| 10. Public beta | Monitor operations and publish prospective forecasts. | Stable flow, methodology, and measured results. |
| 11. Continuous operation | Automate ingestion, state refresh, candidate evaluation, guarded promotion, and rollback. | New results update future forecasts without manual entry; version changes pass recorded gates. |

Do not commit to a complete build schedule until provider coverage, model scope, and team capacity are known. The first testable artifact is the baseline engine and its evaluation report, rather than a polished dashboard backed by fabricated predictions.

## 15. Definition of done

- [ ] The app works in desktop and mobile browsers.
- [ ] The Next.js web app and public API deploy successfully to Vercel Preview and Production.
- [ ] The Python simulation worker runs separately, claims jobs safely, records progress in PostgreSQL, and exposes it through the Vercel API.
- [ ] Supported fixtures and source timestamps are real and traceable.
- [ ] Each sport has its own rules, calculation logic, and evaluation.
- [ ] Both 50-condition registries exist; unsupported conditions are disabled explicitly.
- [ ] AI research is separate from numerical effects and event sampling.
- [ ] Every forecast references immutable evidence, engine, and simulation versions.
- [ ] Both run counts work without per-run AI calls or forced unique outcomes.
- [ ] One coherent score distribution supplies outcome and score probabilities.
- [ ] Users can inspect evidence, uncertainty, and valid assumption changes.
- [ ] Jobs survive retries without duplicated work or counts.
- [ ] Forecasts use predeclared metrics and exclude look-ahead evidence.
- [ ] Historical and prospective results are visibly distinct.
- [ ] New verified results automatically settle forecasts and refresh eligible future snapshots.
- [ ] Automatic coefficient promotion is disabled until versioned evaluation and rollback gates are configured and tested.
- [ ] No accuracy target is marketed as achieved without measured evidence.

## 16. Technical reading

The following titles informed the discussion. They explain relevant concepts; they do not show that MatchLab will achieve any particular accuracy. The flows, factor lists, and implementation decisions above remain proposals to test.

- StatsBomb, *Match Simulation: Score Effects and Beyond* — match-state simulation.
- StatsBomb, *Unpacking Ball Progression* — valuing player actions through expected goal difference.
- StatsBomb, *Upgrading Expected Goals* — context and modelling choices for scoring probability.
- NBA, *Basic/Traditional Stats vs. Advanced Stats* — pace and possession-adjusted efficiency.
- NIST, *Uncertainty Machine* — propagating uncertain inputs through a mathematical function.

## 17. Developer handoff

Build an auditable forecasting product around an explicit numerical engine. Start with a baseline that can be tested, then add player, tactical, form, and contextual factors only where data and validation support them. Freeze evidence for each forecast, sample plausible scenarios and match outcomes, and preserve repeated results because their frequencies determine estimated probabilities. Present winner and score probabilities together, allow constrained personal scenarios, and publish measured performance.

The claim to prove is the quality of the inputs, rules, explanations, and forecasts. Simulation count alone is not a measure of predictive quality.

## 18. Automatic updates and learning after deployment

### 18.1 Required behaviour

After deployment, MatchLab must process new supported matches without manual result entry or repeated founder requests for AI research. This depends on configured data providers, valid credentials, scheduled processing, sufficient coverage, and an operating budget. A deployed website alone does not provide fresh match data.

The automatic cycle is:

1. Detect a completed supported match.
2. Fetch its official result and available team and player statistics.
3. Validate, deduplicate, and version incoming records.
4. Settle forecasts published before that match.
5. Refresh rolling form, player contributions, team strengths, and uncertainty using the active rules.
6. Create new evidence snapshots for affected future fixtures.
7. Periodically fit candidate coefficients or calibration updates from eligible accumulated data.
8. Compare candidates chronologically with the current engine.
9. Promote only candidates that pass configured offline and shadow gates; otherwise retain the incumbent.
10. Monitor production and roll back faulty promotions under predefined triggers.

The app can adapt its statistics, ratings, distributions, and coefficients without fine-tuning a language model. Its equations and feature definitions remain explicit, controlled, and versioned.

### 18.2 Types of update

| Type | Example | Automatic policy |
| --- | --- | --- |
| New factual data | Final score, shots, player minutes, confirmed injury report. | Ingest after validation; retain provenance and timestamps. |
| Derived team or player state | Recent form or a strength estimate after a completed game. | Recompute under the active versioned rule, retaining uncertainty and small-sample shrinkage. |
| Forecasting parameters | Rest-day weight, home-effect coefficient, variance, or calibration mapping. | Fit a candidate, evaluate it, and promote only if release gates pass. |

Changing a factor definition, adding a factor, editing equations, revising the AI extraction rubric, or changing provider mappings is a reviewed code or configuration release. Background AI cannot rewrite production source code or its own evaluation gates.

### 18.3 Scheduling and orchestration

The following are starting defaults. Adjust them to provider limits, publication delays, and measured workload. The separate worker and its scheduler own recurring ingestion and learning jobs; the Vercel web app presents their state and serves user requests.

| Job | Trigger or default cadence | Output |
| --- | --- | --- |
| Fixture reconciliation | Every six hours and on supported schedule-change events. | Upcoming fixtures and postponements. |
| Completed-match detection | Every 15 minutes near expected completion, or by provider webhook. | Fetch jobs for newly completed matches. |
| Detailed-stat retry | Exponential backoff for incomplete records, within rate limits. | Complete or explicitly partial records. |
| Recent-data reconciliation | Nightly over the prior seven days, plus a periodic longer audit. | Corrections, missed matches, and deduplicated revisions. |
| Form and strength refresh | After an accepted result or statistics batch. | Versioned state for affected teams and players. |
| Forecast settlement | After confirmation and again after corrections. | Updated evaluation records; unchanged original forecasts. |
| Learning candidate | Weekly, when enough new eligible data exists. | Candidate artifact and evaluation report. |
| Operational checks | After each job and on a freshness schedule. | Alerts, freshness state, and recovery tasks. |

Enforce dependencies: accept data before refreshing features, and commit features before creating a new snapshot. Coalesce related changes. Refresh official forecasts at defined horizons or after material changes; do not start a deep simulation for every new row.

Use durable watermarks or cursors so missed schedules can be recovered. Make ingestion idempotent by provider, match, record type, and revision. Reconcile expected fixture IDs against received IDs: a successful API response does not prove that all expected matches arrived.

### 18.4 How new performances affect estimates

A striker may play 80 minutes, take five shots, and create strong chances without scoring. Record both the score and the chance quality; a loss does not by itself imply poor individual form. Likewise, separate a basketball player's minutes, role, and scoring efficiency when unusually high minutes drive a large points total.

Strength updates follow predefined equations that account for expected performance, opponent quality, personnel, and uncertainty. One upset does not trigger broad coefficient changes. If a provider supplies only final scores, update only supported score-based estimates and mark richer features unavailable. AI must not reconstruct unobserved events from the score.

### 18.5 Candidate fitting and automatic promotion

Each learning run records its data cutoff, source revisions, fitting and validation windows, feature and configuration versions, coefficient artifact, and evaluation report.

1. Require enough new matches and adequate factor coverage. Otherwise record a skip reason.
2. Fit approved coefficients on an earlier chronological window.
3. Evaluate the candidate and incumbent on later matches excluded from fitting.
4. Reconstruct historical forecasts with only evidence available at each forecast cutoff. Use rolling-origin evaluation where needed.
5. Compare primary probability metrics, calibration, score error, interval coverage, and relevant league and horizon groups.
6. Reject leakage, invalid output, excessive runtime, or material regression under the configured tolerances.
7. Run a passing candidate in shadow mode on future matches while the incumbent remains public.
8. Promote after the predefined shadow sample and performance gates pass. Otherwise keep the incumbent and preserve the report.

The machine-readable, versioned promotion policy must define at least `minimum_new_matches`, `minimum_validation_matches`, `primary_metric`, `minimum_improvement`, `maximum_allowed_regressions`, `shadow_minimum_matches`, `data_quality_thresholds`, and `rollback_triggers`. Choose and freeze thresholds after the initial baseline study and before enabling automatic promotion. Missing thresholds disable promotion; data ingestion and fixed-rule state updates continue.

Repeated optimisation against one validation set can overfit the learning process. Rotate validation windows forward, limit candidate searches, and retain fresh prospective evaluation periods. Once a test season has influenced version selection, it is no longer untouched.

### 18.6 Versioning and rollback

Promote by atomically moving an active-version pointer to an already tested artifact. Each job captures its evidence and engine versions at creation; a promotion during execution cannot change that job. Retain the last known good engine.

Structural failures, such as invalid probabilities, corrupt inputs, or a breached error-rate threshold, may trigger automatic rollback. Predictive-performance rollback needs a predefined sample, window, and tolerance; one surprising game is insufficient. Record the trigger and affected forecast IDs and alert administrators.

Corrections create new source revisions and derived state. Recompute affected evaluations and future snapshots without rewriting the original pre-match forecast. Personal scenarios, simulated outcomes, and AI explanations are never training labels. Only verified real outcomes and permitted performance data enter the learning dataset.

### 18.7 Visibility

Show users:

- **Data updated [time].**
- **Form includes completed matches through [date].**
- **Forecast generated [time] using engine [version].**
- A badge and optional comparison when a newer forecast exists.
- A clear stale or incomplete status when updates are delayed.

Give administrators visibility into last successful ingestion, provider coverage, queue backlog, rejected records, missing-stat retries, learning status, candidate versus incumbent results, promotion history, and rollback controls.

Data freshness and engine age are separate: an unchanged engine can use today's valid team data, while a recently fitted engine can still depend on a stale lineup feed.

### 18.8 Acceptance tests for continuous operation

- [ ] Replay the same completed-match event twice; store one logical revision and refresh derived statistics once.
- [ ] Ingest a new game; rolling form and eligible future snapshots change without manual entry.
- [ ] Correct an old score; preserve its earlier revision, update settlement, and recompute dependent features.
- [ ] Simulate a provider outage; show stale status, retry safely, and backfill missing matches after recovery.
- [ ] Receive incomplete player data; invent no values and apply only the defined degraded behaviour.
- [ ] Evaluate a worse candidate; leave the active engine unchanged.
- [ ] Evaluate a candidate that passes configured offline and shadow gates; promote it automatically with an audit trail.
- [ ] Introduce an invalid promoted artifact; restore the known good version without changing historical forecasts.
- [ ] Verify training records were available by their relevant cutoffs and exclude hypothetical or simulated results.

Continuous adaptation does not guarantee improvement with every update. New data may reveal weaknesses in existing rules; the evaluation gates exist to catch those weaknesses before a candidate becomes the public default.
