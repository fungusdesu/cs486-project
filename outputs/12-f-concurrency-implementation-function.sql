USE School;
GO
SET XACT_ABORT ON;
------------------------------------------------------
-- Support type for Function 5
-- Represents the required set of facility TYPES.
------------------------------------------------------
IF TYPE_ID(N'dbo.FacilityRequirementTable') IS NULL
BEGIN
    EXEC(N'
        CREATE TYPE dbo.FacilityRequirementTable AS TABLE
        (
            facility_type_code VARCHAR(20) NOT NULL PRIMARY KEY
        );
    ');
END;
GO

------------------------------------------------------
-- Function 1: GetAllAdvisories
-- Return active ADVISORY maintenance records for a space.
------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.UF_GetAllAdvisories
(
    @space_id VARCHAR(10)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        m.maintenance_id,
        m.maintenance_description,
        mts.maintenance_status_name
    FROM dbo.Maintenance AS m
    INNER JOIN dbo.MaintenanceSession AS ms
        ON ms.maintenance_id = m.maintenance_id
    INNER JOIN lookup_table.MaintenanceStatus AS mts
        ON mts.maintenance_status_id = m.maintenance_status_id
    INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
        ON mil.maintenance_impact_level_id = ms.maintenance_impact_level_id
    WHERE m.space_id = @space_id
      AND mts.maintenance_status_code = 'ONGOING'
      AND mil.maintenance_impact_level_code = 'ADVISORY'
);
GO

------------------------------------------------------
-- Function 2: GetReservationsFromCriticalSpace
-- Return PENDING/CHECKED_IN reservations associated with the space of an active OUT_OF_SERVICE maintenance.
------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.UF_GetReservationsFromCriticalSpace
(
    @maintenance_id CHAR(6)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        r.reservation_id
    FROM dbo.Maintenance AS m
    INNER JOIN dbo.MaintenanceSession AS ms
        ON ms.maintenance_id = m.maintenance_id
    INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
        ON mil.maintenance_impact_level_id = ms.maintenance_impact_level_id
    INNER JOIN lookup_table.MaintenanceStatus AS mts
        ON mts.maintenance_status_id = m.maintenance_status_id
    INNER JOIN dbo.BookingRequest AS br
        ON br.space_id = m.space_id
    INNER JOIN dbo.Reservation AS r
        ON r.booking_request_id = br.booking_request_id
    INNER JOIN lookup_table.ReservationStatus AS rs
        ON rs.reservation_status_id = r.reservation_status_id
    WHERE m.maintenance_id = @maintenance_id
      AND mts.maintenance_status_code = 'ONGOING'
      AND mil.maintenance_impact_level_code = 'OUT_OF_SERVICE'
      AND rs.reservation_status_code IN ('PENDING', 'CHECKED_IN')
);
GO

------------------------------------------------------
-- Function 3: GetReservationTimePerSpace
-- Aggregate completed actual reservation-session time by space. Optional bounds are inclusive.
------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.UF_GetReservationTimePerSpace
(
    @start_time DATETIME = NULL,
    @end_time   DATETIME = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        br.space_id,
        s.space_name,
        CAST(
            SUM(
                CAST(
                    DATEDIFF(MINUTE, rse.actual_start_time, rse.actual_end_time)
                    AS BIGINT
                )
            ) / 60.0
            AS DECIMAL(18, 2)
        ) AS total_reservation_hours
    FROM dbo.ReservationSession AS rse
    INNER JOIN dbo.Reservation AS r
        ON r.reservation_id = rse.reservation_id
    INNER JOIN dbo.BookingRequest AS br
        ON br.booking_request_id = r.booking_request_id
    INNER JOIN dbo.Space AS s
        ON s.space_id = br.space_id
    WHERE rse.actual_end_time IS NOT NULL
      AND (@start_time IS NULL OR rse.actual_start_time >= @start_time)
      AND (@end_time   IS NULL OR rse.actual_end_time   <= @end_time)
    GROUP BY
        br.space_id,
        s.space_name
);
GO

------------------------------------------------------
-- Function 4: GetReservationCountPerHourPerWeekday
-- Count reservation sessions by weekday and start hour. Weekday_number is coded as: Monday = 1 ... Sunday = 7.
------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.UF_GetReservationCountPerHourPerWeekday
(
    @start_time DATETIME = NULL,
    @end_time   DATETIME = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        x.weekday_number,
        CHOOSE(
            x.weekday_number,
            N'Monday',
            N'Tuesday',
            N'Wednesday',
            N'Thursday',
            N'Friday',
            N'Saturday',
            N'Sunday'
        ) AS weekday_name,
        x.hour_of_day,
        COUNT(*) AS reservation_count
    FROM
    (
        SELECT
            (
                (
                    DATEDIFF(
                        DAY,
                        CONVERT(DATE, '19000101', 112),
                        CONVERT(DATE, rse.actual_start_time)
                    ) % 7 + 7
                ) % 7
            ) + 1 AS weekday_number,
            DATEPART(HOUR, rse.actual_start_time) AS hour_of_day
        FROM dbo.ReservationSession AS rse
        WHERE (@start_time IS NULL OR rse.actual_start_time >= @start_time)
          AND (@end_time   IS NULL OR rse.actual_end_time   <= @end_time)
    ) AS x
    GROUP BY
        x.weekday_number,
        x.hour_of_day
);
GO

------------------------------------------------------
-- Function 5: GetSatisfactorySpaces
-- Relational division: return spaces with capacity >= @capacity that contain every facility type listed in @facility_table.
------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.UF_GetSatisfactorySpaces
(
    @capacity SMALLINT,
    @facility_table dbo.FacilityRequirementTable READONLY
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        s.space_id,
        s.space_name,
        s.capacity,
        s.building,
        s.floor,
        s.room_number
    FROM dbo.Space AS s
    WHERE s.capacity >= @capacity
      AND NOT EXISTS
      (
          SELECT 1
          FROM @facility_table AS required_facility
          WHERE NOT EXISTS
          (
              SELECT 1
              FROM dbo.Facility AS f
              INNER JOIN lookup_table.FacilityType AS ft
                  ON ft.facility_type_id = f.facility_type_id
              WHERE f.space_id = s.space_id
                AND ft.facility_type_code =
                    required_facility.facility_type_code
          )
      )
);
GO

SET XACT_ABORT OFF;
