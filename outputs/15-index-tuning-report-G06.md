# Index Tuning Report — Group 06

## Scope and evidence

This report contains measured SQL Server results, not estimated values. The benchmark used the retained Phase 2 database with 100,019 booking requests (100,000 generated plus 19 pre-existing) and 68,360 reviews on Microsoft SQL Server 2025 Express 17.0.1125.2, Windows 11.

Reproduction scripts:

- `15-index-benchmark-G06.sql`: one warm-up and five measured repetitions per phase.
- `15-index-io-sample-G06.sql`: representative `SET STATISTICS IO, TIME ON` sample.
- `16-analytical-queries-G06.sql`: final query definitions.

The 500,000-row run is deferred by user instruction. The loaded 100,000-row dataset already produced clear, repeatable differences.

## Attribution boundary: index-only comparison

The before/after figures in this report measure **only the effect of the three indexes**. Both phases used the same corrected Output 16 query text, the same stored procedures, the same 100,019 booking rows, the same parameters, and the same warm-up/repetition policy. The baseline phase removed only the three named nonclustered indexes; the indexed phase recreated them and updated statistics.

No query logic, join, predicate, trigger, validation algorithm, or dataset changed between the baseline and indexed measurements. Therefore, the percentages and timing tables below must not be presented as benefits from the earlier logic refactoring. The separate reduction from the original seven-hour estimate to the final 46.813-second load reflects the combined effect of set-based logic, scalable validation, batching changes, and indexes; it is not an index-only result.
## Method

The benchmark dropped only the three named nonclustered indexes below, warmed each query once, measured five repetitions, recreated the indexes, ran `UPDATE STATISTICS ... WITH FULLSCAN`, warmed the queries again, and repeated the same parameters. No booking data was removed or changed.

Targets:

1. Approved-booking conflict check for one space and time range.
2. Available-space room finder.
3. Approved hours per space for one academic year.
4. Approved booking starts by weekday and hour for one academic year.

## Indexes retained

```sql
CREATE INDEX IX_G06_P14_BookingRequest_SpaceWindow
ON dbo.BookingRequest
   (space_id, requested_start_time, requested_end_time, booking_request_id)
INCLUDE (request_state_id);

CREATE INDEX IX_G06_P14_Review_CurrentDecision
ON dbo.Review
   (booking_request_id, decision_time DESC, review_id DESC)
INCLUDE (request_decision_id);

CREATE INDEX IX_G06_P15_BookingRequest_ReportStart
ON dbo.BookingRequest (requested_start_time)
INCLUDE (requested_end_time, space_id, request_state_id);
```

The first index supports equality by space followed by the interval-start range and covers request state. The second supports `TOP (1) ... ORDER BY decision_time DESC, review_id DESC` without sorting each request's review history. The third supports semester/start-time report filtering while covering the remaining booking columns.

## Repeated elapsed-time results

| Target | Baseline average | Indexed average | Baseline range | Indexed range | Improvement |
|---|---:|---:|---:|---:|---:|
| Conflict check | 115.417 ms | 2.001 ms | 101.513–133.516 ms | 2.000–2.002 ms | 98.3% |
| Room finder | 3,713.479 ms | 10.905 ms | 3,504.240–3,963.536 ms | 10.523–11.000 ms | 99.7% |
| Approved hours | 216.074 ms | 125.132 ms | 200.035–257.250 ms | 116.093–140.516 ms | 42.1% |
| Weekday/hour | 211.629 ms | 108.470 ms | 203.016–220.033 ms | 103.510–119.310 ms | 48.7% |

## Representative SQL Server IO and CPU sample

Logical reads below sum the base/work tables reported for the target statement. Table-variable output bookkeeping is excluded equally from both phases.

| Target | Baseline logical reads | Indexed logical reads | Baseline CPU | Indexed CPU |
|---|---:|---:|---:|---:|
| Conflict check | 142,292 | 1,505 | 109 ms | 0 ms (below timer resolution) |
| Room finder | 238,958 | 870 | 3,703 ms | 47 ms |
| Approved hours | 255,205 | 147,864 | 250 ms | 93 ms |
| Weekday/hour | 255,200 | 147,859 | 235 ms | 110 ms |

The actual plans reflected the IO change: without the indexes SQL Server scanned `BookingRequest`/`Review` and created large worktables; with the indexes it used the space-window and current-decision access paths. The room finder changed from 93,886 `BookingRequest` reads plus 138,528 worktable reads to 498 `BookingRequest` reads and no worktable reads.

## Trade-offs

These indexes consume storage and add maintenance to booking/review writes. That cost is justified because approvals and room searches are correctness-critical and frequent. The report-start index benefits large semester reports but should be monitored if write volume becomes dominant. The benchmark intentionally avoids redundant indexes on lookup tables whose primary/unique keys already cover joins.

## Conclusion

With identical corrected logic in both phases, adding only the three measured indexes improved all four required targets on the retained 100k dataset. The percentages in this report are therefore index-only improvements for this workload and environment. The separate 46.813-second production-load result is not used to calculate these index percentages because that overall load also benefited from logic and validation refactoring.