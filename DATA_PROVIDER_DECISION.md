# Task 1: first soccer league and data provider

**Decision date:** 3 October 2026  
**First league:** English Premier League (EPL), provider competition code `PL`  
**Primary provider:** football-data.org API v4, permanent Free plan  
**Provider budget for the first baseline:** €0/month  
**Status:** Task 1 complete for the score-based EPL baseline. A free-account audit confirmed the needed historical and upcoming fixture fields. Actual result-arrival delay will be measured during ingestion; the Free plan does not promise a numeric delay.

This corrects the previous Scottish Premiership choice. [football-data.org explicitly includes the EPL in its free tier](https://www.football-data.org/coverage). Its [free plan](https://www.football-data.org/pricing) provides fixtures, delayed scores and schedules, and league tables at ten calls per minute. The [API documentation](https://www.football-data.org/documentation/quickstart) uses competition code `PL` and exposes fixtures by competition and season.

## Free and cheap options compared

| Provider | EPL on free plan? | Free allowance | Data useful to MatchLab | Decision |
| --- | --- | --- | --- | --- |
| **football-data.org** | **Yes** | €0; **10 calls/minute**. No published daily request cap on its pricing page. | EPL fixtures, final scores, home/away teams and standings. Results/schedules are delayed. Detailed player statistics and lineups require other tiers or sources. | **Primary for the EPL score-based baseline.** |
| **API-Sports Football** | **Yes** | **100 requests/day**, reset at 00:00 UTC. | Broad football endpoints, including EPL fixtures, team/player data and lineups; verify free-account endpoint/season depth. | Research alternative only. Its terms say it does not grant rights to publish competition data, so it is not an approved public-site fallback. |
| **Sportmonks Football** | No; its permanent free leagues are Scotland and Denmark. | Free plan has no expiry; published page does not state its exact quota. EPL starts with a paid plan advertised from **€29/month**. | Richer core team/player and lineup data. | Possible later paid expansion; no purchase needed for the baseline. |

Sources: [football-data.org coverage](https://www.football-data.org/coverage), [pricing](https://www.football-data.org/pricing) and [terms](https://www.football-data.org/client/register); [API-Sports pricing](https://api-sports.io/sports/football) and [terms](https://api-sports.io/terms); [Sportmonks free leagues](https://www.sportmonks.com/football-api/free-plan/) and [pricing](https://www.sportmonks.com/football-api/plans-pricing/).

## Initial factor coverage matrix

The first baseline needs only historical **completed earlier EPL games** and a future fixture's home/away teams. These three factors are the entire proposed active set. Their source coverage is verified by the free-account audit below; their mathematical effects still need implementation and evaluation. All other soccer factors remain inactive.

| Factor | Historical source | Before-match source | Cutoff and measurement rule |
| --- | --- | --- | --- |
| `S01` attack strength | EPL `PL` past-season matches: home/away teams and full-time goals. | The same completed earlier matches, saved before the prediction cutoff. | Opponent-adjusted goals scored, shrunk toward the league average. Exclude future or not-yet-final matches. |
| `S02` defensive strength | Same historical `PL` match scores. | Same completed earlier matches. | Opponent-adjusted goals conceded, with small-sample shrinkage; missing score is never zero. |
| `S36` home advantage | Past `PL` home/away roles and final scores. | Scheduled `PL` fixture home/away roles and venue/status. | League-level home effect fitted on earlier games; review neutral or ambiguous fixtures. |

The [v4 quickstart](https://www.football-data.org/documentation/quickstart) documents match score, status, `utcDate`, team identity, venue and competition/season filters. The free tier does **not** establish reliable lineup, injury or detailed player data, so `S03–S35` and `S37–S50` remain inactive. In particular, lineup-based what-if probability changes must wait for a source and validated replacement model. The schema still retains all 50 candidate definitions. [Feature specification](MATCHLAB_SPEC.md#8-candidate-factor-registries).

### Free-account coverage audit

On 3 October 2026, the founder ran [the local audit script](scripts/check_free_epl.ps1) against their Free account and supplied this token-free output:

| EPL season | Fixtures | Finished with full-time scores | Missing team IDs | Future fixtures |
| --- | ---: | ---: | ---: | ---: |
| 2023/2024 | 380 | 380 | 0 | 0 |
| 2024/2025 | 380 | 380 | 0 | 0 |
| 2025/2026 | 380 | 380 | 0 | 0 |
| 2026/2027 | 380 | 50 | 0 | 330 |

This verifies three complete historical seasons for fitting/validation/testing and a current schedule with 330 future fixtures. It verifies IDs and full-time score presence, not every possible statistic, minute-by-minute publication time or forecast accuracy. The v4 match endpoint supports `season=YYYY` as shown in the provider's [reference](https://www.football-data.org/documentation/quickstart). Older records do not include a trustworthy first-seen timestamp for later corrections; label historical replays as reconstructed and store exact retrieval timestamps prospectively.

## Rights, freshness and budget

- **Use and attribution:** [football-data.org terms](https://www.football-data.org/client/register) require the visible text “Football data provided by the Football-Data.org API”, limit a key to one application/domain, prohibit publishing team logos or photos without separate permission, and restrict continued reference to provider data after subscription cancellation. Put attribution in the web app before public release and avoid logos/photos. Check the current account contract before commercial launch.
- **Budget:** €0/month for the score-based first baseline. A paid plan is **not** required to start. More historical seasons, live scores, lineups and player detail may require a paid tier or a separately approved source; no such cost is authorized by this decision.
- **Limit:** ten calls per minute on Free. Cache season schedules/results in Supabase and refresh centrally, rather than making one provider call for every visitor. [Pricing](https://www.football-data.org/pricing).
- **Expected update delay:** the Free plan says scores and schedules are delayed but gives no numeric service guarantee. Plan for **up to 24 hours after a match** before treating a missing final score as an ingestion incident; this is a conservative MatchLab operating assumption, not a provider promise. Reconcile at least daily, record actual source arrival times during Task 7 and revise the window if measurements require it. Until then show the last update time and never imply live results. [Pricing](https://www.football-data.org/pricing).
- **Fallback:** none approved. During outages or quota exhaustion, show a stale/unavailable state rather than silently mixing another source's IDs or rights.

## Handoff

Task 1 needs no further founder action. Keep the API token private and outside GitHub. Task 2 defines the evaluation split and metrics; Task 7 builds ingestion and measures actual update delay. No payment, package installation or deployment was required for the audit. Forecast accuracy has not been claimed.
