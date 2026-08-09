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

- [ ] Confirm the final Phase 2 table and stored-procedure interfaces from outputs 09–12.
- [x] Windows verification completed: all 9 isolated concurrency scenarios pass on SQL Server `.\MSSQL2025`.
- [ ] Fedora/Linux verification: run the same commands from the Fedora handoff below.
- [ ] Docker verification: run SQL Server in Docker, execute parts 13–14, and retain result files.
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

### 2. Start SQL Server in Docker

Use the SQL Server Developer container documented by the team. Do not commit the password:

```bash
export MSSQL_SA_PASSWORD='Use-a-local-password-only-123!'
docker run --name cs486-sqlserver --accept-eula -e 'MSSQL_PID=Developer' -e "MSSQL_SA_PASSWORD=$MSSQL_SA_PASSWORD" -p 1433:1433 -d mcr.microsoft.com/mssql/server:2022-latest
```

Wait until SQL Server accepts connections, then configure:

```bash
export DB_SERVER='localhost,1433'
export DB_DATABASE='tempdb'
export DB_USERNAME='sa'
export DB_PASSWORD="$MSSQL_SA_PASSWORD"
export SQLCMD_TRUST_CERTIFICATE='true'
```

Install Microsoft SQL Server command-line tools for Fedora (`sqlcmd` and `bcp`) using the Microsoft package repository, then confirm `sqlcmd --version` and `bcp -v` work.

### 3. Run the concurrency tests

```bash
cd outputs/13-concurrency-tests-G06
npm install
npm test
cat results/latest.md
```

Expected result: the JSON report ends with `"passed": true`, and all nine scenarios show `yes`. The runner opens two independent `sqlcmd` processes itself; a second terminal is not needed for this test.

### 4. Run the generator and validation

```bash
cd ../14-data-generator-G06
python3 -m src.cli generate --users 1000 --spaces 30 --bookings 100000 --maintenance 200 --seed 48606
python3 -m src.cli validate
```

Expected result: `"valid": true`, zero validation errors, three or more represented academic years, and non-zero maintenance, approval, rejection, pending, cancellation, no-show, and acknowledgement counts.

For the larger benchmark, change only `--bookings` to `500000`. Keep generated files out of Git.

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

Do not mark parts 13–14 fully final until outputs 09–12 are approved and the Docker/Fedora evidence is retained.
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
- [ ] Load parent tables before child tables to preserve foreign keys.
- [ ] Use staging tables for raw imports, validation, and set-based insertion into final tables.
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
- [ ] Include already-approved bookings affected by maintenance escalation.
- [x] Reuse 10,000 synthetic users across the verified 500,000-booking run.

### Loading strategy

- [x] Generate one CSV per target or staging table.
- [x] Provide staging tables without secondary indexes.
- [x] Bulk-load all generated CSV files into SQL Server staging tables and verify their row counts.
- [ ] Validate types, identifiers, dates, required values, and parent keys.
- [ ] Transform and insert into final tables in dependency order.
- [ ] Commit bounded units of work so a failure does not require restarting the entire load.
- [x] Record scaffold generation, validation, staging-load time, generated size, seed, configuration, and environment.
- [ ] Record final database load time and database size after output 10 mapping is available.

### Validation acceptance criteria

- [x] Requested booking count equals generated booking count.
- [x] At least three academic years are represented.
- [x] Duplicate booking identifiers: zero.
- [x] Missing generated foreign-key parents: zero.
- [x] Invalid generated time ranges: zero.
- [x] Duplicate approved slots for the same space: zero.
- [x] Maintenance, cancellations, no-shows, and acknowledgements all have non-zero counts.
- [ ] The same seed reproduces identical identifiers and aggregate counts.
- [ ] A clean database can be populated using only committed scripts and documented commands.

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
- [ ] Instant approval versus instant approval for the same overlapping slot.
- [ ] Instant approval versus staff approval.
- [ ] Staff approval versus staff approval.
- [ ] Non-overlapping requests that should both succeed.
- [ ] Boundary-adjacent requests that should both succeed.
- [ ] Advisory maintenance that permits booking after acknowledgement.
- [ ] Out-of-service maintenance that blocks an overlapping approval.
- [ ] Advisory escalation that identifies affected approved bookings.
- [ ] Repeat race-sensitive scenarios enough times to show consistent protection.

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
- [ ] Legitimate non-overlapping bookings are not blocked unnecessarily.
- [x] Scaffold tests run from one documented command on localhost.
- [ ] Evidence is reproducible on a clean migrated database.

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
- [ ] Validate request bodies and query parameters.
- [x] Use centralized error handling and stable JSON error responses.
- [ ] Call the protected step 12 stored procedures for booking and approval.
- [x] Do not use a JavaScript mutex as the database concurrency solution.
- [x] Do not expose the 500,000-row generator through HTTP.
- [ ] Provide example PowerShell or `curl` requests in the README.
- [x] Add and pass local HTTP scaffold tests.

## Performance workflow

- [ ] Load 100,000 bookings first and validate correctness.
- [x] Capture scaffold generation, validation, and staging-loading measurements at 500,000 bookings.
- [x] Scale to 500,000 bookings using only a command-line parameter change.
- [ ] Preserve the same seed and distribution configuration when comparing indexes.
- [ ] Give step 15 the generated dataset metadata and validation output.
- [ ] Do not add tuned indexes before the required baseline measurements are captured.

## Evidence to retain

- [ ] Exact Node.js, npm, and SQL Server versions.
- [ ] Machine CPU, RAM, storage type, and operating system.
- [x] Generator seed and configuration.
- [x] Row counts by generated table and state.
- [x] CSV generation time and staging bulk-load time.
- [ ] Database size after loading.
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
