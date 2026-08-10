# G06 Step 13 — Concurrency Tests

This runner demonstrates an unsafe check-then-insert race and its prevention using a SQL Server transaction-owned `sp_getapplock` lock per space.

It uses isolated `dbo.ConcurrencyTestBooking` tables until outputs 09–12 are approved. The final submission must adapt the procedure interface to the approved production operation.

## Requirements

- Node.js 18 or later
- SQL Server with `sqlcmd` on `PATH`
- `DB_SERVER`, `DB_DATABASE`, and optional `DB_USERNAME`/`DB_PASSWORD` environment variables

## Run from this directory

PowerShell:

```powershell
Copy-Item .env.example .env
npm install
npm test
```

bash, Fedora, Linux, macOS, or WSL:

```bash
cp .env.example .env
npm install
npm test
```

The runner launches two independent `sqlcmd` processes. A second runner terminal is not required. If `DB_USERNAME` is empty, it uses Windows integrated authentication; on Linux use SQL authentication with `DB_USERNAME` and `DB_PASSWORD`.

For a local SQL Server named instance on Windows:

```powershell
$env:DB_SERVER='.\MSSQL2025'
$env:DB_DATABASE='tempdb'
$env:SQLCMD_TRUST_CERTIFICATE='true'
npm test
```

For SQL Server in Docker on any supported host:

```bash
export DB_SERVER='localhost,1433'
export DB_DATABASE='tempdb'
export DB_USERNAME='sa'
export DB_PASSWORD='your-local-password'
export SQLCMD_TRUST_CERTIFICATE='true'
npm test
```

## What `npm test` does

1. Creates isolated lab tables and procedures.
2. Opens concurrent SQL Server requests.
3. Demonstrates the unsafe race.
4. Verifies protected approval allows only one overlapping booking.
5. Tests instant/staff approval combinations, non-overlap, boundary adjacency, advisory acknowledgement, out-of-service blocking, and escalation lookup.
6. Writes ignored machine-readable output to `results/latest.json` and `results/latest.md`.
7. Cleans the isolated objects unless `KEEP_TEST_OBJECTS=true`.

Committed summaries belong under `evidence/`. The current Windows run is recorded in `evidence/concurrency-run-2026-08-10-windows.md`; it contains no machine directory paths.

## Docker shortcut

From the repository root, use `scripts/run-docker-phase2.ps1` on Windows or `scripts/run-docker-phase2.sh` on Fedora/bash. The script starts SQL Server, waits for readiness, runs this suite, then removes the container. Set `KEEP_CONTAINER=true` or use `-KeepContainer` when debugging.

## Provisional interface boundary

The runner currently targets isolated procedures because outputs 09–12 are not approved. Before final submission, replace only the adapter procedure names and parameters in `src/database.mjs` with the approved output 12 interface and rerun the same scenarios against a clean migrated database.