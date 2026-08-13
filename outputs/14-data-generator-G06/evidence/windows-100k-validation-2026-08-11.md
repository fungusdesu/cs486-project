# Windows 100,000-row trigger-enabled load evidence

Date: 2026-08-11  
DBMS: Microsoft SQL Server 2025 Developer Edition  
Database: `School`  
Generator seed: `48606`

## Result

The staged 100,000-booking dataset loaded successfully with all validation
triggers enabled. The retained database contains 100,019 booking requests:
100,000 generated requests plus 19 rows that existed before the benchmark.

| Measurement | Result |
|---|---:|
| Generate CSV files | 1.309 s |
| Load staging tables | 9.611 s |
| Production load and final validation | 37.202 s |
| Staging + production total | 46.813 s |
| Final validation query | 3.169 s |

## Generated and loaded rows

| Dataset | Rows |
|---|---:|
| Users | 10,000 |
| Spaces | 100 |
| Maintenance | 2,500 |
| Booking requests | 100,000 |
| Bookings | 100,000 |
| Reviews | 68,346 |
| Reservations | 68,219 |

The final validator returned `valid` for all 100,000 generated booking
requests. A follow-up database query confirmed that all eight triggers on
`dbo.BookingRequest` and `dbo.Review` remained enabled.

## Scale decision

The 10,000-row rehearsal completed successfully before the 100,000-row run.
The 100,000-row result is retained as the current benchmark dataset. The
500,000-row run is intentionally deferred by user instruction.

Raw CSV files and machine-specific runtime logs remain ignored because they
are reproducible and may contain environment-specific paths. This sanitized
file is the version-controlled evidence record.