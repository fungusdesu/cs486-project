# G06 Phase 2 Database Code Review and Refactoring Evaluation

Review date: 2026-08-10  
Source requirement: `reference/CS486_Project_Phase02.pdf`  
Reviewed scope: Phase 2 outputs 08-16, supporting evidence in outputs 13-14, agent documentation, final-report status, and the optional localhost backend.

## 1. Executive verdict

**Reviewer score: 40/100 - not submission-ready.**

This is an internal engineering score, not an official course grade. The assignment brief does not publish numeric weights, so the rubric below weights the required deliverables by implementation risk and importance. The score reflects the repository in its current state, including explicit provisional markers and missing execution evidence.

The project has two notably strong foundations:

- Part 14 is a well-structured, seeded, streaming generator with bounded-memory validation and passing local tests.
- Part 13 demonstrates the intended concurrency scenarios with two independent SQL Server clients and honest scaffold-only evidence.

However, the submission currently fails the central Phase 2 guarantee. The production procedures do not reliably prevent overlapping approved bookings, instant and staff approval do not use one protected operation, and the successful concurrency evidence targets isolated lab tables rather than the migrated schema. The analytical queries use tables and columns removed by the migration. The index report labels its numbers as examples rather than measured results. The final Phase 2 report is absent.

### Submission gates

| Gate | Status | Reason |
|---|---|---|
| Final schema internally consistent | **Fail** | Status-code mismatches and design/migration contradictions remain. |
| No overlapping approved bookings under concurrency | **Fail** | Output 12 lacks one runtime-protected approval path; output 13 tests only isolated lab procedures. |
| All four analytical reports execute on final schema | **Fail** | Output 16 references legacy tables that output 10 removes. |
| Four required tuning targets measured before/after | **Fail** | Output 15 contains example values and obsolete indexes, not retained measurements or plans. |
| 100,000+ generated bookings over three academic years | **Pass for generation** | The retained run reports 500,000 bookings across 2023-2026 with zero Python validation errors. |
| Generated data loaded and validated in final database | **Not proven** | The evidence explicitly says the final SQL Server load is pending. |
| Required repository artifacts present | **Partial** | Outputs 08-16 exist, but `AGENT.md` and `G06_Report_P2.pdf` are absent. |

## 2. Scoring rubric

| Area | Max | Score | Assessment |
|---|---:|---:|---|
| Requirement-change analysis and normalization | 12 | 7 | Maintenance impact and approval policy are identified, but concurrency/report traceability and the final-schema 3NF proof are incomplete. |
| Updated ERD and logical design | 10 | 5 | Both diagrams exist, but cardinalities, entity counts, and acknowledgement semantics are inconsistent. |
| Schema migration | 12 | 6 | Substantial preservation/backfill work exists, but final validation is incomplete and runtime naming defects remain. |
| Concurrency design and implementation | 20 | 3 | The chosen isolation argument is incorrect for the core phantom race, and the final procedures do not share a protected approval operation. |
| Concurrency tests and evidence | 10 | 6 | Scenario coverage is strong, but only isolated procedures are tested and race-sensitive cases are not repeatedly exercised. |
| Procedural data generation and validation | 12 | 9 | Strong implementation and local evidence; final production load evidence and current-code evidence are still missing. |
| Analytical queries | 8 | 1 | Query intent is visible, but the script targets the removed Phase 1 schema and cannot be accepted as final. |
| Indexing and query tuning | 10 | 1 | Proposed indexes and invented example timings do not satisfy measured four-target tuning. |
| Agent update, repository quality, and group report | 6 | 2 | The skill is improved, but the exact agent file, current state tracking, and final report are incomplete. |
| **Total** | **100** | **40** | **Major refactoring and final evidence are required.** |

## 3. Highest-priority findings

### P0-1: The approved-booking invariant is not protected in production

The brief requires the non-overlap rule to hold regardless of instant or staff approval and even when operations execute simultaneously. Output 12 does not provide that guarantee.

Evidence:

- `outputs/12-concurrency-implementation-G06.sql:4-5` sets `REPEATABLE READ` and `XACT_ABORT` only in the deployment session. Those session options are not stored as execution-time behavior of every later procedure call.
- `outputs/12-concurrency-implementation-G06.sql:228-272` approves a request without checking other approved intervals for the same space and without taking a range lock or transaction-owned application lock.
- `outputs/12-concurrency-implementation-G06.sql:795-822` performs instant approval by changing only `RequestState`; it bypasses the `Review` triggers used for staff approvals.
- `outputs/10-schema-migration-G06.sql:1760-1822` checks overlaps in an `AFTER` trigger on `Review`, but concurrent inserts for different requests can both miss an uncommitted phantom under `REPEATABLE READ`.
- `outputs/11-concurrency-design-G06.md:168-170` explicitly dismisses phantoms and chooses repeatable read. That is the exact anomaly relevant when both sessions observe no conflicting approved row and then insert different approvals.
- `outputs/13-concurrency-tests-G06/sql/production-adapter.sql:1-5` is still a deliberate throwing placeholder, and the retained evidence states that isolated lab procedures were tested.

Required refactor:

1. Define one database operation for approval, for example `dbo.usp_ApproveBookingProtected`.
2. Make both instant and staff workflows call that operation inside the same transaction.
3. Acquire a transaction-owned `sp_getapplock` keyed by `space_id`, or prove a `SERIALIZABLE` key-range locking design supported by the correct index.
4. Inside the protected transaction, re-read the request, space policy, current approval state, overlapping approved requests, out-of-service maintenance, and advisory acknowledgement.
5. Insert/update all approval artifacts atomically and return the final result.
6. Add `SET XACT_ABORT ON`, `BEGIN TRY/BEGIN CATCH`, conditional rollback, and deterministic lock ordering inside the procedure.
7. Prevent or safely reject direct writes that bypass the protected operation.

### P0-2: Output 12 contains functional defects beyond the race condition

Several statements are incorrect even in a single-session execution:

- `outputs/12-concurrency-implementation-G06.sql:147-152` checks whether any bookable space exists, not whether `@space_id` is bookable.
- `outputs/12-concurrency-implementation-G06.sql:155-166` checks reservations without filtering by requested space and tests only an existing start against the requested end. The correct half-open overlap predicate is `existing_start < requested_end AND existing_end > requested_start` with the same `space_id`.
- `outputs/12-concurrency-implementation-G06.sql:113-114` permits equal start and end because it uses `<` rather than `<=`.
- `outputs/12-concurrency-implementation-G06.sql:193`, `:565`, `:683`, `:737`, and `:785` use status spellings that do not match the migration (`CANCELED` versus `CANCELLED`; `UNDER_CRIT_MAINT` versus `UNDER_CRITICAL_MAINTENANCE`).
- `outputs/12-concurrency-implementation-G06.sql:664-673` reverses the escalation guard: an advisory row triggers the message "already out-of-service".
- `outputs/12-concurrency-implementation-G06.sql:690-697` compares `Space.space_id` with a selected `space_status_id`.
- `outputs/12-concurrency-implementation-G06.sql:718-742` reverses the downgrade guard and looks up a nonexistent maintenance impact code `AVAILABLE` instead of `ADVISORY`.
- The procedures open transactions before validation and have no local error handler. A caller using default session settings can be left with an open or uncommittable transaction after a thrown error.

This file should be corrected through executable tests, not patched statement by statement without a final behavioral specification.

### P0-3: Output 16 targets the schema that output 10 removes

`outputs/10-schema-migration-G06.sql:1913-1919` treats `junction_table.Booking`, `junction_table.Maintaining`, and `junction_table.Review` as forbidden legacy tables after migration. Output 16 still uses all three:

- Approved hours: `outputs/16-analytical-queries-G06.sql:40-44`
- Weekday/hour report: `outputs/16-analytical-queries-G06.sql:67-72`
- Room finder: `outputs/16-analytical-queries-G06.sql:154-173`
- Maintenance escalation report: `outputs/16-analytical-queries-G06.sql:199-215`
- Proposed indexes: `outputs/16-analytical-queries-G06.sql:223-230`

The script also hard-codes `decision_id = 2`, ignores auto-approved requests, can duplicate a booking when review history contains multiple approved rows, and confuses maintenance status with maintenance impact in the room finder.

Required refactor:

- Rewrite all four reports using `dbo.BookingRequest`, `dbo.Review`, `dbo.Maintenance`, `dbo.MaintenanceSession`, and lookup codes from the final schema.
- Define "currently approved" once. It must include auto-approved requests and use the latest review when review history is retained.
- Validate `@semester_start < @semester_end` and `@period_start < @period_end`.
- Use half-open time intervals consistently.
- Decide and document whether the weekday/hour report counts booking start times or every occupied hour. Do not ship two incompatible interpretations without selecting the required one.
- Execute each procedure against a clean migrated database with generated data and retain result samples.

### P0-4: Output 15 is not admissible performance evidence

`outputs/15-index-tuning-report-G06.md:10` says the figures are example benchmark values. The assignment requires actual before/after execution plans and execution times for four targets: the conflict check, room finder, and two reporting queries other than the room finder.

The proposed indexes also use removed Phase 1 tables and cover only three generic structures. The report lacks actual plans, logical reads, CPU time, repeated elapsed time, dataset cardinalities tied to a load, warm-up policy, and environment details.

Required refactor:

1. Select two analytical reports in addition to the room finder.
2. Establish a reproducible baseline on the final 100k or 500k loaded dataset.
3. Capture actual execution plans and `SET STATISTICS IO, TIME ON` output.
4. Run warm-ups and multiple measured repetitions; report median and range, not a single optimistic value.
5. Add one index at a time, explain key order and `INCLUDE` columns, update statistics, and rerun the identical workload.
6. Discuss write cost, storage cost, lock behavior, and whether each index is used.
7. Store plan files or credential-free text evidence in the repository.

## 4. File-by-file assessment

### Output 08 - requirement change and 3NF analysis

Strengths:

- Correctly introduces `MaintenanceImpactLevel`, `advisory_acknowledged`, and `SpacePolicy.requires_approval` (`outputs/08-requirement-change-analysis-G06.md:4-11`).
- Recognizes multiple reviews and separates request lifecycle state from review decision.
- Attempts explicit candidate keys and functional dependencies.

Problems:

- The file does not analyze instant-vs-instant, instant-vs-staff, or staff-vs-staff races, although conflict identification is explicitly required.
- It does not trace the four reporting requirements to required attributes and relationships.
- A single booking-level Boolean cannot prove which of several simultaneous advisories were shown. The brief may permit a booking-level acknowledgement, but the team must defend how "all active advisories" are reconstructed. A `BookingAdvisoryAcknowledgement(booking_request_id, maintenance_id, acknowledged_at)` junction is the stronger design.
- The normalization section says there are 22 tables and 9 operational tables (`:48`), while output 09 later admits 23 tables and 10 operational tables.
- The proof validates `Maintenance` using attributes that output 09 and output 10 move into `MaintenanceSession`, and it omits a separate 3NF proof for the final `MaintenanceSession` relation.
- Repeating "no partial dependency and non-key dependency" is not a sufficient 3NF proof. State the candidate keys, minimal cover, prime attributes, and show for every nontrivial FD that the determinant is a superkey or the dependent is prime.

### Output 09 - updated ERD and logical design

Strengths:

- Both conceptual and logical diagrams are present.
- The logical model includes the new impact lookup and key operational attributes.
- The relationship summary is useful for reviewing intended participation.

Problems:

- `outputs/09-updated-erd-and-logical-design-G06.md:278-285` contradicts itself: 22 versus 23 total tables and 9 versus 10 operational tables.
- Many Mermaid Crow's Foot relationships are drawn in the wrong direction. For example, `User ||--o{ UserRole` visually says one user has many role rows, while the FK means one role can be referenced by many users. The prose table and diagram therefore disagree.
- `Space ||--|| SpacePolicy` renders one-to-one, while the relationship summary states that a policy may govern many spaces.
- The model has no per-advisory acknowledgement relation and no explicit escalation history. If current-state-only impact is intentional, state that decision and how affected bookings are captured at escalation time.
- The design does not define semester boundaries. Parameterized report dates can avoid a semester table, but the choice must be explicit and reproducible.

### Output 10 - schema migration

Strengths:

- Uses one transaction across batches, `XACT_ABORT`, backfills direct relationships, and attempts rerun/partial-migration recovery.
- Preserves legacy booking and maintenance relationships before removing junction tables.
- Adds structural validation before commit.

Problems:

- The migration renames the status to `UNDER_CRITICAL_MAINTENANCE` at `:493-495`, but `trg_space_maintenance_status` still requires the old `UNDER_MAINTENANCE` code at `:1683-1688`. A correctly updated space therefore fails the trigger.
- Final validation checks object presence but does not compare pre/post row counts, detect orphans across every migrated FK, or confirm semantic equivalence of legacy decisions and new states.
- There is no operator-facing rollback/recovery section or dry-run-on-copy procedure.
- The overlap trigger is a consistency backstop, not a proven concurrency solution.
- `outputs/10-schema-migration-G06.sql:1960` contains an unacceptable informal/profane comment admitting a removed validation check. Remove it and restore a justified check or document why it is unnecessary.
- Status vocabulary is inconsistent across outputs 09-12 and 14. Establish one code dictionary and test every referenced code.

### Output 11 - concurrency design

Strengths:

- Provides concrete interleaving exhibits and recognizes lost-update/check-then-act risks.
- Discusses transaction isolation levels and attempts to connect them to system operations.

Problems:

- Exhibit A calls the scenario a dirty read even though the schedule says the reader sees an older committed value. The real issue is an interleaving/check-then-act race, not necessarily a dirty read.
- Exhibit C analyzes two reviews of the same request, but the required critical case is two different overlapping requests for the same space.
- The conclusion that phantom reads are unimportant is incorrect for the required invariant.
- The design lacks transaction boundaries for one final protected approval path, lock resource/key, lock order, timeout/retry behavior, deadlock handling, direct-write policy, and proof that non-overlapping requests are not over-serialized.

### Output 12 - concurrency implementation

This is the main blocking file. In addition to the P0 findings, the implementation does not atomically create the reservation/approval artifacts described in output 11, and the instant path is represented only by a request state. Refactor it around a small number of cohesive, tested procedures rather than maintaining many independent procedures with duplicated validation.

### Output 13 - concurrency tests

Strengths:

- Uses two independent `sqlcmd` processes.
- Covers unsafe race, all three instant/staff combinations, non-overlap, boundary adjacency, advisory acknowledgement, out-of-service blocking, and escalation lookup.
- Cleans isolated objects and retains a clear evidence summary.

Problems:

- `outputs/13-concurrency-tests-G06/README.md:69-72` and the evidence clearly say the production mapping is provisional.
- Each race-sensitive scenario is executed once in `src/run-tests.mjs`; repeated trials are needed to make timing-dependent evidence meaningful.
- The committed summary omits elapsed times even though the raw ignored report contains them.
- Final assertions must inspect production `BookingRequest`, latest `Review`/auto-approval state, `Reservation`, maintenance, and acknowledgement state after calling the output 12 operation.

Required completion evidence: run the final adapter on a clean migrated database, repeat each race at least 50 times or justify another count, retain environment versions and machine-readable results, and show exactly one conflicting approval with both non-conflicting approvals succeeding.

### Output 14 - data generator

Strengths:

- Seeded Python CLI, streaming CSV generation, disk-backed bounded-memory validation, staging/bulk-load scripts, cleanup, and credential redaction are well designed.
- The retained evidence reports 500,000 bookings, 10,000 users, 100 spaces, 2,500 maintenance rows, four calendar years, zero duplicate approved slots, and zero validation errors.
- Local review reran all seven unit/reproducibility tests successfully.

Problems:

- The evidence explicitly states that it is not a completed SQL Server load (`outputs/14-data-generator-G06/evidence/fedora-500k-validation-2026-08-09.md:3-7,32-37`).
- The committed evidence predates later acknowledgement and adapter changes, so it is not a clean proof of the current generator revision.
- The README still mentions "detailed advisory acknowledgements" although the current implementation retains only the booking-level Boolean.
- Final completion requires retained `load-evidence.json`, final validation output, load time, final row counts, database size, and the exact code revision/seed.

### Output 15 - indexing report

Discard the example timing tables and rebuild this output from actual measurements. No unmeasured number should appear as a result. Proposed indexes must target the final query text and final schema, and the report must include two reporting queries other than the room finder.

### Output 16 - analytical queries

Rewrite against the migrated schema, define current approval correctly, include auto-approval, handle latest review history, validate parameters, and test boundary cases. At minimum retain expected-result fixtures for:

- a booking clipped by semester start/end;
- a boundary-adjacent booking;
- an auto-approved request;
- a request with approved then later rejected review history, if that lifecycle is allowed;
- an empty facility list and a multi-facility list;
- advisory versus out-of-service maintenance;
- an open-ended maintenance period.

### Agent documentation and final report

- The assignment explicitly names `AGENT.md`; the repository contains only `AGENTS.md`. Add a short `AGENT.md` pointer if the teaching scripts require the exact filename.
- The canonical skill contains substantial Phase 2 guidance for parts 13-14, but parts 08-12 and 15-16 remain labeled as placeholders. The final report should briefly explain the actual improvement process.
- `TODO.md` and parts of `MEMORY.md` describe outputs 10-12, 15, and 16 as empty even though they now contain code. Reconcile state documentation after owners accept the files.
- `G06_Report_P2.pdf` is absent, so all report-specific requirements currently receive no completion credit.
- The optional backend passes four mock HTTP tests and its smoke test, but its SQL procedure adapter remains dependent on the corrected output 12 interface. This is useful engineering work but is not a substitute for the required database evidence.

## 5. Recommended refactoring order

1. **Freeze the final vocabulary and logical model.** Resolve table count, Mermaid cardinalities, status codes, approval semantics, acknowledgement cardinality, latest-review semantics, and semester parameters.
2. **Correct and revalidate output 10.** Remove stale codes and comments; add pre/post row counts, orphan checks, semantic mapping checks, and recovery instructions. Execute it on a disposable copy of Phase 1 data.
3. **Redesign outputs 11-12 around one protected approval operation.** Use a per-space transaction lock or a proven serializable range-lock design, with error handling inside the procedure.
4. **Map output 13 to production.** Repeat all races, assert final tables, retain JSON/Markdown evidence, and test direct-write bypass attempts.
5. **Rewrite and execute output 16.** Add deterministic fixtures and verify all four reports on the final schema.
6. **Rerun output 14 and complete the final load.** Generate from the current revision, load 500,000 rows, run final validation, and retain credential-free evidence.
7. **Rebuild output 15 from measurements.** Benchmark the conflict check, room finder, and two selected reports before and after indexing.
8. **Reconcile documentation and assemble `G06_Report_P2.pdf`.** Every claim should point to a committed script or evidence file.

## 6. Suggested acceptance checklist

- [ ] Clean Phase 1 database migrates successfully with preserved row counts.
- [ ] Migration rerun behavior is documented and tested.
- [ ] All lookup/status codes are defined once and referenced consistently.
- [ ] Instant and staff approval call the same protected database operation.
- [ ] Fifty or more repeated trials per conflict combination produce one winner.
- [ ] Non-overlap and boundary adjacency both allow two winners.
- [ ] Out-of-service maintenance blocks approval inside the same protected transaction.
- [ ] Advisory acknowledgement is traceable to all active advisories or the Boolean design is explicitly defended.
- [ ] Escalation returns already-approved overlapping bookings.
- [ ] All four report procedures compile and return verified results on the final schema.
- [ ] Current approval includes auto-approved requests and correct latest-review semantics.
- [ ] Current generator revision produces and validates at least 100,000 rows across three academic years.
- [ ] Final SQL Server load evidence is retained with row counts, timing, and database size.
- [ ] Four tuning targets have actual before/after plans, IO, CPU, and repeated elapsed time.
- [ ] `AGENT.md`, `SKILL.md`, outputs 08-16, and `G06_Report_P2.pdf` meet exact naming requirements.
- [ ] `TODO.md` and `MEMORY.md` match the submitted branch.

## 7. Oral-defense questions teachers may ask

The notes after each question describe what a strong answer should cover.

1. **Why is the interval-overlap predicate `existing_start < new_end AND existing_end > new_start`?**  
   Explain half-open intervals, true overlap, and why `end = next_start` is allowed.

2. **Why is `REPEATABLE READ` insufficient for two different overlapping requests?**  
   Explain that it protects rows already read but not the absence of a qualifying row; a concurrent insert is a phantom unless a suitable range or application lock serializes the decision.

3. **What exactly is the lock resource in your final approval procedure?**  
   State whether it is a per-space application lock or an indexed key range, when it is acquired, its owner, timeout, and release behavior.

4. **How do instant and staff approval share the same invariant enforcement?**  
   Trace both call paths to one protected database procedure and identify which differences are only metadata, such as reviewer identity.

5. **What prevents a developer from inserting an approved review directly?**  
   Discuss permissions, triggers as a backstop, and why application conventions alone are insufficient.

6. **Could your locking design deadlock? How would the client respond?**  
   Discuss deterministic lock order, short transactions, SQL Server deadlock victim errors, bounded retries, and idempotent request identifiers.

7. **Why might one Boolean acknowledgement be inadequate when several advisories are active?**  
   Explain the loss of advisory identity and auditability, and compare the Boolean with a booking-maintenance acknowledgement junction.

8. **When an advisory is escalated, how do you find affected approved bookings without losing the evidence later?**  
   Explain the overlap query, current approval semantics, transaction timing, and whether escalation history or a persisted notification worklist is required.

9. **Why separate `RequestState` from `RequestDecision`?**  
   Distinguish lifecycle state such as pending/cancelled/auto-approved from a staff review decision and explain review history.

10. **What does "currently approved" mean if a request has multiple reviews?**  
    Define the ordering rule, tie breaker, allowed transitions, and how analytical queries avoid counting historical approvals twice.

11. **Show that `MaintenanceSession` is in 3NF.**  
    Give its candidate key and functional dependencies and show why every determinant is a superkey or every dependent is prime.

12. **How did the migration prove that no Phase 1 data was lost?**  
    Cite pre/post row counts, mapping checks, orphan checks, constraint validation, and the recovery plan.

13. **Why should reports join lookup codes rather than assume `decision_id = 2`?**  
    Explain surrogate-key instability across migrations and environments.

14. **Does "bookings by weekday and hour" mean booking start hour or every occupied hour?**  
    State the chosen interpretation, justify it from the business question, and explain how multi-hour bookings are counted.

15. **How do you calculate approved hours for a booking that crosses a semester boundary?**  
    Explain interval clipping with `MAX(start)` and `MIN(end)` and why negative/zero contributions are excluded.

16. **How does the room finder enforce a required facility list?**  
    Explain relational division with double `NOT EXISTS`, empty-list behavior, duplicate facility inputs, capacity, booking conflicts, and out-of-service maintenance.

17. **Why did you choose each index key order and included column?**  
    Relate the leading key to equality/range predicates, join columns, covering behavior, cardinality, and write/storage cost.

18. **How were before/after tuning results made comparable?**  
    Discuss identical data and parameters, warm-ups, cache policy, updated statistics, repeated runs, median/range, actual plans, logical reads, CPU, and elapsed time.

19. **How does the generator prove reproducibility and bounded memory at 500,000 rows?**  
    Explain seed control, streaming writers, hash comparison, disk-backed validation, measured peak RSS, and deterministic configuration.

20. **Why stage CSV data before loading final tables?**  
    Explain fast bulk loading, type/foreign-key validation, set-based transformation, transactional rollback, rerun cleanup, and separation of malformed input from production tables.

## 8. Verification performed during this review

- Read and visually checked all four pages of the Phase 2 PDF.
- Inventoried every required output and supporting evidence file.
- Ran `python -m unittest discover -s test` in output 14: **7 tests passed**.
- Ran `npm run check` in `backend`: **passed**.
- Ran `npm test` in `backend`: **4 tests passed and smoke test passed**.
- Did not execute migration or concurrency procedures against the user's `School` database because this evaluation did not authorize mutating that database.
- Treated retained SQL Server evidence as valid only for the exact isolated or generation-only scope stated in each evidence file.
