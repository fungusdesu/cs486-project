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

Scale to 500,000 bookings by changing only `--bookings 500000`. Generated CSVs, metadata, and validation output are written to the relative `generated/` directory, which is ignored by Git.

## Automated reproducibility test

```bash
python3 -m unittest discover -s test
```

This creates two temporary 1,000-booking datasets, validates both, compares every CSV hash, and removes the temporary directories.

## SQL Server staging load

Install `sqlcmd` and `bcp`, then review the generated bulk-load commands:

```bash
python3 -m src.cli load --server localhost,1433 --database CS486_G06 --trust-certificate
```

Execute them only after checking the target database and credentials:

```bash
python3 -m src.cli load --server localhost,1433 --database CS486_G06 --trust-certificate --execute
```

Use `DB_USERNAME` and `DB_PASSWORD` for SQL authentication on Linux, Fedora, Docker, or Windows. If both are omitted, Windows trusted authentication is used. The loader creates parent staging tables before child tables and uses bulk loading; it does not issue one SQL `INSERT` per generated row.

`sql/load-final.sql` remains a documented stop-point until output 10 approves the final schema mapping. Run `sql/validate.sql` with `sqlcmd` after staging load.

## Cleanup

```bash
python3 -m src.cli clean --input generated --yes
```

PowerShell users may use `python` instead of `python3`. The cleanup command refuses directories outside the generated-data naming convention.

## Provisional interface boundary

Do not mark step 14 final until outputs 09–10 are approved, staging-to-final transformation is implemented, a clean SQL Server load succeeds, and the 100,000–500,000 row dataset passes both Python and SQL validation.