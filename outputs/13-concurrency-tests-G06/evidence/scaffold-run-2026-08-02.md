# Step 13 Scaffold Run — 2026-08-02

This is isolated scaffold evidence, not final step 13 evidence. The runner must be adapted to the approved output 12 production procedures.

## Environment

- Node.js: 24.11.0
- npm: 11.6.1
- SQL Server instance: local `MSSQL2025`
- Test database: `tempdb`
- Authentication: Windows integrated authentication through `sqlcmd`

## Results

| Scenario | Expected approved | Actual approved | Result |
|---|---:|---:|---|
| Unsafe check-then-insert race | 2 | 2 | passed |
| Protected transaction-owned per-space lock | 1 | 1 | passed |

The protected run admitted one booking and rejected the second with SQL Server error 51002: an overlapping approved booking already exists.

The test objects were removed automatically after the run.
