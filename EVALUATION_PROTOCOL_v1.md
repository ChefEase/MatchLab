# MatchLab soccer evaluation protocol v1.0

**Frozen on:** 3 October 2026, before building or fitting the first forecast engine.  
**Applies to:** English Premier League (`PL`) score-based baseline using [football-data.org Free](https://www.football-data.org/pricing).  
**Status:** Frozen evaluation design. No model has been fitted, no historical test has been run, and no accuracy result is claimed.  
**Change rule:** Preserve this file as v1.0. Any later change to dates, eligibility, cutoffs, metrics, or gates needs a new protocol version with a written reason. Never revise v1.0 after viewing 2025/26 test performance.

## 1. Forecast contract

- Predict each EPL regular-season fixture's **full-time score after regulation plus stoppage time**. EPL league matches have no extra time or shootout. The joint score distribution supplies home-win, draw and away-win probabilities, team-goal distributions, total goals and goal difference. Probabilities must sum to one within `1e-10`.
- The only official v1 horizon is **H24**: `cutoff_utc = scheduled_kickoff_utc - 24 hours`. Use the fixture schedule version and evidence available at that cutoff. Lineups, injuries, odds, xG, AI research, personal scenarios, and post-cutoff updates are outside v1.
- A 10,000-run simulation is the first report mode. Use the same underlying fitted distribution for analytic probability scoring; Monte Carlo counts do not create extra matches or override the analytic forecast. A deep run is a numerical convergence check, not a second forecast selection.
- One fixture has at most one official H24 forecast per evidence/engine version. Keep its original snapshot, publication time and result even after a correction. A changed kickoff creates a superseding fixture/snapshot version, not an edit to the old forecast.

## 2. Fixed chronological split

Season membership is determined by the provider's `PL` season-start year, not by a mutable calendar-date query. Dates below identify the league's announced playing windows; use each fixture's provider UTC kickoff to order games within a season.

| Role | Provider filter | Announced playing dates | 3 October 2026 free-account audit | Use |
| --- | --- | --- | ---: | --- |
| Fit | `season=2023` | 11 Aug 2023–19 May 2024 | 380/380 scored | Estimate the first league and team parameters; tune only inside fit/validation rules. |
| Validation | `season=2024` | 16 Aug 2024–25 May 2025 | 380/380 scored | Choose between the league/home benchmark and the team-strength model; apply the gate in §8. |
| Untouched test | `season=2025` | 15 Aug 2025–24 May 2026 | 380/380 scored | One locked evaluation after validation selection. Do not tune or change exclusions after viewing it. |
| Prospective | `season=2026` onward | 21 Aug 2026–30 May 2027 for 2026/27 | 50 scored, 330 future at audit | Publish only genuinely timestamped future forecasts after deployment. Prior 2026/27 fixtures are never backfilled as prospective. |

League date sources: [2023/24 fixtures](https://www.premierleague.com/es/news/3537201), [2024/25 dates](https://www.premierleague.com/en/news/3832048), [2025/26 dates](https://www.premierleague.com/en/news/4171848), [2026/27 dates](https://www.premierleague.com/en/news/4468487/). The audit counts and factor coverage are recorded in [Task 1](DATA_PROVIDER_DECISION.md).

The 2025/26 test season is held out from all coefficient choices, feature transformations, threshold changes and UI claims. Its scores were counted in the Task 1 coverage audit, but no score values were examined for model selection. Because the feed lacks historical first-seen timestamps, this is a **reconstructed retrospective test**, not proof that a live forecast would have received every input on time. The prospective track record is reported separately.

## 3. Eligibility and coverage

The denominator is every provider `PL` regular-season fixture in the validation/test season, expected to be 380 each. A fixture is scoreable only when it has one stable match ID, two distinct team IDs, a valid UTC kickoff, unambiguous home/away roles, `FINISHED` status and nonnegative integer full-time goals for both teams. A postponed match is scored once at its completed rescheduled kickoff. Cancelled/abandoned fixtures with no completed league result are unscoreable, with their IDs and reasons listed. Do not exclude derbies, promoted teams, upsets, high scores, missing player news or model failures.

For every season report: provider fixture count, eligible count, forecasted count, missing/failed count, unscoreable count and the exact ID/reason list. The benchmark and candidate must forecast the **same eligible fixture set**; missing candidate forecasts remain in coverage reporting. The validation gate requires forecasts for **100% of eligible fixtures**. A data integrity mismatch (for example duplicate IDs or a missing result among the audited 380) blocks the evaluation until resolved; it is not an exclusion invented after seeing performance.

## 4. Information allowed at each cutoff

The initial factors are `S01` (prior goals scored), `S02` (prior goals conceded) and `S36` (league home effect). All other soccer factors are inactive. A prediction may use team IDs, the home/away roles and kickoff for the target fixture, plus earlier eligible EPL results.

For the historical reconstruction, a prior result is considered available only if `prior_kickoff_utc + 48 hours <= target_cutoff_utc`. This fixed lag approximates completion plus the free plan's unspecified publication delay. It applies to **all** validation and test forecasts; no actual score or correction from the target game may enter its inputs. The historical feed exposes the latest known kickoff and scores, not their past publication revisions. Therefore any old last-minute reschedule or later correction cannot be replayed exactly; disclose this in every retrospective report. No lineup or injury claim from a historical final-match payload is treated as pre-match evidence.

For prospective forecasts, replace the 48-hour approximation with stored source records that were **actually retrieved by cutoff** and marked final. A late result stays absent until its recorded retrieval time. Store both the provider event time and MatchLab retrieval time. If a target kickoff changes after its H24 cutoff, supersede the old H24 forecast; issue a new one only if the new kickoff still permits a full 24-hour horizon. Report fixtures that cannot receive H24 coverage.

## 5. Models and updating rules

**M0: league/home benchmark.** Fit separate EPL home-goal and away-goal means from earlier eligible results, then use independent Poisson goal distributions. It has no team-specific adjustment. At each subsequent fixture, refresh these means using only results that pass §4's availability rule. This is the explicit league/home reference model.

**M1: first team-strength candidate.** Use the same Poisson score family and league/home terms, plus regularised team attack and defence effects from `S01` and `S02`. New or sparsely observed teams shrink toward zero team deviation, equivalent to the league prior. Home advantage enters once through `S36`; do not add duplicate home factors. No other candidate factor is fitted or sampled.

Both models use the same eligible data and cutoff rule. Fit the initial forms on 2023/24. During 2024/25 validation, update score-derived state using earlier validation matches only after their §4 availability time; never use a later match to predict an earlier one. Choose M1 coefficients/regularisation and any allowed transformation on 2023/24 and 2024/25 only. Once chosen, freeze the model family, feature definitions, hyperparameters, tie rules and update algorithm. Before the 2025/26 test, refit the frozen recipe on all eligible 2023/24 and 2024/25 results; during test, apply the same forward-only update rule to earlier eligible test results. This refit uses no 2025/26 outcome before its own forecast cutoff.

Archive each model's code/configuration version, training IDs, input revision manifest and coefficient artifact hash. AI does not set coefficients or reconstruct unavailable historical inputs.

## 6. Point predictions and probability calculations

- **Reported expected goals** are the means of the team-goal distributions and may be fractional. They are separate from the point predictions used for absolute-error metrics.
- **Point score for each team:** the **lower median** of its marginal integer-goal distribution (smallest integer whose cumulative probability reaches at least 0.5). Team-score MAE and RMSE use these two medians.
- **Point total and margin:** the lower median of each respective marginal distribution, calculated directly from the joint score distribution. Do not assume that summing/subtracting team medians gives these medians.
- **Most likely exact score:** the joint score pair with the largest probability. For equally probable pairs, order by lower home goals, then lower away goals. Top three use the same order.
- Use the analytic Poisson/joint distribution to score outcomes and exact scores, summing tails until omitted mass is below `1e-12`; renormalise numerical truncation only. All nonnegative integer score pairs have positive model probability, so Monte Carlo zero counts never become zero forecast probability. A model that generates NaN, negative rates, invalid mass or a structural zero for a valid score fails evaluation rather than being silently repaired.
- Central 50% and 80% prediction intervals use the smallest integer lower/upper equal-tailed quantiles at 25/75% and 10/90%, inclusive. Report them separately for home goals, away goals, total goals and margin; two team intervals are not a joint pair interval.

## 7. Locked metrics and uncertainty reporting

All means below are over the same eligible fixtures with completed forecasts. Lower loss/error is better. `N` is the number of real matches, never the number of simulation runs.

| Metric | Exact definition |
| --- | --- |
| **Primary: 3-way log loss** | Mean `-ln(p_actual)` for home/draw/away. |
| 3-way Brier score | Mean of `(p_home-y_home)^2 + (p_draw-y_draw)^2 + (p_away-y_away)^2`; no division by three. |
| 3-way accuracy | Choose the largest of home/draw/away probabilities; ties resolve home, then draw, then away. A draw is correct only when the actual score is tied. |
| Always-pick-favourite accuracy baseline | Choose whichever of **M0's home or away win probabilities** is larger, never draw; tie resolves home. Also report an always-home picker. These accuracy baselines do not replace M0's probabilistic scores. |
| Team-goal MAE / RMSE | Mean absolute error over both lower-median team scores (`2N` observations); RMSE is the square root of the mean squared error over the same observations. |
| Total and margin MAE / RMSE | Errors of the total and margin lower medians, each over `N` matches; margin is home minus away. |
| Exact-score log loss | Mean `-ln(P(actual_home, actual_away))` from the analytic joint score distribution. |
| Top-one / top-three exact score | Fraction of games whose actual integer pair is among the first one or three ranked score pairs. |
| Interval coverage and width | Observed inclusive coverage and mean `upper-lower` width for each 50%/80% interval from §6. |
| Calibration | Ten fixed bins `[0,.1),...,[.9,1]` for each of home/draw/away, showing count, mean stated probability and observed rate. Show sparse bins as sparse. |
| Founder's 0.4-goal aspiration | Separately report mean-based per-team `abs(expected_goals-actual_goals) <= 0.4` and both-team hit rates. This is descriptive, never an entry/promotion gate. |

Report each model's metric value and the **paired per-match difference**. For uncertainty intervals, resample UTC calendar-week blocks (Monday–Sunday of actual kickoff) with replacement for **10,000 bootstrap replicates**, using seed `20261003`; recompute the paired metric difference on each replicate and report its 5th/95th percentiles for the validation gate and 2.5th/97.5th percentiles as a descriptive test interval. Simulated matches are not independent evidence of real-game skill. Do not infer accuracy from the number of Monte Carlo runs.

No external probability benchmark is included in v1 because no archived, cutoff-matched feed has been approved. If one is later licensed, report it separately under a new protocol version; never compare today's odds to an old pre-match forecast.

## 8. First improvement and release gates

Evaluate M1 against M0 on **all 2024/25 eligible matches**. M1 passes the validation gate only if **every** condition below holds:

1. Both models forecast 100% of eligible matches with valid probabilities and no post-cutoff input.
2. `mean_logloss(M0) - mean_logloss(M1) >= 0.010` natural-log units per match.
3. The 5th percentile of the paired UTC-week bootstrap improvement in log loss is **greater than zero**.
4. `Brier(M1) <= Brier(M0) + 0.005` and `team_goal_MAE(M1) <= team_goal_MAE(M0) + 0.05` goals.

If M1 fails, keep M0 as the selected model. If it passes, freeze M1 and run the **one-time 2025/26 test**. The test is a release guard: M1 must have no worse log loss than M0, Brier no more than `0.005` worse, and team-goal MAE no more than `0.05` worse, with full eligible-match coverage and no invalid output. Failure keeps M0 as the public baseline and is reported; it does not license retuning on the test season. Passing permits a prospective trial, not a claim that M1 is reliably superior in future matches.

The first richer factor group later proposed for promotion must get its own versioned protocol and fresh forward evidence. Do not reuse the 2025/26 test as an endlessly tunable validation set. Accuracy targets such as 0.4 goals are **not** promotion thresholds.

## 9. Simulation and prospective checks

Run quick 10,000-sample simulations for every test fixture using deterministic indexed streams and compare their outcome estimates with the analytic distribution. For the deep-run cost/convergence subset, select exactly one fixture per provider matchday `1..38`: the eligible fixture with the smallest stable provider match ID in that matchday. Run 1,000,000 total samples on this fixed subset when deep mode exists. Report runtime, cost and Monte Carlo differences; do not replace analytic scoring metrics with whichever run looks better.

For the prospective study, start at the first EPL matchweek for which **all ten scheduled H24 cutoffs occur at least seven calendar days after production activation**. If fewer than eight such matchweeks remain in that season, start with the next season's first qualifying matchweek. Include that week and the following seven consecutive league matchweeks, whether forecast jobs succeed or fail. Publish one official H24 version before each eligible kickoff, with a timestamped input snapshot. Count misses, stale data and superseded/postponed fixtures. Report this prospective window separately from the reconstructed 2025/26 test; never backfill already played 2026/27 games as prospective.

## 10. Required evaluation artifact

Save a machine-readable manifest and human-readable report containing: protocol `v1.0`, source/provider revision and retrieval times, fixture IDs and reasons for exclusions/missing forecasts, actual kickoff and cutoff times, model/coefficients/seed versions, analytic and simulation counts, all metrics, paired intervals, gate pass/fail, and limitations. Export forecasts and observed scores by fixture where provider terms permit. No test result is published without the full eligible-match coverage accounting. Public pages must label retrospective and prospective results separately.
