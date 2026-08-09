# G06 Phase 2 TODO

Last updated: 2026-07-31  
Working branch: `agent`  
Source: `reference/CS486_Project_Phase02.pdf`

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
| `08-requirement-change-analysis-G06.md` | Codex | not started |
| `09-updated-erd-and-logical-design-G06.md` | Antigravity | not started |
| `10-schema-migration-G06.sql` | Codex | not started |
| `11-concurrency-design-G06.md` | Antigravity | not started |
| `12-concurrency-implementation-G06.sql` | Codex | not started |
| `13-concurrency-tests-G06/` | User | not started |
| `14-data-generator-G06/` | User | not started |
| `15-index-tuning-report-G06.md` | Antigravity with Codex SQL support | not started |
| `16-analytical-queries-G06.sql` | Codex | not started |
| Basic Node.js/Express backend | User | not started |
| Agent and Markdown documentation audit | User | not started |
| `G06_Report_P2.pdf` | Shared; final agent verification | not started |

## 0. Repository preparation

- [ ] Reconcile newer `dev` changes with the `agent` branch without losing `MEMORY.md`.
- [ ] Bring the Phase 2 output placeholders onto `agent`.
- [ ] Confirm Phase 1 DDL, sample data, queries, diagrams, and report changes that must be retained.
- [ ] Keep `reference/CS486_Project_Phase02.pdf` as the Phase 2 source of truth.

## 1. User: agent and Markdown audit

- [ ] Audit `AGENTS.md` and the database-pipeline skill.
- [ ] Decide whether Phase 2 extends the existing skill or uses a separate Phase 2 workflow.
- [ ] Add outputs `08`–`16`, prerequisite order, completion checks, and traceability rules.
- [ ] Document Codex and Antigravity as the primary agents.
- [ ] Resolve the assignment's `AGENT.md` filename versus the repository's `AGENTS.md`.
  - [ ] Prefer a short `AGENT.md` pointer to `AGENTS.md` if exact filename compliance is required.
- [ ] Edit `.opencode/skills/db-design-pipeline/SKILL.md` first.
- [ ] Synchronize `.openclaw/skills/db-design-pipeline/SKILL.md` if OpenClaw support is retained.
- [ ] Review `scripts/sync-skills.sh`.
- [ ] Update stale Phase 1-only or four-tool wording in:
  - [ ] `README.md`
  - [ ] `PROMPTS.md`
  - [ ] `md/pipeline.md`
  - [ ] `md/setup.md`
  - [ ] `md/usage.md`

## 2. Requirement and design work

- [ ] Codex: complete `08-requirement-change-analysis-G06.md`.
  - [ ] Trace maintenance impact levels: `ADVISORY` and `OUT_OF_SERVICE`.
  - [ ] Trace advisory notification and acknowledgement requirements.
  - [ ] Analyze instant approval and staff approval races.
  - [ ] Trace all four reporting requirements.
  - [ ] Record unresolved business choices rather than guessing.
- [ ] Antigravity: complete `09-updated-erd-and-logical-design-G06.md`.
  - [ ] Model maintenance impact levels.
  - [ ] Model booking-to-maintenance advisory acknowledgements.
  - [ ] Determine whether impact-change history is needed for escalation auditing.
  - [ ] Model which space types permit instant approval.
  - [ ] Define semesters or academic terms for reproducible reporting.
  - [ ] Identify functional dependencies and prove every relation satisfies at least 3NF.

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

- [ ] Create `13-concurrency-tests-G06/`.
- [ ] Add a README with setup, execution, expected result, and cleanup instructions.
- [ ] Build an automated runner using two or more independent SQL connections.
- [ ] Test:
  - [ ] instant approval versus instant approval;
  - [ ] instant approval versus staff approval;
  - [ ] staff approval versus staff approval;
  - [ ] overlapping requests where only one approval may succeed;
  - [ ] non-overlapping and boundary-adjacent requests where both may succeed;
  - [ ] advisory maintenance with acknowledgement;
  - [ ] out-of-service maintenance blocking an overlapping approval;
  - [ ] escalation returning already-approved affected bookings.
- [ ] Save repeatable test evidence for the Phase 2 report.

## 6. User: token-free data generator

- [ ] Create `14-data-generator-G06/`.
- [ ] Build a seeded Node.js CLI generator so records are created procedurally without consuming agent tokens.
- [ ] Use iterative batches instead of one recursive call per row; deep recursion at 100,000 records risks stack overflow.
- [ ] Generate at least three academic years and at least 100,000 booking records.
- [ ] Include:
  - [ ] maintenance;
  - [ ] cancellations;
  - [ ] no-shows;
  - [ ] advisory acknowledgements;
  - [ ] approved, rejected, pending, and instant-approval cases;
  - [ ] realistic weekday, hour, space, facility, capacity, and semester distributions.
- [ ] Use only synthetic identities.
- [ ] Record the random seed and configuration.
- [ ] Load data in bounded batches or through SQL Server bulk-loading facilities.
- [ ] Validate row counts, unique identifiers, foreign keys, constraints, time ranges, and distributions.
- [ ] Record generation time, load time, database size, and environment.
- [ ] Support increasing the booking count toward 500,000 without changing the generator design.

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

- [ ] Create a separate `backend/` project.
- [ ] Add pooled SQL Server connectivity, environment-based configuration, request validation, and centralized error handling.
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
- [ ] Keep the data generator as a CLI rather than exposing it as a public HTTP endpoint.
- [ ] Add a README and example environment file without committing credentials.

## 8. Analytical queries and index tuning

- [ ] Codex: implement all four reports in `16-analytical-queries-G06.sql`.
  - [ ] Approved booking hours per space for a semester.
  - [ ] Approved booking count by weekday and hour for a semester.
  - [ ] Available spaces matching capacity and a required facility list for a time range.
  - [ ] Approved bookings affected by maintenance escalation to out-of-service.
- [ ] Select two reports other than the room finder for detailed tuning.
  - [ ] Recommended: approved hours per space.
  - [ ] Recommended: bookings by weekday and hour.
- [ ] Tune four targets:
  - [ ] booking conflict check;
  - [ ] room finder;
  - [ ] selected reporting query 1;
  - [ ] selected reporting query 2.
- [ ] Antigravity: write `15-index-tuning-report-G06.md`.
- [ ] Compare actual execution plans, elapsed time, CPU time, and logical reads before and after indexing.
- [ ] Record dataset size and test environment.
- [ ] Test repeatedly with a warm-up policy and report representative measurements.
- [ ] Increase toward 500,000 bookings only if 100,000 does not show meaningful differences.

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

1. Reconcile `dev` into `agent` while preserving project memory.
2. Complete the agent/skill documentation audit.
3. Complete and approve outputs `08` and `09`.
4. Implement and validate output `10`.
5. Complete outputs `11` and `12`.
6. Build and run outputs `13` and `14`, plus the basic backend.
7. Implement output `16`.
8. Capture baseline measurements, add indexes, and complete output `15`.
9. Assemble and verify `G06_Report_P2.pdf`.
