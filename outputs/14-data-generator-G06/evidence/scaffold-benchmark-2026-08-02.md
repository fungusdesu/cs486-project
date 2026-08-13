# Step 14 Scaffold Benchmark — 2026-08-02

This is scaffold evidence, not final step 14 evidence. The production mapping remains blocked until outputs 09–10 are finalized.

## Environment

- Python: 3.12.10
- Operating system: Windows
- Command: `python -m src.cli generate --users 10000 --spaces 100 --bookings 500000 --maintenance 5000 --seed 48606`
- Validation command: `python -m src.cli validate`

## Results

- Generation time: 8.17 seconds
- Python validation time: 5.98 seconds
- SQL Server staging bulk-load time: 12.57 seconds
- Generated local file size: 113,697,030 bytes
- Booking requests: 500,000
- Booking relationships: 500,000
- Users: 10,000
- Spaces: 100
- Maintenance records: 5,000
- Reviews: 409,983
- Reservations: 339,234
- Advisory acknowledgements: 2,573
- Completed reservations: 285,003
- No-shows: 33,760
- Cancelled reservations: 20,471
- Represented calendar years: 2023, 2024, 2025, 2026
- Approved slot collisions: 0
- Validation errors: 0
- SQL Server staging counts matched all generated CSV row counts

The staging tables were removed from `tempdb` after validation. Generated CSV files remain ignored by Git and can be reproduced from the committed generator and seed.
