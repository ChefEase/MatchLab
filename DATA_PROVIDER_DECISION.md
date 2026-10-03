# Task 1: first soccer league and data provider

**Decision date:** 3 October 2026  
**First league:** English Premier League (EPL), provider competition code `PL`  
**Primary provider:** football-data.org API v4, permanent Free plan  
**Provider budget for the first baseline:** €0/month  
**Status:** Task 1 research decision complete. Verify the exact free-account historical seasons, payloads and delays during ingestion (Task 7) before activating any factor in code.

This corrects the previous Scottish Premiership choice. [football-data.org explicitly includes the EPL in its free tier](https://www.football-data.org/coverage). Its [free plan](https://www.football-data.org/pricing) provides fixtures, delayed scores and schedules, and league tables at ten calls per minute. The [API documentation](https://www.football-data.org/documentation/quickstart) uses competition code `PL` and exposes fixtures by competition and season.

## Free and cheap options compared

| Provider | EPL on free plan? | Free allowance | Data useful to MatchLab | Decision |
| --- | --- | --- | --- | --- |
| **football-data.org** | **Yes** | €0; **10 calls/minute**. No published daily request cap on its pricing page. | EPL fixtures, final scores, home/away teams and standings. Results/schedules are delayed. Detailed player statistics and lineups require other tiers or sources. | **Primary for the EPL score-based baseline.** |
| **API-Sports Football** | **Yes** | **100 requests/day**, reset at 00:00 UTC. | Broad football endpoints, including EPL fixtures, team/player data and lineups; verify free-account endpoint/season depth. | Research alternative only. Its terms say it does not grant rights to publish competition data, so it is not an approved public-site fallback. |
| **Sportmonks Football** | No; its permanent free leagues are Scotland and Denmark. | Free plan has no expiry; published page does not state its exact quota. EPL starts with a paid plan advertised from **€29/month**. | Richer core team/player and lineup data. | Possible later paid expansion; no purchase needed for the baseline. |

Sources: [football-data.org coverage](https://www.football-data.org/coverage), [pricing](https://www.football-data.org/pricing) and [terms](https://www.football-data.org/client/register); [API-Sports pricing](https://api-sports.io/sports/football) and [terms](https://api-sports.io/terms); [Sportmonks free leagues](https://www.sportmonks.com/football-api/free-plan/) and [pricing](https://www.sportmonks.com/football-api/plans-pricing/).

## Initial factor coverage matrix

The first baseline needs only historical **completed earlier EPL games** and a future fixture's home/away teams. These three factors are the entire proposed active set. They remain `candidate` in code until Task 7 confirms the free account returns enough historical seasons and future fixtures, and the effects are later evaluated. All other soccer factors remain inactive.

| Factor | Historical source | Before-match source | Cutoff and measurement rule |
| --- | --- | --- | --- |
| `S01` attack strength | EPL `PL` past-season matches: home/away teams and full-time goals. | The same completed earlier matches, saved before the prediction cutoff. | Opponent-adjusted goals scored, shrunk toward the league average. Exclude future or not-yet-final matches. |
| `S02` defensive strength | Same historical `PL` match scores. | Same completed earlier matches. | Opponent-adjusted goals conceded, with small-sample shrinkage; missing score is never zero. |
| `S36` home advantage | Past `PL` home/away roles and final scores. | Scheduled `PL` fixture home/away roles and venue/status. | League-level home effect fitted on earlier games; review neutral or ambiguous fixtures. |

The [v4 quickstart](https://www.football-data.org/documentation/quickstart) documents match score, status, `utcDate`, team identity, venue and competition/season filters. The free tier does **not** establish reliable lineup, injury or detailed player data, so `S03–S35` and `S37–S50` remain inactive. In particular, lineup-based what-if probability changes must wait for a source and validated replacement model. The schema still retains all 50 candidate definitions. [Feature specification](MATCHLAB_SPEC.md#8-candidate-factor-registries).

The public documentation does not prove how many prior EPL seasons the **free account** can fetch. Task 7 must query several seasons through `/v4/competitions/PL/matches?season=YYYY`, record accessible years and score completeness, and adjust the evaluation split if the free history is too short. Older records do not include a trustworthy first-seen timestamp for later corrections; label historical replays as reconstructed and store exact retrieval timestamps prospectively.

## Rights, freshness and budget

- **Use and attribution:** [football-data.org terms](https://www.football-data.org/client/register) require the visible text “Football data provided by the Football-Data.org API”, limit a key to one application/domain, prohibit publishing team logos or photos without separate permission, and restrict continued reference to provider data after subscription cancellation. Put attribution in the web app before public release and avoid logos/photos. Check the current account contract before commercial launch.
- **Budget:** €0/month for the score-based first baseline. A paid plan is **not** required to start. More historical seasons, live scores, lineups and player detail may require a paid tier or a separately approved source; no such cost is authorized by this decision.
- **Limit:** ten calls per minute on Free. Cache season schedules/results in Supabase and refresh centrally, rather than making one provider call for every visitor. [Pricing](https://www.football-data.org/pricing).
- **Update delay:** the provider describes scores and schedules as delayed but does not publish a precise delay for the Free plan on its pricing page. Task 7 should measure arrival over real matchdays and set the settlement/freshness policy from the observed delay. Until then show the last update time and never imply live results. [Pricing](https://www.football-data.org/pricing).
- **Fallback:** none approved. During outages or quota exhaustion, show a stale/unavailable state rather than silently mixing another source's IDs or rights.

## What the founder needs to do

**Nothing for Task 1.** When Task 7 starts, create a [free football-data.org account](https://www.football-data.org/client/register) and put its API token in a local/server secret. Do not paste it into GitHub or chat. The developer will then check accessible EPL seasons and sample fixtures. If those checks fail, revisit the provider before enabling forecasts.

No account, payment, package installation or deployment was required to make this research decision. Forecast accuracy and complete historical coverage have not been claimed.
