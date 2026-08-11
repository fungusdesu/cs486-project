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
  Materialize current approvals exactly once. This avoids repeated CTE
  evaluation on SQL Server Express and gives the window check an ordered,
  statistics-backed input.
*/
CREATE TABLE #ApprovedBookings
(
    booking_request_id CHAR(8) NOT NULL PRIMARY KEY NONCLUSTERED,
    space_id VARCHAR(10) NOT NULL,
    requested_start_time DATETIME NOT NULL,
    requested_end_time DATETIME NOT NULL
);

INSERT INTO #ApprovedBookings
    (booking_request_id, space_id, requested_start_time, requested_end_time)
SELECT br.booking_request_id, br.space_id,
       br.requested_start_time, br.requested_end_time
FROM dbo.BookingRequest AS br
INNER JOIN lookup_table.RequestState AS rs
    ON rs.request_state_id = br.request_state_id
WHERE rs.request_state_code = 'AUTO_APPROVED';

;WITH LatestReview AS
(
    SELECT r.booking_request_id, rd.request_decision_code,
           ROW_NUMBER() OVER
           (
               PARTITION BY r.booking_request_id
               ORDER BY r.decision_time DESC, r.review_id DESC
           ) AS review_rank
    FROM dbo.Review AS r
    INNER JOIN lookup_table.RequestDecision AS rd
        ON rd.request_decision_id = r.request_decision_id
)
INSERT INTO #ApprovedBookings
    (booking_request_id, space_id, requested_start_time, requested_end_time)
SELECT br.booking_request_id, br.space_id,
       br.requested_start_time, br.requested_end_time
FROM dbo.BookingRequest AS br
INNER JOIN LatestReview AS lr
    ON lr.booking_request_id = br.booking_request_id
   AND lr.review_rank = 1
   AND lr.request_decision_code = 'APPROVED'
WHERE NOT EXISTS
(
    SELECT 1 FROM #ApprovedBookings AS existing
    WHERE existing.booking_request_id = br.booking_request_id
);

CREATE CLUSTERED INDEX IX_ApprovedSchedule
    ON #ApprovedBookings
       (space_id, requested_start_time, requested_end_time, booking_request_id);

DECLARE @approved_overlap_exists BIT = 0;
;WITH SequencedBookings AS
(
    SELECT booking_request_id, space_id, requested_start_time,
           MAX(requested_end_time) OVER
           (
               PARTITION BY space_id
               ORDER BY requested_start_time, requested_end_time,
                        booking_request_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
           ) AS prior_max_end_time
    FROM #ApprovedBookings
)
SELECT TOP (1) @approved_overlap_exists = 1
FROM SequencedBookings
WHERE requested_start_time < prior_max_end_time
OPTION (RECOMPILE);

IF @approved_overlap_exists = 1
    INSERT @errors VALUES (N'Overlapping approved synthetic bookings exist in production.');

IF EXISTS
(
    SELECT 1
    FROM #ApprovedBookings AS approved
    INNER JOIN dbo.Maintenance AS mt ON mt.space_id = approved.space_id
    INNER JOIN dbo.MaintenanceSession AS ms
        ON ms.maintenance_id = mt.maintenance_id
    INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
        ON mil.maintenance_impact_level_id = ms.maintenance_impact_level_id
    WHERE mil.maintenance_impact_level_code = 'OUT_OF_SERVICE'
      AND approved.requested_start_time
            < ISNULL(ms.maintenance_end_time,
                     CONVERT(DATETIME, '99991231', 112))
      AND approved.requested_end_time > ms.maintenance_start_time
)
    INSERT @errors VALUES
        (N'An approved booking overlaps out-of-service maintenance.');

IF EXISTS
(
    SELECT 1
    FROM sys.triggers
    WHERE parent_id IN (OBJECT_ID(N'dbo.Review'), OBJECT_ID(N'dbo.BookingRequest'))
      AND is_disabled = 1
)
    INSERT @errors VALUES (N'A required production trigger is disabled.');

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
