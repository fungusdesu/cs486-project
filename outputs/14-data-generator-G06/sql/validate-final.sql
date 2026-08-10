SET NOCOUNT ON;

DECLARE @errors TABLE (validation_error NVARCHAR(500) NOT NULL);

IF (SELECT COUNT_BIG(*) FROM dbo.[User] u INNER JOIN staging_phase2.Users s ON s.user_id = u.user_id)
   <> (SELECT COUNT_BIG(*) FROM staging_phase2.Users)
    INSERT @errors VALUES (N'Production user count does not match staging.');

IF (SELECT COUNT_BIG(*) FROM dbo.Space p INNER JOIN staging_phase2.Spaces s ON s.space_id = p.space_id)
   <> (SELECT COUNT_BIG(*) FROM staging_phase2.Spaces)
    INSERT @errors VALUES (N'Production space count does not match staging.');

IF (SELECT COUNT_BIG(*) FROM dbo.Maintenance p INNER JOIN staging_phase2.Maintenance s ON s.maintenance_id = p.maintenance_id)
   <> (SELECT COUNT_BIG(*) FROM staging_phase2.Maintenance)
    INSERT @errors VALUES (N'Production maintenance count does not match staging.');

IF (SELECT COUNT_BIG(*) FROM dbo.BookingRequest p INNER JOIN staging_phase2.BookingRequests s ON s.booking_request_id = p.booking_request_id)
   <> (SELECT COUNT_BIG(*) FROM staging_phase2.BookingRequests)
    INSERT @errors VALUES (N'Production booking-request count does not match staging.');

IF (SELECT COUNT_BIG(*) FROM dbo.Review p INNER JOIN staging_phase2.Reviews s ON s.review_id = p.review_id)
   <> (SELECT COUNT_BIG(*) FROM staging_phase2.Reviews)
    INSERT @errors VALUES (N'Production review count does not match staging.');

IF (SELECT COUNT_BIG(*) FROM dbo.Reservation p INNER JOIN staging_phase2.Reservations s ON s.reservation_id = p.reservation_id)
   <> (SELECT COUNT_BIG(*) FROM staging_phase2.Reservations)
    INSERT @errors VALUES (N'Production reservation count does not match staging.');

/*
  Detect interval overlap in O(n log n) rather than self-joining the entire
  approved set. The running maximum is required (LAG alone misses intervals
  nested inside an earlier long interval).
*/
DECLARE @approved_overlap_exists BIT = 0;

;WITH ApprovedBookings AS
(
    SELECT br.booking_request_id, br.space_id,
           br.requested_start_time, br.requested_end_time
    FROM dbo.BookingRequest br
    INNER JOIN staging_phase2.BookingRequests s
        ON s.booking_request_id = br.booking_request_id
    INNER JOIN lookup_table.RequestState rs
        ON rs.request_state_id = br.request_state_id
    WHERE rs.request_state_code = 'AUTO_APPROVED'

    UNION ALL

    SELECT br.booking_request_id, br.space_id,
           br.requested_start_time, br.requested_end_time
    FROM dbo.BookingRequest br
    INNER JOIN staging_phase2.BookingRequests s
        ON s.booking_request_id = br.booking_request_id
    INNER JOIN dbo.Review r ON r.booking_request_id = br.booking_request_id
    INNER JOIN lookup_table.RequestDecision rd
        ON rd.request_decision_id = r.request_decision_id
    WHERE rd.request_decision_code = 'APPROVED'
), SequencedBookings AS
(
    SELECT booking_request_id, space_id, requested_start_time,
           MAX(requested_end_time) OVER
           (
               PARTITION BY space_id
               ORDER BY requested_start_time, requested_end_time, booking_request_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
           ) AS prior_max_end_time
    FROM ApprovedBookings
)
SELECT TOP (1) @approved_overlap_exists = 1
FROM SequencedBookings
WHERE requested_start_time < prior_max_end_time;

IF @approved_overlap_exists = 1
    INSERT @errors VALUES (N'Overlapping approved synthetic bookings exist in production.');

IF EXISTS (SELECT 1 FROM @errors)
BEGIN
    SELECT validation_error FROM @errors;
    THROW 51401, 'Final generated-data validation failed.', 1;
END;

SELECT N'valid' AS final_validation,
       (SELECT COUNT_BIG(*) FROM staging_phase2.BookingRequests) AS booking_requests;

SELECT DB_NAME(database_id) AS database_name,
       CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18, 2)) AS allocated_size_mb
FROM sys.master_files
WHERE database_id = DB_ID()
GROUP BY database_id;
