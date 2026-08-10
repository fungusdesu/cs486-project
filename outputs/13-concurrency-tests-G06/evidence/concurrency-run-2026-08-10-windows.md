# G06 Part 13 Concurrency Evidence — 2026-08-10

This is curated evidence from the successful local SQL Server run. The runner
used independent `sqlcmd` processes and removed its isolated tables and
procedures afterward.

## Environment

- OS: Windows (`win32`)
- Node.js: v24.11.0
- SQL Server: local Windows named instance
- Database: `tempdb`
- Procedure scope: isolated lab procedures; production output-12 mapping remains provisional

## Results

| Scenario | Expected approved | Actual approved | Passed |
|---|---:|---:|---|
| instant-vs-instant | 1 | 1 | yes |
| instant-vs-staff | 1 | 1 | yes |
| staff-vs-staff | 1 | 1 | yes |
| unsafe-isolated-race | 2 | 2 | yes |
| non-overlapping | 2 | 2 | yes |
| boundary-adjacent | 2 | 2 | yes |
| advisory-without-acknowledgement-rejected | 0 | 0 | yes |
| advisory-with-acknowledgement-approved | 1 | 1 | yes |
| out-of-service-overlap-rejected | 0 | 0 | yes |
| maintenance-escalation-identifies-approved-booking | 1 | 1 | yes |

Overall result: **PASS**.

Raw machine-readable output is retained locally under ignored `results/`.