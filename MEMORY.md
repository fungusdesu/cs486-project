# MEMORY.md — Project State (read this first, every session)

Last updated: 2026-08-05 by Codex (Phase 2 repository audit)

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
- Thien Loc's steps 13–14 and localhost backend plan: `thienloc.md`
- Required outputs: `08`–`16`, including directories for steps 13 and 14
- Status: steps 13–14 and localhost backend have working scaffolds under an explicit user override; final adapters remain blocked by steps 09–12
- User owns steps 13–14, the procedural data generator, the basic Node.js/Express backend, and the agent/Markdown audit
- Codex and Antigravity are the primary Phase 2 agents
- Data requirement: at least three academic years and at least 100,000 booking records; increase toward 500,000 only if needed for measurable indexing results
- Current branch at audit: `data`, matching local `dev`; local `agent` is behind
- Generator/backend status: Python generator validated and bulk-staged 500,000 bookings; isolated concurrency runner passed unsafe/safe tests; Express adapter passed HTTP safety tests
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
- **Also configured**: OpenClaw
- **Removed**: Claude Code (CLAUDE.md and .claude/ deleted on 2026-07-01)
- All tools converge on AGENTS.md as single source of truth
- Canonical skill: `.codex/skills/db-design-pipeline/SKILL.md`
- Synced copy: `.openclaw/skills/db-design-pipeline/SKILL.md`

## Reports

| Report | File | Status |
|---|---|---|
| Group Report (Agent improvements + MD setup) | `report/Report_Phase1_Group06.tex` | done |
| Phase 2 Group Report | `G06_Report_P2.pdf` | not started |

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
- Claude removal: all CLAUDE.md references and .claude/ directory removed; team standardized on Antigravity + Codex CLI
- Phase 2 task ownership and order are recorded in `TODO.md`
- Updated conceptual ERD: `assets/svg/refined_refined_conceptual.svg`
- Step 14 implementation choice: Python lazy generators/iterators write synthetic CSV data; Node.js/Express remains the localhost backend
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
- Setup: Table of Contents does not appear when opening `report/.aux/Report_Phase1_Group06.pdf` because latexmk compiles and moves it to `report/Report_Phase1_Group06.pdf`. Users should open the root PDF, not the one in `.aux`.
- `MEMORY.md` and `TODO.md` were originally written for `agent`; current work is on `data`/`dev`, while local `agent` is behind.

## Completed tasks log
- 2026-07-01: Removed all Claude Code traces (CLAUDE.md, .claude/, references in all .md/.sh/.tex files)
- 2026-07-01: Merged reports into single `report/Report_Phase1_Group06.tex` (Part I: improvements + Part II: MD setup)
- 2026-07-01: Updated MEMORY.md to reflect true pipeline progress (steps 2–6 done; assets complete; step 7 remaining)
- 2026-07-01: Added `md/usage.md` documentation, resolved trigger schema issue, implemented step 7 queries, and compiled final PDF.
- 2026-07-01: Updated MEMORY.md to reflect true pipeline progress (steps 2–7 done; assets complete)
- 2026-07-02: Added five more step 7 queries for availability, facilities, approved bookings, maintenance status, and purpose statistics.
- 2026-07-31: Read and verified the Phase 2 brief; created `TODO.md` with deliverables, ownership, dependencies, generator/backend work, and final validation.
- 2026-08-02: Audited Phase 2 progress; recorded step 08 as needs revision, step 09 as in progress, empty later placeholders, and the absence of generator/backend implementations.
- 2026-08-02: Added `thienloc.md` with the implementation plan and acceptance criteria for steps 13–14 and the localhost Express backend.
- 2026-08-02: Updated `thienloc.md` to use a Python iterator-based step 14 generator and recorded the decision in project memory.
- 2026-08-02: Merged `origin/main` into `data`, preserved local planning changes, and implemented verified scaffolds for steps 13–14 and the localhost Express backend under explicit override.
