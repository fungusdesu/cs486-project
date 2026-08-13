# Fedora 500,000-booking generator evidence — 2026-08-09

## Scope

This run verifies generation and bounded-memory Python validation. SQL Server,
`sqlcmd`, and `bcp` were not installed on this laptop, so this file is not
evidence of a completed server load.

## Environment and command

- OS: Fedora 43
- Python: 3.14.4
- Seed: 48606
- Command: `python3 -m src.cli generate --users 10000 --spaces 100 --bookings 500000 --maintenance 2500 --seed 48606`
- Validation: `python3 -m src.cli validate`

## Results

- Generated CSV bytes: 109,149,100
- Generation time: 28.942 seconds
- Validation time: 25.98 seconds
- Validation peak RSS: 28,296 KB
- Validation errors: 0
- Booking requests / booking relationships: 500,000 / 500,000
- Users / spaces / maintenance: 10,000 / 100 / 2,500
- Reviews / reservations / detailed acknowledgements: 342,367 / 340,324 / 1,302
- Approved / rejected / pending / cancelled: 340,324 / 69,881 / 49,953 / 39,842
- Completed / no-show / cancelled reservations: 285,789 / 34,306 / 20,229
- Calendar years represented: 2023, 2024, 2025, 2026
- Duplicate approved slots: 0

## Pending server evidence

Run the documented `load --execute` command on a SQL Server host and retain
`generated/load-evidence.json` plus successful `sql/validate-final.sql` output.
That later evidence must show exactly 500,000 staged and production booking
requests and report the allocated database size.
