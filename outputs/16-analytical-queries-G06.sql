USE School
GO

SET NOCOUNT ON;
GO

/*
  outputs/16-analytical-queries-G06.sql
  Converted to procedural format to match style in outputs/12-concurrency-implementation-G06.sql

  Procedures provided:
  - USP_GetApprovedHoursPerSpace(@semester_start, @semester_end)
  - USP_GetApprovedBookingCountByWeekdayHour(@semester_start, @semester_end)
  - USP_GetApprovedBookingCountPerHour(@semester_start, @semester_end)
  - USP_FindAvailableSpaces(@period_start, @period_end, @required_capacity, @facility_table)
  - USP_GetBookingsAffectedByMaintenance(@maintenance_id)

    Notes:
    - Approved reviews are identified by lookup code mapping; use `lookup_table.RequestDecision` with `request_decision_code = 'APPROVED'`.
    - The type `dbo.FacilityRequirementTable` is created in outputs/12; procedures accept it as READONLY where needed.
*/

------------------------------------------------------
-- 1) Total approved booking hours of each space for a semester
------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetApprovedHoursPerSpace
    @semester_start DATETIME,
    @semester_end   DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.space_id,
        s.space_name,
        SUM(CAST(DATEDIFF(MINUTE,
            CASE WHEN br.requested_start_time > @semester_start THEN br.requested_start_time ELSE @semester_start END,
            CASE WHEN br.requested_end_time   < @semester_end   THEN br.requested_end_time   ELSE @semester_end   END
        ) AS FLOAT) / 60.0) AS total_approved_hours
    FROM BookingRequest br
    JOIN Review r ON r.booking_request_id = br.booking_request_id
    JOIN lookup_table.RequestDecision rd ON rd.request_decision_id = r.request_decision_id
    JOIN Space s ON s.space_id = br.space_id
    WHERE rd.request_decision_code = 'APPROVED'
      AND br.requested_start_time < @semester_end
      AND br.requested_end_time > @semester_start
    GROUP BY s.space_id, s.space_name
    ORDER BY total_approved_hours DESC;
END
GO

------------------------------------------------------
-- 2) Number of approved bookings by weekday and hour
--    (simple classification by requested_start_time)
----------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetApprovedBookingCountByWeekdayHour
    @semester_start DATETIME,
    @semester_end   DATETIME
AS
BEGIN
    SET NOCOUNT ON;

        SELECT
                DATEPART(WEEKDAY, br.requested_start_time) AS weekday,
                DATEPART(HOUR, br.requested_start_time) AS hour,
                COUNT(1) AS approved_count
        FROM BookingRequest br
        JOIN Review r ON r.booking_request_id = br.booking_request_id
        JOIN lookup_table.RequestDecision rd ON rd.request_decision_id = r.request_decision_id
        WHERE rd.request_decision_code = 'APPROVED'
            AND br.requested_start_time >= @semester_start
            AND br.requested_start_time <= @semester_end
        GROUP BY DATEPART(WEEKDAY, br.requested_start_time), DATEPART(HOUR, br.requested_start_time)
        ORDER BY weekday, hour;
END
GO


------------------------------------------------------
-- 2b) Precise per-hour occupancy: expand approved bookings into hour slots
--     Returns weekday/hour counts within the semester window.
------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetApprovedBookingCountPerHour
    @semester_start DATETIME,
    @semester_end   DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @maxHours INT = DATEDIFF(HOUR, @semester_start, @semester_end);

    ;WITH Numbers AS (
        SELECT 0 AS n
        UNION ALL
        SELECT n + 1 FROM Numbers WHERE n + 1 <= @maxHours
    ), Bookings AS (
        SELECT br.booking_request_id, br.space_id,
            DATEADD(HOUR, DATEDIFF(HOUR, 0, CASE WHEN br.requested_start_time > @semester_start THEN br.requested_start_time ELSE @semester_start END), 0) AS start_hour,
            DATEADD(HOUR, DATEDIFF(HOUR, 0, CASE WHEN br.requested_end_time < @semester_end THEN br.requested_end_time ELSE @semester_end END), 0) AS end_hour
        FROM BookingRequest br
        JOIN Review r ON r.booking_request_id = br.booking_request_id
        JOIN lookup_table.RequestDecision rd ON rd.request_decision_id = r.request_decision_id
        WHERE rd.request_decision_code = 'APPROVED'
          AND br.requested_start_time < @semester_end
          AND br.requested_end_time > @semester_start
    ), Slots AS (
        SELECT bk.booking_request_id,
               DATEADD(HOUR, n.n + DATEDIFF(HOUR, 0, bk.start_hour), 0) AS slot_start
        FROM Bookings bk
        JOIN Numbers n ON n.n < DATEDIFF(HOUR, bk.start_hour, bk.end_hour)
    )
    SELECT
        DATEPART(WEEKDAY, slot_start) AS weekday,
        DATEPART(HOUR, slot_start) AS hour,
        COUNT(1) AS approved_count
    FROM Slots
    GROUP BY DATEPART(WEEKDAY, slot_start), DATEPART(HOUR, slot_start)
    ORDER BY weekday, hour
    OPTION (MAXRECURSION 0);
END
GO


------------------------------------------------------
-- 3) Room finder: available spaces matching capacity and facility list
--    Accepts a table-valued parameter of required facility codes.
----------------------------------------------------------------
    IF TYPE_ID(N'FacilityRequirementTable') IS NULL
BEGIN
    CREATE TYPE dbo.FacilityRequirementTable AS TABLE
    (
        facility_type_code VARCHAR(20) NOT NULL PRIMARY KEY
    );
END;
GO

CREATE OR ALTER PROCEDURE USP_FindAvailableSpaces
    @period_start DATETIME,
    @period_end   DATETIME,
    @required_capacity INT,
    @facility_table dbo.FacilityRequirementTable READONLY
AS
BEGIN
    SET NOCOUNT ON;

        SELECT
                s.space_id,
                s.space_name,
                s.capacity,
                s.building,
                s.floor,
                s.room_number
        FROM dbo.Space AS s
        WHERE s.capacity >= @required_capacity
            AND NOT EXISTS (
                    SELECT 1
                    FROM BookingRequest br
                    JOIN Review r ON r.booking_request_id = br.booking_request_id
                    JOIN lookup_table.RequestDecision rd ON rd.request_decision_id = r.request_decision_id
                    WHERE br.space_id = s.space_id
                        AND rd.request_decision_code = 'APPROVED'
                        AND br.requested_start_time < @period_end
                        AND br.requested_end_time > @period_start
            )
            AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.MaintenanceSession ms
                    JOIN dbo.Maintenance m ON m.maintenance_id = ms.maintenance_id
                    JOIN lookup_table.MaintenanceStatus mst ON mst.maintenance_status_id = m.maintenance_status_id
                    JOIN lookup_table.MaintenanceImpactLevel mil ON mil.maintenance_impact_level_id = ms.maintenance_impact_level_id
                    WHERE m.space_id = s.space_id
                        AND mil.maintenance_impact_level_code = 'OUT_OF_SERVICE'
                        AND ms.maintenance_start_time < @period_end
                        AND (ms.maintenance_end_time IS NULL OR ms.maintenance_end_time > @period_start)
            )
            AND NOT EXISTS (
                    SELECT 1
                    FROM @facility_table AS required_facility
                    WHERE NOT EXISTS (
                            SELECT 1
                            FROM dbo.Facility AS f
                            INNER JOIN lookup_table.FacilityType AS ft ON ft.facility_type_id = f.facility_type_id
                            WHERE f.space_id = s.space_id
                                AND ft.facility_type_code = required_facility.facility_type_code
                    )
            )
        ORDER BY s.capacity DESC, s.space_name;
END
GO


------------------------------------------------------
-- 4) Approved bookings affected when a maintenance record is escalated
------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetBookingsAffectedByMaintenance
    @maintenance_id VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

        SELECT
                br.booking_request_id,
                br.user_id AS requester_id,
                br.space_id,
                br.requested_start_time AS booking_start,
                br.requested_end_time   AS booking_end,
                CASE WHEN br.requested_start_time > ms.maintenance_start_time THEN br.requested_start_time ELSE ms.maintenance_start_time END AS overlap_start,
                CASE WHEN br.requested_end_time   < ISNULL(ms.maintenance_end_time, br.requested_end_time) THEN br.requested_end_time ELSE ISNULL(ms.maintenance_end_time, br.requested_end_time) END AS overlap_end
        FROM dbo.MaintenanceSession ms
        JOIN dbo.Maintenance m ON m.maintenance_id = ms.maintenance_id
        JOIN BookingRequest br ON br.space_id = m.space_id
        JOIN Review r ON r.booking_request_id = br.booking_request_id
        JOIN lookup_table.RequestDecision rd ON rd.request_decision_id = r.request_decision_id
        WHERE ms.maintenance_id = @maintenance_id
            AND rd.request_decision_code = 'APPROVED'
            AND br.requested_start_time < ISNULL(ms.maintenance_end_time, br.requested_end_time)
            AND br.requested_end_time > ms.maintenance_start_time
        ORDER BY overlap_start;
END
GO


/* Index recommendations (keep as comments) */
/*
CREATE INDEX IX_BookingRequest_space_times ON BookingRequest (space_id, requested_start_time, requested_end_time);
CREATE INDEX IX_BookingRequest_times ON BookingRequest (booking_request_id, requested_start_time, requested_end_time);
CREATE INDEX IX_Review_decision_bookingreq ON Review (request_decision_id, booking_request_id);
CREATE INDEX IX_Facility_space_ftid ON Facility (space_id, facility_type_id);
CREATE INDEX IX_MaintenanceSession_times ON MaintenanceSession (maintenance_id, maintenance_start_time, maintenance_end_time);

-- Example filtered index for approved reviews (SQL Server filtered index):
-- Replace <approved_id> with the numeric id for the 'APPROVED' code in lookup_table.RequestDecision
CREATE INDEX IX_Review_approved ON Review (booking_request_id) WHERE request_decision_id = <approved_id>;
*/

SET NOCOUNT OFF;
GO