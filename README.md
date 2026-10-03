# MatchLab

MatchLab is being built as an EPL forecasting web app. The current repository contains the [product specification](MATCHLAB_SPEC.md), [data-provider decision](DATA_PROVIDER_DECISION.md), [frozen evaluation protocol](EVALUATION_PROTOCOL_v1.md), [development plan](DEVELOPMENT_PLAN.md), Supabase schema draft, and **Task 3 application scaffolds**. The page and health endpoints prove that the web and Python projects start; they do not forecast matches or connect to a database yet.

## Repository layout

| Path | Purpose |
| --- | --- |
| `apps/web` | Next.js App Router web app and public API, intended for Vercel. |
| `services/worker` | Python numerical/ingestion worker, intended for a separate container host. |
| `packages/contracts` | Shared API schemas and examples, to be added in Task 6. |
| `supabase` | Private application schema migration and local configuration; validation is Task 4. |
| `infra/worker` | Future production worker deployment configuration. |

The JavaScript side uses **npm workspaces**. There is one root `package-lock.json` after the first install. No package install is needed to read or edit the project. Use Node.js 20.9+ and Python 3.11+ to run it. On Windows PowerShell, use `npm.cmd` if the `npm.ps1` shim is blocked by execution policy. [Next.js installation requirements](https://nextjs.org/docs/app/getting-started/installation).

## Run the web scaffold locally

From the repository root in PowerShell:

```powershell
npm.cmd install
npm.cmd run dev:web
```

Open `http://localhost:3000`. In a **second** terminal, run:

```powershell
npm.cmd run health:web
npm.cmd run lint:web
npm.cmd run typecheck:web
npm.cmd run format:check
```

`health:web` expects `Web health OK: http://localhost:3000/api/health`. The route returns `{"status":"ok","service":"web","mode":"scaffold"}`. You can also open `http://localhost:3000/api/health` directly. The health check tests only this process, not Supabase or the sports-data feed.

On macOS or Linux, use `npm` in place of `npm.cmd`. Later, `npm run build:web` checks the production build. Once dependencies are installed, commit the generated root `package-lock.json` so installs are reproducible.

## Run the worker scaffold locally

From the repository root in PowerShell:

```powershell
cd services/worker
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[dev]"
.\.venv\Scripts\python.exe -m matchlab_worker health
```

The last command prints `{"status": "ok", "service": "worker", "mode": "scaffold"}`. To expose a local HTTP health route, run:

```powershell
.\.venv\Scripts\python.exe -m matchlab_worker serve-health
```

In another terminal, open `http://127.0.0.1:8001/health` or run `Invoke-RestMethod http://127.0.0.1:8001/health`. Stop the server with Ctrl+C. To check Python style after installing the optional dev dependency:

```powershell
.\.venv\Scripts\python.exe -m ruff check src
.\.venv\Scripts\python.exe -m ruff format --check src
```

On macOS or Linux, activate/use `.venv/bin/python` instead. The worker's health endpoint does not yet claim a queue connection or database readiness.

## Configuration and secrets

The scaffold health checks require **no API keys or database credentials**. [`.env.example`](.env.example) lists future variable names only. Put real values in local `.env` files or deployment secret stores. Do not commit tokens, Supabase secret keys, database URLs containing passwords, or copied provider responses with account details. The `.gitignore` excludes local environment files.

The football-data.org token belongs on the server/worker side, never in a `NEXT_PUBLIC_` variable. The Vercel project will use `apps/web` as its Root Directory; the Python worker is deployed separately. [Vercel monorepo setup](https://vercel.com/docs/monorepos).

## Current limits and next task

Task 3 adds only structure, start commands, lint/format configuration and process health checks. The developer reports that the initial migration applied without errors in the hosted Supabase SQL Editor. For Task 4, run [the rollback-only schema smoke check](supabase/tests/task4_schema_smoke.sql) in that editor and verify that its final result row shows PASS. If the Auth column shows SKIP, create a test user through Supabase Auth and rerun it. In the hosted project's **Data API settings**, confirm `matchlab` is absent from **Exposed schemas**; the local `supabase/config.toml` setting does not control the hosted project. A fresh local migration run remains a separate reproducibility check when the Supabase CLI is available. No real fixtures, forecasts or background jobs have been loaded by this scaffold.
