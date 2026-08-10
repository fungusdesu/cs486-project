# MEMORY.md — Project State (read this first, every session)

Last updated: 2026-08-10 by Codex (Parts 13–14 refinement)

## Group info
- Group number: G06
- DBMS: Microsoft SQL Server (default)

## Pipeline status

| Step | File | Status | Notes |
|---|---|---|---|
| 1. Business req analysis | `01-business-req-analysis-G06.md` | done | Hand-written by team; includes schema design and inquiries |
| 2. Conceptual ERD | `02-erd-design-G06.md` | done | Chen notation; references `assets/conceptual.svg` (drawio source at `assets/conceptual.drawio`); refined version at `assets/refined_conceptual.svg` |
| 3. Logical design | `03-logical-design-G06.md` | done | Crow's Foot notation; references `assets/logical.svg`; refined version at `assets/refined_logical.svg` (source: `assets/refined_logical.mmd`) |
| 4. Design validation | `04-design-validation-G06.md` | done | Conceptual refinement, reference entity domains, SpacePolicy entity added, enum-like attributes promoted |
| 5. DDL | `05-db-definition-G06.sql` | done | SET NOEXEC ON removed; needs final review for FK order and string literal correctness |
| 6. Sample data | `06-sample-data-G06.sql` | done | 32 KB of INSERT statements |
| 7. Query design | `07-query-design-G06.sql` | done | 15 business queries covering history, maintenance, utilization, availability, equipment lookup, and reporting |

Status values: `not started` / `in-progress` / `done` / `needs revision`

## Phase 2

- Source: `reference/CS486_Project_Phase02.pdf`
- Detailed ownership and execution plan: `TODO.md`
- Thien Loc's steps 13–14 and localhost backend plan: `md/thienloc.md`
- Required outputs: `08`–`16`, including directories for steps 13 and 14
- Status: steps 13–14 and localhost backend have working scaffolds under an explicit user override; final adapters remain blocked by steps 09–12
- User owns steps 13–14, the procedural data generator, the basic Node.js/Express backend, and the agent/Markdown audit
- Codex and Antigravity are the primary Phase 2 agents
- Data requirement: at least three academic years and at least 100,000 booking records; increase toward 500,000 only if needed for measurable indexing results
- Current branch at audit: `data`, matching local `dev`; local `agent` is behind
- Generator/backend status: Part 14 generates and bounded-memory-validates 500,000 bookings; trigger-enabled batched production-load SQL is parser-verified, but a successful final 500,000-row server load remains pending. Part 13 isolated concurrency tests pass against local SQL Server; production procedure mapping remains provisional pending approved outputs 09–12.
- Step 08: maintenance impact, `requires_approval`, schema refinements, FDs, and 3NF analysis exist; concurrency/reporting coverage and acknowledgement cardinality still need revision
- Step 09: updated conceptual ERD exists; updated logical ERD is missing

## Assets

| File | Description | Status |
|---|---|---|
| `assets/conceptual.drawio` | Conceptual ERD source (drawio format) | done |
| `assets/conceptual.svg` | Conceptual ERD export (referenced by step 2) | done |
| `assets/refined_conceptual.svg` | Refined conceptual ERD after design validation | done |
| `assets/logical.mmd` | Logical ERD source (Mermaid) | done |
| `assets/logical.svg` | Logical ERD export (referenced by step 3) | done |
| `assets/refined_logical.mmd` | Refined logical ERD source (Mermaid) | done |
| `assets/refined_logical.svg` | Refined logical ERD export | done |

## Agent tools
- **Primary for Phase 2**: Codex and Antigravity
- **Removed**: Claude Code (CLAUDE.md and .claude/ deleted on 2026-07-01)
- All tools converge on AGENTS.md as single source of truth
- Canonical skill: `.codex/skills/db-design-pipeline/SKILL.md`

## Reports

| Report | File | Status |
|---|---|---|
| Group Report (Agent improvements + MD setup) | `report/G06_Report.tex` | done |
| Phase 2 Group Report | `G06_Report_P2.pdf` | not started |
| Phase 2 Code Review | `outputs/phase2-code-review-evaluation-G06.md` | done - internal score 40/100; not submission-ready |

## Locked decisions
- Group number: G06
- DBMS: Microsoft SQL Server
- Space IDs: 3-5 letter codes (e.g. HT1, I12b) per step 1 analysis
- User IDs: 8-digit numeric, generated on creation
- Facility IDs: 6-char format (3 alpha + 3 numeric, e.g. chr055)
- Full name: composite of surname + given_name
- Space location: composite of building + floor + room_number
- Policy: modeled as `SpacePolicy` entity (policy_id, booking_window_days, min/max_duration_minutes, check_in_grace_minutes)
- Space–Facility cardinality: (1,N) and (1,1) — both participations mandatory
- SpaceCondition: enum-like reference entity; used in ReservationCheckin (initial + final condition)
- UserStatus: enum-like reference entity replacing simple status attribute on User
- Claude removal: all CLAUDE.md references and .claude/ directory removed; team standardized on Codex + Antigravity
- Phase 2 task ownership and order are recorded in `TODO.md`
- Updated conceptual ERD: `assets/svg/refined_refined_conceptual.svg`
- Step 14 implementation choice: Python lazy generators/iterators write synthetic CSV data; Node.js/Express remains the localhost backend
- Step 14 credential rule: every local developer creates a private machine-local SQL password; a shared server uses separate named logins, never a shared `sa` credential
- Step 14 Fedora guard: Linux requires explicit `DB_USERNAME`/`DB_PASSWORD`, the final adapter targets `School`, dry runs redact passwords, and Windows integrated authentication is never an implicit Linux fallback
- Step 14 operator guide: `outputs/14-data-generator-G06/README.md` and its `.env.example` are authoritative; the Python CLI reads the local `.env` directly while exported Bash variables take priority; `md/thienloc.md` is the wider project checklist
- Out-of-order override: user explicitly authorized scaffold-only implementation before steps 09–12 are finalized; scaffolds must not be marked done

## Open questions
- *(resolved)* Policy values → now modeled as SpacePolicy entity with structured attributes
- *(resolved)* Non-academic users and departments → confirmed not all users belong to a department (facility staff, admins exempt)
- What are the exact states a user account may be in? (UserStatus reference entity — domain values not yet confirmed)
- Which space types support instant approval in Phase 2?
- How are academic semesters defined for Phase 2 reporting and generated data?
- Is maintenance impact-change history required, or is current impact plus escalation-time evidence sufficient?
- Does one `BookingRequest.advisory_acknowledged` Boolean satisfy the requirement to record acknowledgement of all simultaneously active advisories, or is a booking–maintenance junction required?

## Assumptions recorded
- Space–Facility participation is mandatory on both sides (confirmed in step 4)
- SpacePolicy is a separate entity, not a text paragraph (confirmed in step 4)
- ReservationCheckin is an associative entity participating in space condition relationships (confirmed in step 4)

## Entity/requirement traceability snapshot
- User entity ← req: user ID, full name, email, phone, role, department, account status (→ UserStatus ref entity)
- Space entity ← req: space code, name, type, building/floor/room, capacity, status, policy (→ SpacePolicy entity)
- Facility entity ← req: facility ID, facility name
- Space_Facility junction ← req: list of facilities per space
- Booking ← req: booking with space, times, purpose, participants, status (step 3: renamed from BookingRequest)
- ReservationCheckin ← req: check-in record; associative entity with initial/final SpaceCondition
- BookingApproval ← req: approval/rejection by staff
- Maintaining ← req: maintenance records per space (step 3: renamed from Maintains)
- Lookup tables: UserRole, UserStatus, SpaceType, SpaceCondition, SpacePolicy, RoomStatus, RequestStatus, MaintenanceStatus

## Known issues / things to fix next session
- Step 5 DDL: double check final FK trigger logic against any potential SQL Server strict check constraints
- Setup: LaTeX intermediate files live in `report/.aux/`; users should open the compiled root report PDF, not an intermediate file.
- `MEMORY.md` and `TODO.md` were originally written for `agent`; current work is on `data`/`dev`, while local `agent` is behind.

## Completed tasks log
- 2026-07-01: Removed all Claude Code traces (CLAUDE.md, .claude/, references in all .md/.sh/.tex files)
- 2026-07-01: Merged the report into one source containing Part I (improvements) and Part II (Markdown setup); the retained canonical source is `report/G06_Report.tex`.
- 2026-07-01: Updated MEMORY.md to reflect true pipeline progress (steps 2–6 done; assets complete; step 7 remaining)
- 2026-07-01: Added `md/usage.md` documentation, resolved trigger schema issue, implemented step 7 queries, and compiled final PDF.
- 2026-07-01: Updated MEMORY.md to reflect true pipeline progress (steps 2–7 done; assets complete)
- 2026-07-02: Added five more step 7 queries for availability, facilities, approved bookings, maintenance status, and purpose statistics.
- 2026-07-31: Read and verified the Phase 2 brief; created `TODO.md` with deliverables, ownership, dependencies, generator/backend work, and final validation.
- 2026-08-02: Audited Phase 2 progress; recorded step 08 as needs revision, step 09 as in progress, empty later placeholders, and the absence of generator/backend implementations.
- 2026-08-02: Added `md/thienloc.md` with the implementation plan and acceptance criteria for steps 13–14 and the localhost Express backend.
- 2026-08-02: Updated `md/thienloc.md` to use a Python iterator-based step 14 generator and recorded the decision in project memory.
- 2026-08-02: Merged `origin/main` into `data`, preserved local planning changes, and implemented verified scaffolds for steps 13–14 and the localhost Express backend under explicit override.

- 2026-08-08: Continued thienloc implementation: enforced dependency-ordered generator staging input checks and added JSON-object validation to POST generator-backed API routes; verified 100-booking generation and validation with zero errors.
- 2026-08-08: Updated canonical Codex db-design-pipeline SKILL.md with Phase 2 placeholders, detailed user-owned parts 13–14, and a post-project review checklist; AGENTS.md left unchanged.
- 2026-08-08: Corrected Phase 2 placeholder ownership in SKILL.md to refer to other team members rather than Codex or Antigravity.

- 2026-08-09: Completed reproducible part 13 isolated concurrency runner with unsafe/protected, approval-mode, non-overlap, boundary, maintenance acknowledgement, out-of-service, and escalation scenarios; final procedure mapping remains provisional pending approved outputs 09–12.
- 2026-08-09: Completed part 14 generator CLI with streaming CSV generation, validation, SQL Server staging dry-run/load workflow, safe cleanup, and same-seed reproducibility verification.
- 2026-08-09: Implemented cross-platform localhost Express backend under `backend/`; `npm run check` and mock-mode HTTP smoke test pass on Windows; SQL Server mode uses environment variables and output-12 procedure adapters.
- 2026-08-09: SQL Server concurrency execution was not completed in this environment because no reachable local SQL Server named instance was discoverable; run `npm test` from part 13 after configuring DB_SERVER/DB_DATABASE.
- 2026-08-09: Executed part 13 successfully on Windows with Node v24.11.0 and SQL Server `\.\MSSQL2025`/`tempdb`; all 9 scenarios passed and isolated objects were cleaned up.

- 2026-08-09: Added Docker Compose SQL Server integration workflow, readiness/cleanup scripts, backend API tests, and generator reproducibility tests; code-level checks pass, Docker daemon integration remains pending.

- 2026-08-09: Generated and validated output 14 dataset with 100,000 bookings, 10,000 users, 100 spaces, 2,500 maintenance rows, seed 48606, 23.6 MB CSV output, and zero validation errors.

- 2026-08-09: Moved the Thien Loc Phase 2 plan to `md/thienloc.md`; updated dependent README/TODO/MEMORY references and made parts 13–14 documentation path-portable.
- 2026-08-09: Finalized part 14 production adapter and Fedora credential guide; generated 500,000 bookings with seed 48606 (10,000 users, 100 spaces, 2,500 maintenance rows, 109,149,100 CSV bytes) and bounded-memory validation passed with zero errors (28,296 KB peak RSS); SQL Server execution is still pending because this laptop has no SQL Server tools.
- 2026-08-09: Resolved the Fedora loader failure: missing Linux credentials and stale database names now fail fast, backend defaults use `School`, SQL auth/certificate flags are tested, password output is redacted, and all five generator/loader tests pass.
- 2026-08-09: Removed the retired third-party agent integration, its duplicated skill directory, sync script, and all project references; Codex is canonical and Antigravity follows the AGENTS.md pointer.
- 2026-08-09: Retained `report/G06_Report.tex` as the sole canonical LaTeX report and removed the older Phase-1-named duplicate; reconciled stale `md/thienloc.md` checkboxes and annotated every remaining item with its SQL Server, output-12, repetition, or part-15 dependency.
- 2026-08-09: Made the part-14 README self-contained for teammates, including Fedora credentials, optional SQL Server container startup, schema setup, 500,000-row generation/load/verification, troubleshooting, evidence, and cleanup; corrected Docker EULA configuration to `ACCEPT_EULA=Y`.
- 2026-08-09: Added dependency-free direct `.env` loading to the part-14 CLI; `.env` is resolved from the generator folder and never overrides credentials already exported by the parent shell.
- 2026-08-09: Scoped part-14 `.env` parsing to the database `load` subcommand so malformed database configuration cannot block `generate`, `validate`, or `clean`.

- 2026-08-10: Section 6 server-load attempt reached .\\MSSQL2025/School, bulk-loaded staging successfully, then load-final.sql rolled back at SpacePolicy because generated codes P0001–P0004 violate CHK_SpacePolicy_space_policy_id_format (letters-only); terminal log: outputs/14-data-generator-G06/generated/terminal-load-2026-08-10.log.

- 2026-08-10: Updated part-14 generator/staging/load adapter to use workbook-consistent space_policy_id values (DYWGI/HKBSL/NCYTN/QFJJO-style uppercase IDs) and explicit lowercase review IDs in SQL 10 xxxx-xxxx format; small 100-row generation and validation passed with zero errors.

- 2026-08-10: Removed the separate advisory_acknowledgements CSV/staging/load/validation artifact from part 14; preserved only BookingRequest.advisory_acknowledged, regenerated 100,000 rows, and validation passed with zero errors.

- 2026-08-10: Committed Part 14 rerun cleanup fix after 100-row test confirmed CSV/staging success and no policy truncation; temporary generated-test-100 data was deleted, while a clean production rerun remains pending stale synthetic-row cleanup.
- 2026-08-10: Refined Part 13 into executable instant/staff race, boundary, maintenance acknowledgement/blocking, and escalation scenarios; all 10 isolated SQL Server tests passed and cleanup removed the lab objects.
- 2026-08-10: Refined Part 14 staging/final validation and cleanup SQL; load-final now requires enabled Review triggers, batches approved reviews per space with progress output, and all changed SQL scripts pass SQL Server PARSEONLY. The 500,000-row CSV validation passed with zero errors; the 100-row production-load test is deferred and no final load claim is recorded.
- 2026-08-10: Completed the Phase 2 code-review evaluation at `outputs/phase2-code-review-evaluation-G06.md`; internal score 40/100, with output 12 concurrency, output 16 final-schema queries, output 15 measured tuning, production evidence, and the final report as submission blockers.
