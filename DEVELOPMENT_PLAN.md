# MatchLab development plan

**Source:** [MATCHLAB_SPEC.md](MATCHLAB_SPEC.md)  
**Implementation context:** [CONTEXT.md](CONTEXT.md)  
**Status:** Tasks 1–3 complete. Task 4 is next.

**First release:** One selected soccer league, with Vercel for the web app, Supabase for PostgreSQL/Auth/Storage, and a separate Python worker.

## How to use this plan

Work through the numbered tasks **in order, one task at a time**. A task is complete only when its listed result exists and its check passes. Record the decision, relevant command or report, and any limitation before moving to the next task. Keep implementation changes small enough to review. If a gate fails, fix that task before adding the next feature.

The first major milestone is a reproducible soccer baseline with an evaluation report. UI polish and additional factors follow measured forecasting work. Do not publish an accuracy claim based on simulation count or a small selected sample. Do not estimate the full schedule until Task 1 establishes data coverage and the team estimates capacity.

## Stage A — Prove data feasibility

### Task 1. Select the first soccer league and data provider

**Build:** Compare candidate providers for future fixtures, historical results, timestamps, team and player statistics, lineups, commercial rights, rate limits, and cost. Select one league and one approved primary provider. Record fallback sources only where their terms permit use.

**Done when:** A coverage matrix maps every initially proposed active factor to a source available both historically and before future matches. The chosen league, provider, rights, expected update delay, and budget are documented. Unsupported factors remain inactive. [Spec §§2, 7, 8](MATCHLAB_SPEC.md#7-data-and-evidence-pipeline).

**Completed (3 October 2026):** [Provider decision and verified factor coverage matrix](DATA_PROVIDER_DECISION.md) select the EPL and football-data.org's permanent Free plan. A token-free account audit found three complete historical seasons with 380 scored matches and no missing team IDs, plus 330 future fixtures in the current season. The initial source-backed factor set is `S01`, `S02` and `S36`; all other soccer factors stay inactive. A conservative 24-hour missing-result window is documented pending observed delay measurements. Public use must follow the provider's attribution and rights terms.

### Task 2. Freeze the first evaluation protocol

**Build:** Define official forecast scope, cutoff horizons, chronological fit/validation/test dates, eligible fixture rules, league/home benchmark, scoring metrics, and the first improvement gate. Specify the point prediction used for score error.

**Done when:** A versioned protocol can be applied without changing dates, exclusions, or metrics after seeing test results. [Spec §12](MATCHLAB_SPEC.md#12-evaluation-and-first-experiment).

**Completed (3 October 2026):** [Evaluation protocol v1.0](EVALUATION_PROTOCOL_v1.md) freezes the EPL 2023/24 fit, 2024/25 validation and 2025/26 untouched test seasons; H24 scope and cutoff; eligible fixtures; M0 league/home benchmark; M1 strength candidate; point predictions, metrics, paired uncertainty and promotion gates. Historical availability is explicitly reconstructed with a fixed 48-hour lag. No results have been inspected for model selection.

## Stage B — Establish the project and trusted data

### Task 3. Bootstrap the repository

**Build:** Create the `apps/web`, `services/worker`, `packages/contracts`, and `supabase` structure from [CONTEXT.md](CONTEXT.md). Add package scripts, Python environment, formatting, linting, and a local setup guide. Keep secrets out of source control.

**Done when:** A new developer can install dependencies and run empty web and worker health checks locally from the guide.

**Completed (3 October 2026):** [README](README.md) documents npm-workspace web setup and a Python virtual environment. The Next.js and worker scaffolds, process health checks, formatting/lint configuration, Supabase local config and secret exclusions are present. The worker CLI/HTTP health checks passed. The developer installed web dependencies and confirmed `/api/health` locally; `lint:web`, `typecheck:web` and `format:check` pass. Next's generated `next-env.d.ts` is excluded from formatting.

### Task 4. Validate the Supabase schema

**Build:** Run [the initial migration](supabase/migrations/20261003000000_initial.sql) against a fresh local Supabase project. Fix SQL or permission issues found during execution. Confirm the `matchlab` schema is not exposed through the Data API, and test Auth-to-`app_users` creation.

**Done when:** The migration applies from scratch and basic insert/read tests pass for users, fixtures, snapshots, jobs, and reports. Browser roles cannot read private app tables.

**Progress (3 October 2026):** The developer reports that the migration applied without errors in the hosted Supabase SQL Editor. Run [the rollback-only smoke check](supabase/tests/task4_schema_smoke.sql) to verify insert/read paths and browser-role grants; create a test Supabase Auth user first to exercise the user path. Confirm `matchlab` is absent from the hosted project's Data API Exposed schemas. A clean local replay is still needed for the stated fresh-local-project gate.

### Task 5. Seed rules and the factor registry

**Build:** Add the first soccer ruleset and all 50 soccer and 50 basketball candidate factor definitions. Mark each factor candidate, experimental, active, or retired. Activate only factors supported by Task 1.

**Done when:** A clean database has the complete registry and explicit statuses, with no invented measurements or “50/50 active” claim. [Spec §8](MATCHLAB_SPEC.md#8-candidate-factor-registries).

### Task 6. Define shared data contracts

**Build:** Write versioned schemas for fixtures, evidence snapshots, job requests/status, forecast reports, scenarios, and stable API errors. Validate them in TypeScript and Python.

**Done when:** A sample payload accepted by one service is accepted by the other, and incompatible payloads fail with a clear error. [Spec §11](MATCHLAB_SPEC.md#11-application-architecture-and-deployment).

### Task 7. Ingest fixtures and map identities

**Build:** Implement one provider adapter for leagues, teams, players, fixtures, and schedule revisions. Resolve provider IDs to internal IDs. Store source, event, availability, and retrieval times.

**Done when:** Replaying a fixture feed does not duplicate fixtures, and a schedule correction produces a new revision. Unknown entity matches enter a review state.

### Task 8. Ingest historical results and supported statistics

**Build:** Import completed matches and the statistics required by the initial active factors. Preserve corrected revisions and explicit partial-data status.

**Done when:** Counts reconcile with the provider's expected fixtures, duplicate fetches are harmless, and a corrected result does not erase its earlier revision.

### Task 9. Reconstruct pre-match training examples

**Build:** Generate dated feature rows using only records available by each historical cutoff. Add missing-data flags and opponent adjustments defined for the baseline.

**Done when:** An automated check rejects any training example that includes a later source or transformation fitted on future games. Record coverage by season and feature. [Spec §§7, 12](MATCHLAB_SPEC.md#12-evaluation-and-first-experiment).

## Stage C — Build and measure the soccer baseline

### Task 10. Fit initial soccer strengths

**Build:** Estimate league intercept, home effect, and shrunk team attack/defence strengths on the fitting period. Save coefficients and transformation versions as immutable artifacts.

**Done when:** Re-fitting the same input manifest produces the same artifact and every coefficient has a defined unit and source window. [Spec §9.2](MATCHLAB_SPEC.md#soccer-baseline).

### Task 11. Calculate the analytic baseline distribution

**Build:** Implement positive scoring rates and the independent Poisson score distribution, including high-score overflow and home/draw/away probabilities.

**Done when:** Probabilities sum to one within tolerance, extreme but valid scores are retained, and fixed examples produce reproducible expected scores.

### Task 12. Implement the 10,000-run simulator

**Build:** Add indexed random streams, valid scenario sampling, incremental score counts, and summary generation. For the first baseline, include only uncertainty layers actually modelled.

**Done when:** The same snapshot, engine, and seed reproduce the result; duplicate scores remain counted; Monte Carlo outputs agree with the analytic distribution within expected sampling error. [Spec §10](MATCHLAB_SPEC.md#10-simulation-design).

### Task 13. Run the untouched historical test

**Build:** Fit on the declared window, choose on validation, freeze the baseline, and evaluate every eligible match in the untouched test period. Produce outcome, score, calibration, interval, and coverage metrics against the declared benchmark.

**Done when:** The evaluation report lists dates, exclusions, sample size, engine version, benchmark, uncertainty across real matches, and any unmet accuracy target. This is the **first testable product artifact**. [Spec §12](MATCHLAB_SPEC.md#12-evaluation-and-first-experiment).

## Stage D — Make forecasts durable and usable

### Task 14. Build immutable evidence snapshots

**Build:** Freeze the source revisions and transformed feature values eligible at a cutoff. Record the content hash, lineup status, uncertainty, and missing or conflicting factors.

**Done when:** A late injury report creates a new snapshot without changing the old one; post-cutoff evidence is rejected.

### Task 15. Add constrained AI research

**Build:** Extract approved claims from stored, pre-cutoff sources with a strict schema, entity checks, source links, and conflict review. Convert only validated claims into supported features.

**Done when:** AI cannot invent a source or coefficient, override the numerical engine, or leak a post-cutoff result into a historical example. [Spec §7.2](MATCHLAB_SPEC.md#ais-role).

### Task 16. Add sign-in and ownership rules

**Build:** Integrate Supabase Auth for accounts. Enforce registered-user and admin permissions in the Vercel API; keep all app data access server-side.

**Done when:** Guests can read published reports, users cannot read another user's private scenario or job, and admin routes reject ordinary users. [Spec §3](MATCHLAB_SPEC.md#3-users-and-access).

### Task 17. Add durable simulation jobs

**Build:** Implement the forecast request endpoint, cache identity, idempotency keys, and job states. A request must create or reuse a job and return promptly.

**Done when:** Two identical official requests resolve to one job/result, invalid requests return stable error codes, and the Vercel function does not perform the simulation. [Spec §11.5](MATCHLAB_SPEC.md#job-lifecycle-and-cache-identity).

### Task 18. Run jobs in the Python worker

**Build:** Claim leased jobs, process disjoint indexed batches, write checkpoints, heartbeat, and resume safely after interruption.

**Done when:** Killing and restarting the worker finishes the job without gaps or double-counted indices. Completed count equals committed batch counts.

### Task 19. Publish immutable forecast reports

**Build:** Aggregate a completed job into one report containing outcome probabilities, score distribution, intervals, evidence references, snapshot and engine versions, seed, and run count.

**Done when:** Every displayed number comes from the same completed run; another result or later snapshot cannot mutate the report.

### Task 20. Build fixture discovery pages

**Build:** Create the responsive home, filtered match list, and match overview pages, using real fixture API data. Include local start time, status, evidence freshness, and forecast availability.

**Done when:** A user can find and open a supported fixture on mobile and desktop; no-fixture, unsupported, and provider-unavailable states are distinct. [Spec §6](MATCHLAB_SPEC.md#6-screen-requirements).

### Task 21. Build job progress and forecast report pages

**Build:** Show actual job state and progress, then the immutable outcome and score report, evidence panel, methodology notes, and accessible chart alternatives.

**Done when:** A user can request a quick forecast, leave, return by link, and inspect the completed result without a developer's help.

### Task 22. Add saved content

**Build:** Let signed-in users follow teams and save fixtures and specific forecast versions.

**Done when:** Saved links reopen the exact chosen report, and newer versions appear as a badge rather than silently replacing it.

### Task 23. Add constrained scenario comparison

**Build:** Support eligible player availability, valid starting lineups, and expected minutes. Recompute dependent inputs and compare with the baseline using equal run counts and matched streams where practical.

**Done when:** Invalid lineups or minutes are rejected; scenario outputs remain private and never enter the official track record. [Spec §5.3](MATCHLAB_SPEC.md#compare-assumptions).

### Task 24. Add the 1,000,000-run continuation

**Build:** Extend a quick job's indexed sample sequence to one million total runs. Preserve the quick report, checkpoint batches, enforce quotas, and measure runtime and cost.

**Done when:** The first 10,000 indices match the quick run, retries cannot double-count, and partial progress cannot appear as a completed deep report. [Spec §10](MATCHLAB_SPEC.md#10-simulation-design).

## Stage E — Settle, deploy, and operate the first release

### Task 25. Settle forecasts against confirmed results

**Build:** Link each official report to a confirmed result revision and calculate predeclared score and outcome metrics. Handle postponed, abandoned, and corrected results.

**Done when:** A correction creates a new settlement and leaves the original forecast untouched.

### Task 26. Publish the track record

**Build:** Show historical and prospective results separately, with league, horizon, lineup status, period, sample size, engine version, exclusions, and benchmarks.

**Done when:** Every eligible fixture is represented as included, excluded with reason, or missing; personal scenarios are absent. [Spec §6.5](MATCHLAB_SPEC.md#saved-content-and-track-record).

### Task 27. Deploy a complete Preview environment

**Build:** Connect `apps/web` to Vercel, configure a separate Supabase Preview project and private artifact bucket, deploy the worker, and add environment variables and health checks.

**Done when:** The full fixture-to-forecast-to-settlement flow works in Preview using test or licensed data; credentials never appear in the browser or repository. [Spec §11](MATCHLAB_SPEC.md#vercel-deployment-contract).

### Task 28. Automate new-match updates

**Build:** Schedule fixture reconciliation, completed-match detection, stat retries, derived-state refresh, snapshot rebuild, and settlement. Use durable cursors, idempotency keys, dependency ordering, and stale-data alerts.

**Done when:** A new verified result changes eligible future snapshots without manual entry; duplicate events, corrections, and provider outages pass the acceptance checks in [Spec §18](MATCHLAB_SPEC.md#18-automatic-updates-and-learning-after-deployment).

### Task 29. Run a prospective beta

**Build:** Deploy the first public version on Vercel and publish timestamped official forecasts for a predefined run of consecutive matchweeks. Monitor coverage, failures, latency, cost, and model quality.

**Done when:** The published report includes all eligible fixtures, failed or unavailable forecasts, the frozen official selection rule, and measured results. Do not claim an accuracy target unless the evidence supports it.

## Stage F — Add sophistication only after the baseline is stable

### Task 30. Add and test one factor group

**Build:** Choose one data-supported dependency group, define its measurement, transform, effect, and uncertainty, then run a chronological ablation against the frozen baseline.

**Done when:** The group is active only if it meets the predeclared validation gate; otherwise it remains experimental. Repeat this task for later groups rather than enabling all 50 at once. [Spec §§8–9](MATCHLAB_SPEC.md#8-candidate-factor-registries).

### Task 31. Enable guarded coefficient learning

**Build:** Add weekly candidate fitting, chronological comparison, prospective shadow runs, a versioned machine-readable promotion policy, atomic activation, and rollback.

**Done when:** A worse candidate stays inactive, a candidate passing every frozen gate promotes with an audit trail, and an invalid promotion rolls back without rewriting historical reports. Promotion remains disabled until thresholds are explicitly set. [Spec §18.5](MATCHLAB_SPEC.md#185-candidate-fitting-and-automatic-promotion).

### Task 32. Start basketball as a separate engine

**Build:** Select NBA data, define its independent evaluation protocol, implement legal full-game rules including overtime, and repeat the baseline-through-prospective sequence for basketball.

**Done when:** Basketball has its own validated engine, ruleset, tests, and performance report. Do not reuse soccer coefficients or imply basketball is complete because its candidate registry exists. [Spec §§8.2, 9.3](MATCHLAB_SPEC.md#basketball-baseline).

## Release gates

| Gate | Required evidence |
| --- | --- |
| **Baseline gate — after Task 13** | Reproducible soccer forecast distribution and honest chronological evaluation. |
| **Usable flow gate — after Task 24** | Real fixtures, immutable quick reports, accessible web flow, valid scenarios, and measured deep-run cost. |
| **Operational gate — after Task 29** | Preview and Production deployments, automatic result updates, safe settlement, complete prospective coverage reporting. |
| **Learning gate — after Task 31** | Versioned promotion policy, shadow evidence, rollback test, and unchanged historical forecasts. |

**Next check:** Task 4 — validate the initial Supabase migration locally, including Auth-to-`app_users` creation and private-table access rules.
