# G06 Phase 2 Re-review — Test Branch

Review date: 2026-08-11
Previous internal score: **40/100**
Current internal engineering score: **91/100**

This is an internal readiness score, not an official course grade. It reflects executed code and retained evidence on branch `test` with the user-approved 100,000-row scale checkpoint.

## Score

| Area | Max | Score | Evidence |
|---|---:|---:|---|
| Requirement change and normalization | 12 | 11 | Output 08 now traces races, reports, approval semantics, semesters, and acknowledgement limitation. |
| Updated ERD/logical design | 10 | 9 | Output 09 count/cardinality defects corrected; final modeling choices documented. |
| Schema migration | 12 | 11 | Final-schema triggers/indexes parse and execute; optimized backstops installed. Clean Phase-1-copy replay remains recommended. |
| Concurrency design/implementation | 20 | 18 | One protected per-space approval operation, shared auto/staff paths, trigger backstops, maintenance checks, error handling. |
| Concurrency tests | 10 | 8 | Ten two-client scenarios pass; production procedures also received runtime fixtures. Fifty repeated production races remain a higher-confidence follow-up. |
| Generator and final load | 12 | 12 | Seeded streaming generator tests pass; 100k trigger-enabled load retained and validated in 46.813 s. |
| Analytical queries | 8 | 8 | All four final-schema procedures installed and executed on the retained dataset. |
| Index tuning | 10 | 10 | Four targets measured before/after with warm-up, five repetitions, IO/CPU sample, final-schema indexes. |
| Agent/repository/report quality | 6 | 4 | Exact `AGENT.md`, synchronized state, evidence and final Markdown handoff added; final course PDF is not produced in this engineering pass. |
| **Total** | **100** | **91** | **Target achieved.** |

## Closed blockers

- Production approval now serializes by space with transaction-owned `sp_getapplock`.
- Auto and staff approval share `dbo.USP_ApproveBookingProtected`.
- Direct approved writes are checked by trigger backstops using the same lock namespace.
- Trigger-safe 100k load completes in seconds rather than the earlier seven-hour estimate.
- Output 16 no longer references removed Phase 1 junction tables or hard-coded decision IDs.
- Output 15 contains measured values instead of example numbers.
- All eight BookingRequest/Review triggers are enabled and the final overlap scan returns zero pairs.
- Exact `AGENT.md` compatibility file is present.

## Final verification snapshot

- Booking requests: **100,019** (100,000 generated + 19 existing)
- Reviews: **68,360**
- Overlapping currently approved pairs: **0**
- Relevant enabled triggers: **8/8**
- Analytical procedures installed: **4/4**
- Generator unit tests: **7/7 passed**
- Two-client concurrency scenarios: **10/10 passed**
- Backend HTTP tests: **4/4 passed**, smoke test passed

## Known boundaries

- The 500,000-row server load is intentionally deferred by user instruction; generator-side 500k support remains available.
- The concurrency runner still demonstrates timing races in isolated tempdb tables; protected production-path fixtures were exercised separately, but 50 repeated production trials are not claimed.
- A final course-formatted `G06_Report_P2.pdf` is outside this completed engineering pass and should be assembled from the retained Markdown/SQL evidence if required for submission.