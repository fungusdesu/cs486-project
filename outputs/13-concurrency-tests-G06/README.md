# G06 Step 13 — Concurrency Test Scaffold

This scaffold demonstrates an unsafe check-then-insert race and its prevention using a SQL Server transaction-owned `sp_getapplock` lock per space.

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

Run `sql/cleanup.sql` to remove the isolated objects.

## Scaffold limitation

This is an explicitly authorized out-of-order scaffold. Step 13 is not done until the runner tests output 12's production procedures and includes all scenarios listed in `thienloc.md`.
