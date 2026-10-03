# MatchLab contracts v1

[`schemas/v1.json`](schemas/v1.json) is the shared source of truth for seven API payloads: `fixture`, `evidence_snapshot`, `job_request`, `job_status`, `forecast_report`, `scenario` and `api_error`. Every payload carries `schema_version: 1`. The first report schema covers the soccer regulation baseline; basketball will need its own report version when its engine is built.

The [TypeScript validator](src/validate.ts) and [Python worker validator](../../services/worker/src/matchlab_worker/contracts.py) use the same catalog. They implement the JSON Schema keywords present in this file: `type`, `required`, `additionalProperties`, `properties`, `items`, `enum`, `const`, `pattern`, string/array length and numeric bounds, plus asserted `uuid` and `date-time` formats. Unknown schema keywords cause an error. Keep new schema versions in new files; do not silently change a published version.

To check the shared [examples](examples/v1_cases.json), run from the repository root:

```powershell
npm.cmd --workspace @matchlab/contracts run build
npm.cmd --workspace @matchlab/contracts run check
python -m unittest discover -s tests -p test_contracts.py
```

The tests run the same seven valid and ten invalid payload cases through both validators. No package installation is needed after the existing web workspace dependencies are installed. The worker deployment must include this schema file alongside its code when contract validation is wired into live jobs.

These schemas validate the transport shape. Application rules remain in their owning services: different home/away teams, source timestamps before cutoff, job progress within its target, probability totals, score-count totals, lineup feasibility, access control and ownership. A payload that passes this schema has **not** passed those domain checks. The registry's `active` factor status is also separate from an enabled engine version.
