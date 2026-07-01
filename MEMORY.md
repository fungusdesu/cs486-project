# MEMORY.md — Project State (read this first, every session)

Last updated: 2026-07-01 by Antigravity (query design completion)

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
| 7. Query design | `07-query-design-G06.sql` | done | 6 business queries covering history, maintenance, utilization, and availability |

Status values: `not started` / `in-progress` / `done` / `needs revision`

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
- **Active**: Antigravity, OpenCode, Codex CLI, OpenClaw
- **Removed**: Claude Code (CLAUDE.md and .claude/ deleted on 2026-07-01)
- All tools converge on AGENTS.md as single source of truth
- Canonical skill: `.opencode/skills/db-design-pipeline/SKILL.md`
- Synced copy: `.openclaw/skills/db-design-pipeline/SKILL.md`

## Reports

| Report | File | Status |
|---|---|---|
| Group Report (Agent improvements + MD setup) | `report/Report_Phase1_Group06.tex` | done |

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

## Open questions
- *(resolved)* Policy values → now modeled as SpacePolicy entity with structured attributes
- *(resolved)* Non-academic users and departments → confirmed not all users belong to a department (facility staff, admins exempt)
- What are the exact states a user account may be in? (UserStatus reference entity — domain values not yet confirmed)

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

## Completed tasks log
- 2026-07-01: Removed all Claude Code traces (CLAUDE.md, .claude/, references in all .md/.sh/.tex files)
- 2026-07-01: Merged reports into single `report/Report_Phase1_Group06.tex` (Part I: improvements + Part II: MD setup)
- 2026-07-01: Updated MEMORY.md to reflect true pipeline progress (steps 2–6 done; assets complete; step 7 remaining)
- 2026-07-01: Added `md/usage.md` documentation, resolved trigger schema issue, implemented step 7 queries, and compiled final PDF.
- 2026-07-01: Updated MEMORY.md to reflect true pipeline progress (steps 2–7 done; assets complete)
