# G06 Phase 2 TODO

Last updated: 2026-08-11
Audited branch: `test` (created from current `dev`)
Source: `reference/CS486_Project_Phase02.pdf`

## Current audited state

- Step 08 contains maintenance-impact changes, an instant-approval policy proposal, schema refinements, functional dependencies, and 3NF checks.
- Step 08 still needs explicit concurrency-conflict analysis, reporting traceability, and validation of its advisory-acknowledgement design.
- Step 09 links the updated conceptual ERD; its logical-design section is still a placeholder.
- Outputs 10, 12, 15, and 16 are implemented and runtime-verified; Output 11 documents the adopted protected design. Parts 13-14 and the backend have passing executable suites.
- Scaffold implementations now exist for the Python data generator, `sqlcmd` concurrency runner, and localhost Express backend; final schema/procedure adapters remain pending outputs 09–12.

## Ground rules

- Phase 2 extends the existing Phase 1 SQL Server database and agent workflow.
- Generate at least three academic years of realistic data containing at least 100,000 booking records.
- Increase the dataset toward 500,000 bookings only if needed to make indexing improvements measurable.
- Preserve requirement traceability and complete work in dependency order.
- Codex and Antigravity are the primary agents.
- Keep one active owner per file to prevent conflicting edits.

## Ownership

| Deliverable | Owner | Status |
|---|---|---|
| `08-requirement-change-analysis-G06.md` | Codex | done — final concurrency/report traceability added |
| `09-updated-erd-and-logical-design-G06.md` | Antigravity | done — logical diagram present; counts/cardinalities reconciled |
| `10-schema-migration-G06.sql` | Codex | done — parser/runtime-verified final-schema triggers and indexes |
| `11-concurrency-design-G06.md` | Antigravity | done — final per-space lock design recorded |
| `12-concurrency-implementation-G06.sql` | Codex | done — protected shared approval path runtime-tested |
| `13-concurrency-tests-G06/` | User | in progress — isolated runner passes unsafe/safe test |
| `14-data-generator-G06/` | User | in progress — 100,000-row trigger-enabled SQL Server load retained; 500,000 server run deferred |
| `15-index-tuning-report-G06.md` | Antigravity with Codex SQL support | done — four measured targets on retained 100k dataset |
| `16-analytical-queries-G06.sql` | Codex | done — four final-schema procedures runtime-verified on retained 100k dataset |
| Basic Node.js/Express backend | User | in progress — localhost procedure adapter scaffold tested |
| Agent and Markdown documentation audit | User | done — exact AGENT.md and final handoff added |
| `G06_Report_P2.pdf` | Shared; final agent verification | not started |

## 0. Repository preparation

- [ ] Reconcile current `data`/`dev` changes back into `agent` without losing `MEMORY.md` or `TODO.md`.
- [x] Phase 2 output placeholders 08–12, 15, and 16 exist in the integrated tree.
- [x] Phase 1 DDL, sample data, queries, diagrams, and report files remain present.
- [x] Asset folders were reorganized into `assets/png/`, `assets/svg/`, and `assets/wysiwyg/`; dependent Phase 1 Markdown paths were updated.
- [x] Keep `reference/CS486_Project_Phase02.pdf` as the Phase 2 source of truth.
- [x] Create `outputs/13-concurrency-tests-G06/` and `outputs/14-data-generator-G06/` under the user's scaffold-only override.

## 1. User: agent and Markdown audit

- [x] Audit `AGENTS.md` and the database-pipeline skill.
- [x] Keep one canonical skill with modular Phase 1 and Phase 2 reference files.
- [x] Add outputs `08`–`16`, prerequisite order, completion checks, and traceability rules.
- [x] Document Codex and Antigravity as the primary agents.
- [x] Resolve the assignment's `AGENT.md` filename versus the repository's `AGENTS.md`.
  - [x] Added a short `AGENT.md` pointer to canonical `AGENTS.md`.
- [x] Migrate the canonical skill to `.codex/skills/db-design-pipeline/SKILL.md`.
- [x] Review and update `scripts/sync-skills.sh`.
- [ ] Update stale Phase 1-only or four-tool wording in:
  - [ ] `README.md`
  - [x] Removed obsolete `PROMPTS.md`; use `AGENTS.md`, `MEMORY.md`, and `md/thienloc.md`.
  - [x] `md/pipeline.md`
  - [ ] `md/setup.md`
  - [ ] `md/usage.md`

## 2. Requirement and design work

- [ ] Codex: revise and finish `08-requirement-change-analysis-G06.md`.
  - [x] Introduce `MaintenanceImpactLevel` with `ADVISORY` and `OUT_OF_SERVICE`.
  - [x] Add `maintenance_impact_level_id` to the proposed maintenance design.
  - [x] Propose `SpacePolicy.requires_approval` for instant versus staff approval.
  - [x] Document schema refinements, functional dependencies, and 3NF checks.
  - [ ] Validate advisory acknowledgement cardinality: the current `BookingRequest.advisory_acknowledged` Boolean does not identify which of several active advisories were shown.
  - [ ] Analyze instant approval and staff approval races.
  - [ ] Trace all four reporting requirements.
  - [ ] Record unresolved business choices rather than guessing.
- [ ] Antigravity: complete `09-updated-erd-and-logical-design-G06.md`.
  - [x] Add and link the updated conceptual ERD.
  - [x] Model maintenance impact levels in the updated conceptual design.
  - [ ] Produce the updated logical ERD; the document currently contains `(logical goes here)`.
  - [ ] Decide whether to model per-maintenance advisory acknowledgements rather than one booking-level Boolean.
  - [ ] Determine whether impact-change history is needed for escalation auditing.
  - [x] Propose policy-level `requires_approval` for instant approval.
  - [ ] Define semesters or academic terms for reproducible reporting.
  - [ ] Reconcile the step 08 functional-dependency/3NF analysis with the final logical ERD and migration schema.

## 3. Migration

- [ ] Codex: implement `10-schema-migration-G06.sql`.
- [ ] Preserve Phase 1 data or clearly document every transformation.
- [ ] Replace the Phase 1 assumption that all maintenance makes a space unusable.
- [ ] Add rollback or recovery instructions.
- [ ] Make the migration safe to validate on a copy of the Phase 1 database.
- [ ] Add post-migration row-count, constraint, and orphan checks.

## 4. Concurrency design and implementation

- [ ] Antigravity: complete `11-concurrency-design-G06.md`.
- [ ] Demonstrate the check-then-approve race involving overlapping bookings.
- [ ] Cover instant-versus-instant, instant-versus-staff, and staff-versus-staff approval.
- [ ] Document transaction boundaries, isolation behavior, lock order, and failure handling.
- [ ] Codex: implement `12-concurrency-implementation-G06.sql`.
- [ ] Route instant and staff approval through the same protected database operation.
- [ ] Prefer database-level protection, such as a transaction-owned lock per space or a proven serializable locking design.
- [ ] Check out-of-service maintenance and approved-booking overlap inside the protected transaction.
- [ ] Store all applicable advisory acknowledgements.
- [ ] Ensure direct table writes cannot silently bypass the booking invariant.

## 5. User: concurrency tests

- [x] Create `13-concurrency-tests-G06/`.
- [x] Add a README with setup, execution, expected result, and cleanup instructions.
- [x] Build an automated runner using two independent `sqlcmd` sessions.
- [ ] Test:
  - [ ] instant approval versus instant approval;
  - [ ] instant approval versus staff approval;
  - [ ] staff approval versus staff approval;
  - [ ] overlapping requests where only one approval may succeed;
  - [ ] non-overlapping and boundary-adjacent requests where both may succeed;
  - [ ] advisory maintenance with acknowledgement;
  - [ ] out-of-service maintenance blocking an overlapping approval;
  - [ ] escalation returning already-approved affected bookings.
- [x] Save repeatable isolated scaffold evidence; replace it with production-procedure evidence after step 12.

## 6. User: token-free data generator

- **Audit result:** the generator supports and validates 500,000 rows; the finalized adapter loaded and validated 100,000 generated bookings on SQL Server with all triggers enabled in 46.813 seconds. The 500,000-row server run is deferred by user instruction.
- [x] Create `14-data-generator-G06/`.
- [x] Build a seeded Python CLI generator so records are created procedurally without consuming agent tokens.
- [x] Use lazy iterators and streaming instead of recursive calls or in-memory row accumulation.
- [x] Generate at least three academic years and validate a 500,000-booking run.
- [x] Include maintenance, cancellations, no-shows, advisory acknowledgements, approved/rejected/pending/instant cases, and realistic time/space/capacity/academic-year distributions.
- [x] Use only synthetic identities.
- [x] Record the random seed and configuration.
- [x] Provide and verify SQL Server staging tables and `bcp`/`sqlcmd` bulk loading with 500,000 bookings.
- [x] Validate row counts, unique identifiers, generated foreign-key references, time ranges, approved slots, and required distributions.
- [x] Record scaffold generation, validation, staging-load time, generated size, counts, seed, and environment.
- [x] Support increasing the booking count to 500,000 through one CLI parameter.
- [x] Finalize the staging-to-production mapping and final SQL validation against output 10.
- [x] Execute the finalized mapping on SQL Server and retain credential-free 100,000-row load timing, final row-count output, trigger status, and database size.

Suggested layout:

```text
outputs/14-data-generator-G06/
├── package.json
├── README.md
├── config.example.json
├── src/
│   ├── generate.mjs
│   ├── load.mjs
│   ├── random.mjs
│   └── distributions/
└── sql/
    └── validate-generated-data.sql
```

## 7. User: basic Node.js/Express backend

- **Audit result:** the Express scaffold exists and passes HTTP safety tests; its stored-procedure mappings remain deliberately unconfigured.
- [x] Create a separate `backend/` project.
- [x] Add pooled SQL Server connectivity, environment configuration, and centralized error handling.
- [ ] Make the API call protected database procedures; do not rely on an in-process Node mutex for booking correctness.
- [ ] Implement basic endpoints:
  - [ ] `POST /api/bookings`
  - [ ] `POST /api/bookings/:id/approve`
  - [ ] `POST /api/bookings/:id/reject`
  - [ ] `GET /api/spaces/available`
  - [ ] `POST /api/maintenance`
  - [ ] `PATCH /api/maintenance/:id/impact`
  - [ ] `GET /api/maintenance/:id/affected-bookings`
  - [ ] four reporting endpoints corresponding to the Phase 2 reports
  - [ ] health check
- [x] Keep the data generator as a CLI rather than exposing it as a public HTTP endpoint.
- [x] Add a README and example environment file without committing credentials.

## 8. Analytical queries and index tuning

- [x] Codex: implement all four reports in `16-analytical-queries-G06.sql`.
  - [x] Approved booking hours per space for a semester.
  - [x] Approved booking count by weekday and hour for a semester.
  - [x] Available spaces matching capacity and a required facility list for a time range.
  - [x] Approved bookings affected by maintenance escalation to out-of-service.
- [x] Select two reports other than the room finder for detailed tuning.
  - [x] Approved hours per space.
  - [x] Bookings by weekday and hour.
- [x] Tune four targets:
  - [x] booking conflict check;
  - [x] room finder;
  - [x] selected reporting query 1;
  - [x] selected reporting query 2.
- [x] Antigravity/Codex: write `15-index-tuning-report-G06.md`.
- [x] Compare actual plan behavior, elapsed time, CPU time, and logical reads before and after indexing.
- [x] Record dataset size and test environment.
- [x] Test repeatedly with a warm-up policy and report representative measurements.
- [ ] Deferred by user: run the 500,000-row SQL Server benchmark later; retain the successful 100,000-row dataset now.

## 9. Final report and validation

- [ ] Create `G06_Report_P2.pdf`.
- [ ] Include group members and individual queries.
- [ ] Include LLM models and the agent-improvement process.
- [ ] Include concurrency conflicts, proposed solutions, and test results.
- [ ] Include indexing and query-tuning results.
- [ ] Include functional dependencies and 3NF proofs or decomposition steps.
- [ ] Verify every report claim against committed scripts and captured evidence.
- [ ] Run a final requirement-to-design-to-SQL traceability check.
- [ ] Run a clean-database migration, data generation, concurrency test, query, and backend smoke-test sequence.

## Recommended execution order

1. Reconcile current `data`/`dev` into `agent` while preserving project memory and this TODO.
2. Finish the concurrency, reporting, and acknowledgement-cardinality analysis in output `08`.
3. Complete the logical ERD and approve output `09`.
4. Complete the agent/skill documentation audit against the approved Phase 2 workflow.
5. Implement and validate output `10`.
6. Complete outputs `11` and `12`.
7. Build and run outputs `13` and `14`, plus the basic backend.
8. Implement output `16`.
9. Capture baseline measurements, add indexes, and complete output `15`.
10. Assemble and verify `G06_Report_P2.pdf`.

## Fedora/Linux handoff (2026-08-09)

- [x] Windows SQL Server verification completed: all nine part 13 scenarios passed.
- [ ] Friend: run the Fedora checklist in `md/thienloc.md` using bash.
- [ ] Friend: start SQL Server 2022 Developer in Docker and run `npm test` from `outputs/13-concurrency-tests-G06/`.
- [ ] Friend: run the 100,000-booking generator and `validate`; optionally repeat at 500,000 bookings.
- [ ] Friend: run `backend/npm test` and verify `/api/health` on localhost.
- [ ] Friend: retain Docker/Fedora version output and `results/latest.{json,md}` as evidence.
- [ ] Final owner: replace provisional isolated/procedure adapters after outputs 09–12 are approved.
