# Thien Loc — Phase 2 Implementation Plan

Last updated: 2026-08-09

## Scope

I own the following Phase 2 work:

- `outputs/13-concurrency-tests-G06/`
- `outputs/14-data-generator-G06/`
- A basic Node.js/Express backend running on localhost

The step 14 generator will be written in Python. Step 13 and the localhost backend may remain Node.js projects.

The generator target is at least 100,000 booking records across three academic years, with support for scaling to 500,000 booking records. Related rows in reviews, reservations, maintenance, sessions, and acknowledgements mean the final database may contain well over 500,000 total rows.

## Current dependencies and blockers

- Step 08 needs revision.
- Step 09 has a conceptual ERD but no updated logical ERD.
- Step 10 migration is empty.
- Steps 11–12 concurrency design and implementation are empty.
- Step 13 must use the final concurrency operation from step 12.
- Step 14 must target the final schema produced by steps 09–10.

I may scaffold folders, configuration, logging, and command-line interfaces now. I must not finalize table mappings or concurrency assertions until steps 09–12 are approved.

## Architecture

```text
Python data generator
    -> streamed CSV files
    -> SQL Server staging tables
    -> set-based validation and transformation
    -> final Phase 2 tables

Node concurrency runner
    -> two or more independent SQL connections
    -> synchronized conflicting operations
    -> machine-readable and Markdown results

Express backend on localhost:3000
    -> validated HTTP requests
    -> SQL Server stored procedures
    -> JSON responses
```

The data generator and concurrency runner are command-line tools. The generator must not be exposed as a public Express endpoint.

## Phase A — Project scaffolding

- [ ] Confirm the final Phase 2 table and stored-procedure interfaces from outputs 09–12 (blocked: output 09 logical design is still incomplete and final procedure approval is not recorded).
- [x] Windows verification completed: all 9 isolated concurrency scenarios pass on SQL Server `.\MSSQL2025`.
- [ ] Fedora/Linux SQL verification: execute the database commands from the handoff below (blocked: this Fedora laptop has no SQL Server, `sqlcmd`, or `bcp`; Python generation/validation is complete).
- [ ] Docker verification: run SQL Server in Docker, execute parts 13–14, and retain result files (blocked: Docker/SQL Server is unavailable on the current laptop).
- [x] Record the exact Python version used by step 14.
- [x] Record the Node.js and npm versions used by the scaffolds.
- [x] Create `outputs/13-concurrency-tests-G06/`.
- [x] Create `outputs/14-data-generator-G06/`.
- [x] Create `backend/`.
- [x] Add `.env.example` files containing names but no secrets.
- [x] Add generated CSV, result, log, and `.env` files to `.gitignore`.
- [x] Use a shared environment-variable convention for database configuration.
- [x] Keep scaffold commands non-interactive so another group member can reproduce them.


## Fedora/Linux handoff checklist

The authoritative, teammate-facing Fedora generation and SQL Server loading
guide is `outputs/14-data-generator-G06/README.md`. Follow that README for the
actual part-14 run; the checklist below records the wider parts 13–14/backend
handoff and project acceptance status.

A group member using Fedora should complete this section before marking the work final. These commands use bash and do not depend on PowerShell.

### 1. Install and verify tools

```bash
sudo dnf install -y git nodejs npm python3 python3-pip
node --version
npm --version
python3 --version
docker --version
docker compose version
```

Start Docker Desktop or the Fedora Docker service, then verify:

```bash
sudo systemctl enable --now docker
docker ps
```

### 2. Configure local development credentials and start SQL Server

Generate a different local-only password on each developer computer. Never
commit the value, paste it into documentation, or retain it in evidence:

```bash
export MSSQL_SA_PASSWORD="$(openssl rand -base64 24)Aa1!"
docker run --name cs486-sqlserver -e 'ACCEPT_EULA=Y' -e 'MSSQL_PID=Developer' -e "MSSQL_SA_PASSWORD=$MSSQL_SA_PASSWORD" -p 1433:1433 -d mcr.microsoft.com/mssql/server:2022-latest
```

Wait until SQL Server accepts connections, then configure:

```bash
export DB_SERVER='localhost,1433'
export DB_DATABASE='School'
export DB_USERNAME='sa'
export DB_PASSWORD="$MSSQL_SA_PASSWORD"
export SQLCMD_TRUST_CERTIFICATE='true'
```

Install Microsoft SQL Server command-line tools for Fedora (`sqlcmd` and
`bcp`) using Microsoft's package repository, then confirm `sqlcmd --version`
and `bcp -v` work. These environment-variable names are shared project
configuration; their values are never committed. At the end of the session,
run `unset MSSQL_SA_PASSWORD DB_PASSWORD`.

Credential ownership is per computer. Each member creates a different local
`sa` password; the group must not circulate one mock administrator account.
If the team deliberately uses one shared development server, its owner keeps
`sa` private. After the owner creates and migrates `School` with the commands
below, they create one named login per member in a private `sqlcmd` session.
For this disposable course database, use this template:

```sql
USE [master];
GO
CREATE LOGIN [g06_member_name] WITH PASSWORD = '<private-random-password>';
GO
USE [School];
GO
CREATE USER [g06_member_name] FOR LOGIN [g06_member_name];
ALTER ROLE [db_owner] ADD MEMBER [g06_member_name];
GO
```

Replace both placeholders privately and send the password through a secure
channel, never Git or group chat history. `db_owner` is acceptable here only
for the disposable development database because the loader creates staging
objects and transforms data; it is not a production-server pattern. The
10,000 generated rows in `users.csv` are synthetic application data, not SQL
logins, so members do not create those accounts manually.

Create and migrate the database in strict order from the project root:

```bash
sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C -b -i outputs/05-db-definition-G06.sql
sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C -b -d School -i outputs/06-sample-data-G06.sql
sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C -b -d School -i outputs/10-schema-migration-G06.sql
```

### 3. Run the concurrency tests

```bash
cd outputs/13-concurrency-tests-G06
npm install
npm test
cat results/latest.md
```

Expected result: the JSON report ends with `"passed": true`, and all nine scenarios show `yes`. The runner opens two independent `sqlcmd` processes itself; a second terminal is not needed for this test.

### 4. Generate, validate, and load 500,000 booking requests

```bash
cd ../14-data-generator-G06
python3 -m src.cli generate --users 10000 --spaces 100 --bookings 500000 --maintenance 2500 --seed 48606
python3 -m src.cli validate
python3 -m src.cli load --server "$DB_SERVER" --database "$DB_DATABASE" --trust-certificate
python3 -m src.cli load --server "$DB_SERVER" --database "$DB_DATABASE" --trust-certificate --execute
```

The first `load` command is a credentials-redacted dry run. Review its exact
targets before adding `--execute`. The executed workflow recreates staging,
uses `bcp` for all eight CSVs, runs `sql/validate.sql`, transforms the rows in
one set-based transaction with `sql/load-final.sql`, and runs
`sql/validate-final.sql`. Expected result: `"valid": true`, exactly 500,000
staged and production booking requests, zero approved overlaps, three or more
represented academic years, and non-zero maintenance, approval, rejection,
pending, cancellation, no-show, and acknowledgement counts.

Keep `generated/` out of Git. Retain its `metadata.json`, `validation.json`,
and `load-evidence.json` only as local/run evidence. The final SQL validation
also prints the allocated database size. Output 10 stores only the aggregate
`BookingRequest.advisory_acknowledged` flag, so detailed per-maintenance
acknowledgement rows intentionally remain available in staging.

### 5. Test the localhost backend

In one terminal:

```bash
cd backend
npm install
cp .env.example .env
npm test
npm start
```

In a second terminal:

```bash
curl http://localhost:3000/api/health
```

Expected response contains `"ok":true`. Mock mode tests the HTTP layer without database credentials. SQL Server mode requires adapting the `.env` values and approved output-12 procedures.

### 6. Record evidence and clean up

Record Fedora, Docker, SQL Server, Node.js, npm, Python, and `sqlcmd` versions in the part 13/14 evidence files. Then remove local test resources:

```bash
cd ../13-concurrency-tests-G06
npm test
cd ../../
docker rm -f cs486-sqlserver
```

Part 14's generator, bounded-memory validation, bulk staging, production-load
query, and final validation are implemented. Do not claim that the server
load itself ran until `load-evidence.json` and successful final SQL output are
retained from a SQL Server host. Parts 13 and the backend still depend on the
final output-12 procedure adapter.
## Step 14 — Data generator

### Planned structure

```text
outputs/14-data-generator-G06/
├── requirements.txt or pyproject.toml
├── README.md
├── config.example.json
├── src/
│   ├── cli.py
│   ├── generate.py
│   ├── load.py
│   ├── validate.py
│   ├── random_data.py
│   ├── ids.py
│   ├── dates.py
│   └── generators/
├── sql/
│   ├── create-staging.sql
│   ├── load-final.sql
│   ├── validate.sql
│   └── clean-generated-data.sql
└── generated/                  # ignored by Git
```

### Command interface

```powershell
python -m src.cli generate --bookings 500000 --seed 48606
python -m src.cli load
python -m src.cli validate
python -m src.cli clean
```

### Python combination idea

The core idea is good: combine reusable name components procedurally so Python can produce many synthetic identities without consuming AI tokens. The implementation should use lazy iteration rather than a function recursively calling itself once per row.

For example, 100 surnames × 100 middle names × 100 given names provides 1,000,000 possible combinations. `itertools.product` yields one combination at a time, so memory use remains small even when generation stops at 500,000 rows.

```python
import csv
from itertools import islice, product

surnames = ["Nguyen", "Tran", "Le"]       # expand the source list
middle_names = ["Van", "Thi", "Minh"]
given_names = ["An", "Binh", "Chau"]


def generate_users(limit):
    combinations = product(surnames, middle_names, given_names)

    for number, (surname, middle, given) in enumerate(
        islice(combinations, limit),
        start=1,
    ):
        yield {
            "user_id": f"{number:08d}",
            "surname": surname,
            "given_name": f"{middle} {given}",
            "email": f"user{number}@student.local",
        }


with open("users.csv", "w", newline="", encoding="utf-8") as file:
    writer = csv.DictWriter(
        file,
        fieldnames=["user_id", "surname", "given_name", "email"],
    )
    writer.writeheader()
    writer.writerows(generate_users(500_000))
```

This demonstrates the technique, not the intended user count. Phase 2 requires up to 500,000 booking records, not 500,000 people. The final generator should create a smaller realistic user population and reuse those users across the booking records.

### Generation strategy

- [x] Use a seeded pseudo-random generator.
- [x] Use Python generators, iterators, and `itertools.product` for lazy combination generation.
- [x] Stream rows directly to CSV instead of storing 500,000 objects in memory.
- [x] Avoid deep recursive function calls per row.
- [x] Avoid one SQL `INSERT` per generated row.
- [x] Provide SQL Server `bcp` staging-load commands.
- [x] Load parent tables before child tables to preserve foreign keys.
- [x] Use staging tables for raw imports, validation, and set-based insertion into final tables.
- [x] Make row counts and synthetic distributions configurable rather than business rules.
- [x] Generate synthetic identities only.

### Booking generation

- [x] Cover three academic years using a configurable provisional term calendar.
- [x] Accept 100,000 or 500,000 bookings from a command-line option.
- [x] Generate approved bookings from unique `space × date × time-slot` combinations.
- [x] Generate deliberate overlaps for non-approved requests.
- [x] Include provisional instant and staff approval indicators.
- [x] Include cancellations and no-shows.
- [x] Include advisory and out-of-service maintenance.
- [x] Include per-maintenance advisory acknowledgement rows in the staging format.
- [x] Include already-approved bookings affected by advisory maintenance that can be escalated.
- [x] Reuse 10,000 synthetic users across the verified 500,000-booking run.

### Loading strategy

- [x] Generate one CSV per target or staging table.
- [x] Provide staging tables without secondary indexes.
- [x] Bulk-load all generated CSV files into SQL Server staging tables and verify their row counts.
- [x] Validate types, identifiers, dates, required values, and parent keys in Python and final SQL.
- [x] Transform and insert into final tables in dependency order with `sql/load-final.sql`.
- [x] Keep bulk staging restartable and wrap the production transformation in one rollback-safe transaction.
- [x] Record scaffold generation, validation, staging-load time, generated size, seed, configuration, and environment.
- [ ] Record final database load time and database size (blocked: requires executing the implemented output-10 adapter on SQL Server).

### Validation acceptance criteria

- [x] Requested booking count equals generated booking count.
- [x] At least three academic years are represented.
- [x] Duplicate booking identifiers: zero.
- [x] Missing generated foreign-key parents: zero.
- [x] Invalid generated time ranges: zero.
- [x] Duplicate approved slots for the same space: zero.
- [x] Maintenance, cancellations, no-shows, and acknowledgements all have non-zero counts.
- [x] The same seed reproduces identical identifiers and aggregate counts.
- [ ] A clean database can be populated using only committed scripts and documented commands (unverified until a SQL Server host runs the documented workflow).

## Step 13 — Concurrency tests

### Planned structure

```text
outputs/13-concurrency-tests-G06/
├── package.json
├── README.md
├── src/
│   ├── run-tests.mjs
│   ├── barrier.mjs
│   ├── database.mjs
│   └── scenarios/
├── sql/
│   ├── setup.sql
│   ├── unsafe-operation.sql
│   ├── safe-operation.sql
│   └── cleanup.sql
└── results/                    # ignored except curated evidence
```

### Required scenarios

- [x] Reproduce the unsafe check-then-approve race before protection in an isolated table.
- [x] Instant approval versus instant approval for the same overlapping slot.
- [x] Instant approval versus staff approval.
- [x] Staff approval versus staff approval.
- [x] Non-overlapping requests that should both succeed.
- [x] Boundary-adjacent requests that should both succeed.
- [x] Advisory maintenance that permits booking after acknowledgement.
- [x] Out-of-service maintenance that blocks an overlapping approval.
- [x] Advisory escalation that identifies affected approved bookings.
- [ ] Repeat race-sensitive scenarios enough times to show consistent protection (current retained evidence contains one successful pass of each scenario).

### Test mechanism

- [x] Open two independent SQL Server sessions through concurrent `sqlcmd` processes.
- [x] Use synchronized SQL delays so both unsafe operations pass the availability check.
- [x] Run unsafe and protected versions against controlled fixture data.
- [x] Assert final database state, not only SQL return messages.
- [x] Clean up isolated test objects after the run.
- [x] Save scaffold result metadata including outcomes, elapsed time, and approved count.
- [x] Export a concise Markdown scaffold result table.

### Step 13 acceptance criteria

- [x] Unsafe isolated script demonstrates a concurrency conflict.
- [x] Protected isolated script admits only one overlapping approved booking.
- [x] Legitimate non-overlapping and boundary-adjacent bookings are not blocked unnecessarily.
- [x] Scaffold tests run from one documented command on localhost.
- [ ] Evidence is reproducible on a clean migrated database (blocked: retained evidence targets the isolated `tempdb` fixture until the final output-12 procedure adapter is approved).

## Local Node.js/Express backend

### Planned structure

```text
backend/
├── package.json
├── README.md
├── .env.example
└── src/
    ├── server.mjs
    ├── database.mjs
    ├── routes/
    ├── controllers/
    ├── services/
    └── middleware/
```

### Local runtime

- Express URL: `http://localhost:3000`
- SQL Server: local SQL Server instance or local container
- Credentials: environment variables only
- Hosting: localhost is sufficient; no public deployment is required

### API checklist

- [x] `GET /api/health`
- [x] `POST /api/bookings`
- [x] `POST /api/bookings/:id/approve`
- [x] `POST /api/bookings/:id/reject`
- [x] `GET /api/spaces/available`
- [x] `POST /api/maintenance`
- [x] `PATCH /api/maintenance/:id/impact`
- [x] `GET /api/maintenance/:id/affected-bookings`
- [x] Approved-hours report endpoint scaffold
- [x] Bookings-by-weekday-and-hour report endpoint scaffold
- [x] Room-finder endpoint scaffold
- [x] Maintenance-escalation endpoint scaffold

### Backend rules

- [x] Use a SQL Server connection pool.
- [x] Validate request bodies and query parameters.
- [x] Use centralized error handling and stable JSON error responses.
- [ ] Call the protected step 12 stored procedures for booking and approval (blocked: the final output-12 procedure names/signatures have not been approved for the adapter).
- [x] Do not use a JavaScript mutex as the database concurrency solution.
- [x] Do not expose the 500,000-row generator through HTTP.
- [x] Provide example PowerShell and `curl` requests in the README.
- [x] Add and pass local HTTP scaffold tests.

## Performance workflow

- [x] Generate and validate 100,000 bookings before the 500,000-row run.
- [x] Capture scaffold generation, validation, and staging-loading measurements at 500,000 bookings.
- [x] Scale to 500,000 bookings using only a command-line parameter change.
- [ ] Preserve seed 48606 and the same distribution configuration when comparing indexes (pending part 15 execution).
- [ ] Give step 15 the generated dataset metadata and validation output (pending part 15 owner handoff).
- [ ] Do not add tuned indexes before the required baseline measurements are captured (pending part 15 baseline run).

## Evidence to retain

- [ ] Exact Node.js, npm, and SQL Server versions for the final host (current evidence has Node.js/npm but not a final SQL Server/Fedora execution environment).
- [ ] Machine CPU, RAM, storage type, and operating system for the final benchmark host.
- [x] Generator seed and configuration.
- [x] Row counts by generated table and state.
- [x] CSV generation time and staging bulk-load time.
- [ ] Database size after loading (the final validation query is implemented; execution requires SQL Server).
- [x] Concurrency-test scaffold result table.
- [x] Commands needed to reproduce scaffold results.
- [x] Generated 100,000–500,000-row files remain ignored.

## Recommended work order

1. Wait for outputs 09–10 to lock the Phase 2 schema.
2. Wait for outputs 11–12 to lock the protected concurrency interface.
3. Scaffold the Python generator, Node concurrency runner, Node/Express backend, and their shared configuration conventions.
4. Implement and validate the generator at 1,000 bookings.
5. Scale and validate at 100,000 bookings.
6. Scale to 500,000 bookings and capture performance metadata.
7. Implement the concurrency runner and collect unsafe/safe evidence.
8. Implement the localhost Express routes over the protected database procedures.
9. Run a clean end-to-end reproduction and provide evidence to outputs 15 and the Phase 2 report.

## Definition of done

- Step 13 contains reproducible conflict and prevention scripts with test evidence.
- Step 14 uses Python to generate and load 100,000 or 500,000 valid booking records without AI-generated rows.
- The generator consumes no AI tokens during normal use.
- The localhost Express backend exercises the same database operations used by the tests.
- Another group member can reproduce the database, tests, and API using only committed code and README instructions.
