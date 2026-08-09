# G06 Step 14 — Python Data Generator Scaffold

This scaffold generates deterministic, synthetic Phase 2 CSV data without AI-generated rows. It currently targets a schema-neutral staging format because outputs 09–10 are not finalized.

## Requirements

- Python 3.10 or later (tested with Python 3.12.10)
- Optional SQL Server command-line tools: `sqlcmd` and `bcp`

No third-party Python package is required for generation or validation.

## Quick start

Run commands from this directory. The commands are identical in PowerShell, bash, and WSL:

```powershell
python -m src.cli generate --users 1000 --spaces 30 --bookings 10000 --maintenance 200 --seed 48606
python -m src.cli validate
```

Scale using the same command:

```powershell
python -m src.cli generate --users 10000 --spaces 100 --bookings 500000 --maintenance 5000 --seed 48606
python -m src.cli validate
```

Generated files go to `generated/`, which is ignored by Git. `metadata.json` records the seed, requested counts, generated counts, and slot strategy. `validation.json` records integrity results.

The verified 500,000-booking scaffold run is summarized in `evidence/scaffold-benchmark-2026-08-02.md`.

## SQL Server staging load (Windows or Linux)

Install Microsoft SQL Server command-line tools (`sqlcmd` and `bcp`) and ensure both are on PATH. On Linux, use DB_USERNAME/DB_PASSWORD; on Windows, omit them for integrated authentication or set them for SQL authentication. Review the commands first:

```powershell
python -m src.cli load --server localhost --database CS486_G06 --trust-certificate
```

Execute them only when SQL Server and its command-line tools are available:

```powershell
python -m src.cli load --server localhost --database CS486_G06 --trust-certificate --execute
```

The loader creates and fills `staging_phase2` tables. `sql/load-final.sql` deliberately stops with an error until output 10 locks the final Phase 2 schema mapping.

For SQL authentication, set `DB_USERNAME` and `DB_PASSWORD`; otherwise the loader uses Windows trusted authentication.

The loader is a dry run unless `--execute` is supplied. It creates parent staging tables first, then bulk-loads child CSVs in foreign-key order. `sql/validate.sql` can be run with sqlcmd after loading. `sql/load-final.sql` is a documented stop-point until output 10 locks the final schema mapping.`n`n## Design notes

- Names are produced lazily from reusable surname, middle-name, and given-name components.
- CSV rows are streamed rather than accumulated in memory.
- Approved bookings receive unique one-hour space/time slots.
- Rejected and pending requests may overlap intentionally.
- Out-of-service maintenance changes an otherwise approved request to rejected.
- Advisory maintenance produces per-maintenance acknowledgement rows for approved bookings.
- Synthetic distribution ratios are generator choices, not business rules, and must remain configurable.

## Scaffold limitation

This is an explicitly authorized out-of-order scaffold. Do not mark step 14 done until:

1. outputs 09–10 are approved;
2. the staging-to-final mapping is implemented;
3. a clean SQL Server load succeeds; and
4. 100,000–500,000 rows pass both Python and SQL validation.

## Automated tests

Run the standard-library reproducibility test before generating a large dataset:

```bash
python3 -m unittest discover -s test
```

This generates two temporary 1,000-booking datasets with the same seed, validates both, and compares every CSV hash. The temporary directories are removed automatically.