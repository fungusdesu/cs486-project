# G06 Part 14 — Generate and load synthetic data

This folder is self-contained. A group member can generate, validate, and load
the Phase 2 dataset by following this file without reading `md/thienloc.md`.

## What this produces

The required run uses seed `48606` and produces:

- 500,000 booking requests across at least three academic years;
- 10,000 synthetic users, 100 spaces, and 2,500 maintenance rows;
- reviews, reservations, cancellations, no-shows, instant approvals, and
  detailed advisory acknowledgements;
- streaming CSV files under ignored directory `generated/`.

## 1. Requirements

- Python 3.10 or later
- Microsoft SQL Server reachable over TCP
- Microsoft `sqlcmd` and `bcp` on `PATH`
- Docker is optional; it is needed only when starting SQL Server in a container

Check the tools:

```bash
python3 --version
sqlcmd --version
bcp -v
```

Run all Python commands below from this directory:

```bash
cd outputs/14-data-generator-G06
```

## 2. Configure SQL credentials on Fedora/Linux

Linux requires SQL authentication. Windows integrated authentication does not
work on Fedora. Every member either uses the password for their own local SQL
Server or receives a separate named login from the shared-server owner.

If SQL Server is already running, do not generate a new password. Export the
credentials that were used when that server or account was created:

```bash
export DB_SERVER='localhost,1433'
export DB_DATABASE='School'
export DB_USERNAME='sa'
export DB_PASSWORD='<the-existing-private-password>'
```

Do not commit, screenshot, or paste the password into documentation.

Alternatively, copy the included template and edit the private copy:

```bash
cp .env.example .env
# Edit .env and replace DB_PASSWORD with the real existing password.
```

The repository ignores `.env`. The `load` subcommand automatically reads this
file from the part-14 folder; no `source` command is required. `generate`,
`validate`, and `clean` do not read it. Variables already exported by Bash
take priority over values in `.env`.

### Optional: start a new local SQL Server container

Only use this when no SQL Server instance already exists:

```bash
export MSSQL_SA_PASSWORD="$(openssl rand -base64 24)Aa1!"
docker run --name cs486-sqlserver \
  -e 'ACCEPT_EULA=Y' \
  -e 'MSSQL_PID=Developer' \
  -e "MSSQL_SA_PASSWORD=$MSSQL_SA_PASSWORD" \
  -p 1433:1433 \
  -d mcr.microsoft.com/mssql/server:2022-latest

export DB_SERVER='localhost,1433'
export DB_DATABASE='School'
export DB_USERNAME='sa'
export DB_PASSWORD="$MSSQL_SA_PASSWORD"
```

Wait for SQL Server to become ready, then test authentication:

```bash
sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C \
  -Q "SELECT @@VERSION AS sql_server_version;"
```

If this fails, stop here. The generator cannot create or recover a SQL login.
The local container owner must provide the password, or the shared-server owner
must create an account.

### Optional: create a member account on a shared development server

The server owner runs this only after creating `School`, replacing both
placeholders privately:

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

Do not share the server's `sa` account. The broad `db_owner` role is only for
this disposable course database because the loader creates staging objects.

## 3. Create and migrate `School`

The loader intentionally accepts only `School`, because outputs 05 and 10 use
that database name. `CS486_G06` is not the project database name.

From the repository root, run these scripts once and in this exact order on a
fresh development server:

```bash
cd ../..

sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C -b \
  -i outputs/05-db-definition-G06.sql

sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C -b \
  -d School -i outputs/06-sample-data-G06.sql

sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C -b \
  -d School -i outputs/10-schema-migration-G06.sql

cd outputs/14-data-generator-G06
```

Confirm the target database exists and the migration objects are present:

```bash
sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C -d School \
  -Q "SELECT DB_NAME() AS database_name, OBJECT_ID('dbo.MaintenanceSession') AS migration_object_id;"
```

Expected: `database_name` is `School` and `migration_object_id` is not `NULL`.

## 4. Generate and validate 500,000 bookings

```bash
python3 -m src.cli generate \
  --users 10000 \
  --spaces 100 \
  --bookings 500000 \
  --maintenance 2500 \
  --seed 48606

python3 -m src.cli validate
```

Expected validation result:

```json
{
  "valid": true,
  "error_count": 0
}
```

Validation uses a temporary disk-backed SQLite database, so the 500,000-row
check remains memory-bounded.

## 5. Review the load without executing it

Run the credential-redacted dry run first:

```bash
python3 -m src.cli load \
  --trust-certificate
```

This prints the `sqlcmd` and `bcp` commands but changes nothing. Confirm that:

- the database is `School`;
- every input path points to this run's `generated/` directory;
- the displayed password is `********`;
- all seven staging files are listed.

## 6. Execute the server load

```bash
python3 -m src.cli load \
  --trust-certificate \
  --execute
```

The loader performs this sequence:

1. recreates `staging_phase2` tables;
2. bulk-loads all seven CSV files with `bcp`;
3. runs `sql/validate.sql`;
4. runs transactional, rerunnable `sql/load-final.sql`;
5. runs `sql/validate-final.sql` for final row counts, approved-overlap
   detection, booking-level acknowledgement flags, and allocated database size.

A successful run ends with:

```text
Staging and production load complete
```

It also creates `generated/load-evidence.json`. That file and the successful
final SQL output are the evidence that the server load actually ran.

## 7. Verify 500,000 rows manually

```bash
sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C -d School \
  -Q "SELECT COUNT_BIG(*) AS generated_booking_requests FROM dbo.BookingRequest WHERE booking_request_id BETWEEN '10000001' AND '10500000';"
```

Expected result: `500000`.

## Troubleshooting

### `received 'CS486_G06'. Set DB_DATABASE=School`

The wrong database name was supplied. Use:

```bash
export DB_DATABASE='School'
```

Nothing was executed before this error.

### `Linux requires SQL authentication`

The shell does not contain credentials. Export the existing account values:

```bash
export DB_USERNAME='sa'
export DB_PASSWORD='<the-existing-private-password>'
```

Nothing was executed before this error.

### `Login failed for user`

The loader received credentials, but SQL Server rejected them. Verify the
username/password with the connection-test command in section 2. Ask the
server owner to reset or create the login; do not change the loader to bypass
authentication.

### `sqlcmd` or `bcp` was not found

Install Microsoft SQL Server command-line tools and ensure both executables are
on `PATH`, then rerun the version checks from section 1.

## Reproducibility test

```bash
python3 -m unittest discover -s test
```

This generates two temporary datasets with the same seed, validates them, and
compares every CSV hash.

## Cleanup

Remove only locally generated files:

```bash
python3 -m src.cli clean --input generated --yes
```

Remove staging tables after retaining evidence:

```bash
sqlcmd -S "$DB_SERVER" -U "$DB_USERNAME" -P "$DB_PASSWORD" -C -b \
  -d School -i sql/clean-generated-data.sql
```

Remove the optional local container only if this member created it:

```bash
docker rm -f cs486-sqlserver
```

Finally clear secrets from the shell:

```bash
unset DB_PASSWORD MSSQL_SA_PASSWORD
```

## Verification boundary

Generation, bounded-memory validation, the final-schema adapter, and static
loader tests are implemented. Do not claim that the server load completed
until `generated/load-evidence.json` and successful final SQL validation have
been retained from an actual SQL Server run.
