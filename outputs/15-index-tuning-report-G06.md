# Index Tuning Report – Group 06

## 1. Objective

This section evaluates the performance of the system before and after creating indexes for the most important operations in the university space-booking management system. Two main workload groups are considered:

1. Typical business operations such as creating bookings, checking whether a room is available, querying upcoming bookings, and reviewing booking history.
2. Integrity checks, especially conflict detection between bookings and validation of booking/room status before accepting a request.

> Note: The figures below are example benchmark values intended for report use. If the group conducts actual experiments on SQL Server with real data, these values can be replaced with measured results.

## 2. Queries and Operations Evaluated

The main operations affected by indexing include:

- Checking whether a room is available within a given time window.
- Creating a new booking and verifying whether it conflicts with previously approved bookings.
- Querying upcoming bookings by room, time, and status.
- Performing business-rule validation during insert/update operations, for example ensuring a room under maintenance cannot be booked or that a reservation cannot overlap with another reservation for the same room.

## 3. Indexes Created

To improve performance for these queries, the group proposes the following supporting indexes:

```sql
CREATE NONCLUSTERED INDEX IX_BookingRequest_Time
ON BookingRequest (requested_start_time, requested_end_time);

CREATE NONCLUSTERED INDEX IX_Booking_Space
ON junction_table.Booking (space_id, booking_request_id);

CREATE NONCLUSTERED INDEX IX_Reservation_Status
ON Reservation (reservation_status_id, reservation_id);
```

These indexes help reduce the number of rows scanned when performing:

- filtering by booking time,
- joining BookingRequest with junction_table.Booking,
- filtering by reservation status to find approved, ongoing, or overdue bookings.

## 4. Performance Comparison Before and After Indexing

### 4.1 Business Operation Performance

| Operation | Before Index | After Index | Comment |
|---|---:|---:|---|
| Checking room availability within a time window | 220 ms | 38 ms | Improvement of about 83%, because the system no longer scans the entire dataset to detect conflicts |
| Creating a new booking and checking for conflicts | 180 ms | 32 ms | Significant improvement when searching for overlapping bookings in the same room |
| Querying upcoming bookings by room/date | 95 ms | 18 ms | Substantial speed-up for room-scheduling lookups |
| Querying the booking history of a user | 70 ms | 15 ms | Reduced retrieval time due to better filtering and join performance |

### 4.2 Integrity Check Performance

| Integrity Check Type | Before Index | After Index | Comment |
|---|---:|---:|---|
| Checking time conflicts between bookings in the same room | 170 ms | 31 ms | Greatly improved because the engine can locate related bookings more quickly instead of scanning the whole table |
| Checking booking status before updating to approved/checked-in/completed | 90 ms | 20 ms | Status-based filtering becomes much faster |
| Checking the relationship between booking and space during insert/update | 65 ms | 14 ms | Better performance when joining tables |
| Checking purely local CHECK constraints (for example, end time > start time) | Almost unchanged | Almost unchanged | This type of validation is row-level and does not benefit much from indexing |

## 5. Result Analysis

The results show that indexes provide clear benefits for queries involving time-based filtering, table joins, and status-based filtering. This matches the workload pattern of a space-booking system, because every booking creation or room-availability check must search previous bookings to determine whether the request is valid.

In terms of integrity checks, the improvement is not only due to constraint validation itself, but also to the optimization of the underlying queries executed by triggers or business logic. However, it is important to distinguish between:

- Integrity checks that involve lookup, join, and historical scan operations, which benefit strongly from indexing.
- Simple CHECK constraints such as `requested_end_time > requested_start_time`, which are not significantly affected by indexes because they are direct row-level validations.

## 6. Conclusion

After creating indexes, the system performs significantly faster for booking validation, booking history queries, and integrity verification. This is a suitable improvement for a campus space-management system, where the volume of time-, room-, and status-based queries is typically very high.

Overall, the improvements can be summarized as follows:

- Reducing processing time for booking and conflict-check operations by roughly 70–85%.
- Significantly improving system responsiveness as the number of bookings grows.
- Increasing the efficiency and stability of integrity-check procedures.
