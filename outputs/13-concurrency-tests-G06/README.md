# G06 Step 13 — Concurrency Tests

This reproducible test runner demonstrates an unsafe check-then-insert race and its prevention using a SQL Server transaction-owned `sp_getapplock` lock per space.

It uses an isolated `dbo.ConcurrencyTestBooking` table so it can be developed before outputs 11–12 are finalized. The isolated lab must later be adapted to the real Phase 2 booking procedures.

## Setup

```powershell
Copy-Item .env.example .env
npm install
npm test
```

The runner launches independent `sqlcmd` processes, which provides real concurrent database sessions. It uses Windows integrated authentication when `DB_USERNAME` is empty. Set `SQLCMD_TRUST_CERTIFICATE=true` for a local development certificate.

For the local named instance discovered during scaffolding, a temporary test run can use:

```powershell
$env:DB_SERVER='.\MSSQL2025'
$env:DB_DATABASE='tempdb'
$env:SQLCMD_TRUST_CERTIFICATE='true'
npm test
```

`npm test`:

1. creates the isolated lab table and procedures;
2. opens concurrent SQL requests;
3. expects the unsafe procedure to approve both conflicting rows;
4. expects the safe procedure to approve exactly one row; and
5. writes JSON and Markdown evidence under `results/`.

The verified isolated scaffold run is summarized in `evidence/scaffold-run-2026-08-02.md`.

Run `sql/cleanup.sql` to remove the isolated objects. Linux/macOS/WSL use the same commands; use `cp .env.example .env` instead of `Copy-Item`.

## Provisional interface boundary

The runner currently targets isolated tables because outputs 09–12 are not approved. Before final submission, replace only the adapter procedure names/parameters in `src/database.mjs` with the approved output 12 interface and rerun the same scenarios. The test evidence must then be collected against a clean migrated database.

## Docker integration shortcut

From the repository root, use `scripts/run-docker-phase2.ps1` on Windows or `scripts/run-docker-phase2.sh` on Fedora/bash. The script starts SQL Server, waits for readiness, runs this suite, then cleans up the container. The runner itself still opens two independent `sqlcmd` sessions.