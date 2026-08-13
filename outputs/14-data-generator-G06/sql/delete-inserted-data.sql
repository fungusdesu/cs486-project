/*
  Delete only data inserted by the G06 Part 14 synthetic-data loader.

  Synthetic identifier boundaries are fixed by src/generate.py:
    BookingRequest  10000001-10500000
    User            80000001-80010000
    Space           S0001-S0100
    Maintenance     m00001-m02500

  The script is transactional and rerunnable. It refuses to delete generated
  spaces if a non-Part-14 Facility row has subsequently been attached to one.
  It also removes now-unreferenced lookup rows that load-final.sql can create
  and drops the disposable staging schema.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'School'
    THROW 51410, 'Part 14 cleanup must run in the School database.', 1;

IF OBJECT_ID(N'dbo.BookingRequest', N'U') IS NULL
   OR OBJECT_ID(N'dbo.[User]', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Space', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Maintenance', N'U') IS NULL
    THROW 51411, 'The final G06 schema is missing required tables.', 1;

DECLARE @deleted TABLE
(
    delete_order INT NOT NULL,
    table_name SYSNAME NOT NULL,
    deleted_rows BIGINT NOT NULL
);
DECLARE @row_count BIGINT;

BEGIN TRANSACTION;
BEGIN TRY
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Facility f
        WHERE f.space_id BETWEEN 'S0001' AND 'S0100'
    )
        THROW 51412,
              'A generated space is referenced by Facility; cleanup stopped to preserve non-Part-14 data.',
              1;

    DELETE rs
    FROM dbo.ReservationSession rs
    INNER JOIN dbo.Reservation r ON r.reservation_id = rs.reservation_id
    WHERE r.booking_request_id BETWEEN '10000001' AND '10500000';
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (10, N'dbo.ReservationSession', @row_count);

    DELETE r
    FROM dbo.Reservation r
    WHERE r.booking_request_id BETWEEN '10000001' AND '10500000';
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (20, N'dbo.Reservation', @row_count);

    DELETE r
    FROM dbo.Review r
    WHERE r.booking_request_id BETWEEN '10000001' AND '10500000';
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (30, N'dbo.Review', @row_count);

    DELETE br
    FROM dbo.BookingRequest br
    WHERE br.booking_request_id BETWEEN '10000001' AND '10500000';
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (40, N'dbo.BookingRequest', @row_count);

    DELETE ms
    FROM dbo.MaintenanceSession ms
    WHERE ms.maintenance_id BETWEEN 'm00001' AND 'm02500';
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (50, N'dbo.MaintenanceSession', @row_count);

    DELETE m
    FROM dbo.Maintenance m
    WHERE m.maintenance_id BETWEEN 'm00001' AND 'm02500';
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (60, N'dbo.Maintenance', @row_count);

    DELETE s
    FROM dbo.Space s
    WHERE s.space_id BETWEEN 'S0001' AND 'S0100';
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (70, N'dbo.Space', @row_count);

    DELETE u
    FROM dbo.[User] u
    WHERE u.user_id BETWEEN '80000001' AND '80010000';
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (80, N'dbo.User', @row_count);

    /* Policies may be shared by migrated Phase 1 spaces, so delete only orphans. */
    DELETE p
    FROM dbo.SpacePolicy p
    WHERE p.space_policy_id IN ('DYWGI', 'HKBSL', 'NCYTN', 'QFJJO')
      AND NOT EXISTS
          (SELECT 1 FROM dbo.Space s WHERE s.space_policy_id = p.space_policy_id);
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (90, N'dbo.SpacePolicy (unreferenced)', @row_count);

    DELETE d
    FROM lookup_table.Department d
    WHERE d.department_code IN ('D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08')
      AND d.department_name LIKE N'Synthetic Department%'
      AND NOT EXISTS
          (SELECT 1 FROM dbo.[User] u WHERE u.department_id = d.department_id);
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (100, N'lookup_table.Department (unreferenced)', @row_count);

    DELETE p
    FROM lookup_table.Purpose p
    WHERE p.purpose_code IN ('TEACHING', 'MEETING', 'STUDY', 'EVENT', 'RESEARCH')
      AND NOT EXISTS
          (SELECT 1 FROM dbo.BookingRequest br WHERE br.purpose_id = p.purpose_id);
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (110, N'lookup_table.Purpose (unreferenced)', @row_count);

    DELETE ms
    FROM lookup_table.MaintenanceStatus ms
    WHERE ms.maintenance_status_code = 'OPEN'
      AND ms.maintenance_status_name = N'Open'
      AND NOT EXISTS
          (SELECT 1 FROM dbo.Maintenance m WHERE m.maintenance_status_id = ms.maintenance_status_id);
    SET @row_count = @@ROWCOUNT;
    INSERT @deleted VALUES (120, N'lookup_table.MaintenanceStatus (unreferenced)', @row_count);

    IF EXISTS
       (SELECT 1 FROM dbo.BookingRequest WHERE booking_request_id BETWEEN '10000001' AND '10500000')
       OR EXISTS
       (SELECT 1 FROM dbo.Maintenance WHERE maintenance_id BETWEEN 'm00001' AND 'm02500')
       OR EXISTS
       (SELECT 1 FROM dbo.Space WHERE space_id BETWEEN 'S0001' AND 'S0100')
       OR EXISTS
       (SELECT 1 FROM dbo.[User] WHERE user_id BETWEEN '80000001' AND '80010000')
        THROW 51413, 'Part 14 production rows remain; cleanup was rolled back.', 1;

    DROP TABLE IF EXISTS staging_phase2.Reservations;
    DROP TABLE IF EXISTS staging_phase2.Reviews;
    DROP TABLE IF EXISTS staging_phase2.Bookings;
    DROP TABLE IF EXISTS staging_phase2.BookingRequests;
    DROP TABLE IF EXISTS staging_phase2.Maintenance;
    DROP TABLE IF EXISTS staging_phase2.Spaces;
    DROP TABLE IF EXISTS staging_phase2.Users;

    IF SCHEMA_ID(N'staging_phase2') IS NOT NULL
        EXEC(N'DROP SCHEMA staging_phase2');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT table_name, deleted_rows
FROM @deleted
ORDER BY delete_order;

SELECT SUM(deleted_rows) AS total_production_and_lookup_rows_deleted
FROM @deleted;

SELECT N'valid' AS cleanup_validation,
       (SELECT COUNT_BIG(*) FROM dbo.BookingRequest
        WHERE booking_request_id BETWEEN '10000001' AND '10500000') AS generated_booking_requests_remaining,
       (SELECT COUNT_BIG(*) FROM dbo.Maintenance
        WHERE maintenance_id BETWEEN 'm00001' AND 'm02500') AS generated_maintenance_remaining,
       (SELECT COUNT_BIG(*) FROM dbo.Space
        WHERE space_id BETWEEN 'S0001' AND 'S0100') AS generated_spaces_remaining,
       (SELECT COUNT_BIG(*) FROM dbo.[User]
        WHERE user_id BETWEEN '80000001' AND '80010000') AS generated_users_remaining;
GO
