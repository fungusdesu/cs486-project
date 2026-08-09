# G06 Part 13 Concurrency Evidence — 2026-08-09

This is the curated evidence from the successful local SQL Server run. The runner used two independent `sqlcmd` processes and cleaned up its isolated tables/procedures afterward.

## Environment

- OS: Windows (`win32`)
- Node.js: v24.11.0
- SQL Server: `THIENLOC-ASUS-TUF-A14\MSSQL2025`
- Database: `tempdb`
- Procedure scope: isolated lab procedures; production output-12 adapter remains provisional

## Results

| Scenario | Expected approved | Actual approved | Elapsed ms | Passed |
|---|---:|---:|---:|---|
| instant-vs-instant | 1 | 1 | 2031 | yes |
| instant-vs-staff | 1 | 1 | 2031 | yes |
| staff-vs-staff | 1 | 1 | 1994 | yes |
| unsafe-isolated-race | 2 | 2 | 2027 | yes |
| non-overlapping | 2 | 2 | 2253 | yes |
| boundary-adjacent | 2 | 2 | 2231 | yes |
| advisory acknowledged | 1 | 1 | 0 | yes |
| out-of-service overlap blocked | 1 | 1 | 0 | yes |
| maintenance escalation affected-booking query | 0 | 0 | 0 | yes |

Overall result: **PASS**.

Raw machine-readable output is retained locally at `results/latest.json`; that directory is ignored because each run overwrites `latest.*`.