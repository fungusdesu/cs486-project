# MEMORY.md — Project State (read this first, every session)

Last updated: 2026-06-19 by Antigravity (initial setup)

## Group info
- Group number: G06
- DBMS: Microsoft SQL Server (default)

## Pipeline status

| Step | File | Status | Notes |
|---|---|---|---|
| 1. Business req analysis | `01-business-req-analysis-G06.md` | done | Hand-written by team; includes schema design and inquiries |
| 2. Conceptual ERD | `02-erd-design-G06.md` | not started | 0-byte placeholder; ERD exists separately as `ERD.mmd` |
| 3. Logical design | `03-logical-design-G06.md` | not started | 0-byte placeholder |
| 4. Design validation | `04-design-validation-G06.md` | not started | 0-byte placeholder |
| 5. DDL | `05-db-definition-G06.sql` | in-progress | Has CREATE TABLE + lookup INSERTs; uses SET NOEXEC ON (not runnable yet); needs review |
| 6. Sample data | `06-sample-data-G06.sql` | not started | 0-byte placeholder |
| 7. Query design | `07-query-design-G06.sql` | not started | 0-byte placeholder |

Status values: `not started` / `in-progress` / `done` / `needs revision`

## Locked decisions
- Group number: G06
- DBMS: Microsoft SQL Server
- Space IDs: 3-5 letter codes (e.g. HT1, I12b) per step 1 analysis
- User IDs: 8-digit numeric, generated on creation
- Facility IDs: 6-char format (3 alpha + 3 numeric, e.g. chr055)
- Full name: composite of surname + given_name
- Space location: composite of building + floor + room_number

## Open questions
- What are the exact values the policies may take on for a space?
- Do users with non-academic roles belong to a specific department? If no, is it safe to assume a user need not belong to one department?
- What are the exact states a user account may be in?

## Assumptions recorded
- (none confirmed by user yet — the step 1 doc records several implicit assumptions)

## Entity/requirement traceability snapshot
- User entity ← req: user ID, full name, email, phone, role, department, account status
- Space entity ← req: space code, name, type, building/floor/room, capacity, status, policy
- Facility entity ← req: facility ID, facility name
- Space_Facility junction ← req: list of facilities per space
- BookingRequest ← req: booking with space, times, purpose, participants, status
- BookingApproval ← req: approval/rejection by staff
- Maintains (maintenance) ← req: maintenance records per space
- Lookup tables: UserRole, RoomStatus, RequestStatus, MaintenanceStatus

## Known issues / things to fix next session
- Step 5 DDL has `SET NOEXEC ON` — tables won't actually create until removed
- DDL uses double-quote string literals (invalid in MSSQL — should be single quotes)
- DDL references `Booking(booking_id)` in BookingApproval FK but table is actually `BookingRequest`
- DDL CREATE TABLE order has forward-reference issues (User references UserRole before it's created)
- Steps 2-4 need to be generated before step 5 can be properly validated per pipeline rules
- ERD exists as `ERD.mmd` but step 2 output file is empty — need to consolidate
