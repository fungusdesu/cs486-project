# G06 Step 14 — Python Procedural Data Generator

This generator creates deterministic synthetic Phase 2 CSV data without AI-generated rows. It targets a schema-neutral staging format until outputs 09–10 are approved.

## Requirements

- Python 3.10 or later
- No third-party Python package for generation, validation, or unit tests
- Optional SQL Server command-line tools: `sqlcmd` and `bcp`

## Quick start

Run from this directory. The commands are portable between PowerShell, bash, Fedora, Linux, macOS, and WSL.

```bash
python3 -m src.cli generate --users 1000 --spaces 30 --bookings 10000 --maintenance 200 --seed 48606
python3 -m src.cli validate
```

PowerShell users may use `python` instead of `python3`.

Required-size run:

```bash
python3 -m src.cli generate --users 10000 --spaces 100 --bookings 100000 --maintenance 2500 --seed 48606
python3 -m src.cli validate
```

Scale to 500,000 bookings by changing only `--bookings 500000`. Generated CSVs, metadata, and validation output are written to the relative `generated/` directory, which is ignored by Git. Validation uses a temporary disk-backed SQLite workspace, so the 500,000-row check remains memory-bounded.

## Automated reproducibility test

```bash
python3 -m unittest discover -s test
```

This creates two temporary 1,000-booking datasets, validates both, compares every CSV hash, and removes the temporary directories.

## Fedora development credentials

Use a dedicated local-only SQL login. Generate the password in the shell and
do not put its value in this repository, command history, screenshots, or an
evidence file:

```bash
export MSSQL_SA_PASSWORD="$(openssl rand -base64 24)Aa1!"
export DB_SERVER='localhost,1433'
export DB_DATABASE='School'
export DB_USERNAME='sa'
export DB_PASSWORD="$MSSQL_SA_PASSWORD"
```

The variable names are the public interface; the values are machine-local.
Unset them after the run with `unset MSSQL_SA_PASSWORD DB_PASSWORD`.

On Linux, the loader deliberately refuses to fall back to Windows integrated
authentication. If either `DB_USERNAME` or `DB_PASSWORD` is missing, it exits
before calling `sqlcmd`. This prevents the `Login failed for user ''` failure.
The database must be `School`, matching outputs 05 and 10; the loader rejects
stale examples that use `CS486_G06`.

## SQL Server production load

Install `sqlcmd` and `bcp`, then review the generated bulk-load commands:

```bash
python3 -m src.cli load --server "$DB_SERVER" --database "$DB_DATABASE" --trust-certificate
```

Execute them only after checking the target database and credentials:

```bash
python3 -m src.cli load --server "$DB_SERVER" --database "$DB_DATABASE" --trust-certificate --execute
```

Use `DB_USERNAME` and `DB_PASSWORD` for SQL authentication on Linux, Fedora,
Docker, or Podman. If both are omitted, Windows trusted authentication is
used. Before this command, create the `School` database by running outputs 05,
06, and 10 in order. The loader then runs one reproducible pipeline:

1. recreate typed-neutral staging tables;
2. bulk-copy all eight CSV files with `bcp`;
3. run `sql/validate.sql`;
4. run the transactional and rerunnable `sql/load-final.sql` transformation;
5. run `sql/validate-final.sql`, including final row counts, approved-slot
   uniqueness, acknowledgement flags, and allocated database size.

This is a bulk load followed by set-based SQL; it does not issue one `INSERT`
per generated row. `generated/load-evidence.json` records the staging and
production load durations without recording credentials.

The generator retains one row per maintenance acknowledgement in staging.
Output 10 currently exposes only `BookingRequest.advisory_acknowledged`, so
the production transformation preserves the aggregate Boolean while leaving
the detailed rows in staging as traceable evidence of that schema limitation.

## Cleanup

```bash
python3 -m src.cli clean --input generated --yes
```

PowerShell users may use `python` instead of `python3`. The cleanup command refuses directories outside the generated-data naming convention.

## Verification boundary

The 500,000-row generation, reproducibility test, bounded-memory Python
validation, staging schema, production transformation, and final SQL
validation are implemented. On a computer without SQL Server, query execution
remains unverified; the operator must retain `generated/load-evidence.json`
and the successful `validate-final.sql` output before claiming the server load
itself is complete.
