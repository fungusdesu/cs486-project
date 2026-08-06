USE [School];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF @@TRANCOUNT > 0
BEGIN
    THROW 50000,
        'Only run this migration with no pre-existing transaction in the current session.',
        1;
END;

BEGIN TRANSACTION;
GO
------------------------------
-- 0. validate existing data
------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;
    -- 0.1. drop existing procedures
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateLegacyBooking;
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateLegacyMaintaining;
    DROP PROCEDURE IF EXISTS dbo.__mig_BackfillBookingRelationships;
    DROP PROCEDURE IF EXISTS dbo.__mig_BackfillMaintenanceRelationships;
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateBookingCopy;
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateMaintenanceCopy;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
    -- 0.2. validate Booking and Maintaining
CREATE PROCEDURE dbo.__mig_ValidateLegacyBooking
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT b.booking_request_id
        FROM junction_table.Booking AS b
        GROUP BY b.booking_request_id
        HAVING COUNT(*) <> 1
    )
    BEGIN
        THROW 50011,
            'Each booking request must have exactly one Booking row before migration.',
            1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.BookingRequest AS br
        LEFT JOIN junction_table.Booking AS b
            ON b.booking_request_id = br.booking_request_id
        WHERE b.booking_request_id IS NULL
    )
    BEGIN
        THROW 50012,
            'A BookingRequest without a Booking relationship cannot be migrated.',
            1;
    END;
END;
GO

CREATE PROCEDURE dbo.__mig_ValidateLegacyMaintaining
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT mt.maintenance_id
        FROM junction_table.Maintaining AS mt
        GROUP BY mt.maintenance_id
        HAVING COUNT(*) <> 1
    )
    BEGIN
        THROW 50013,
            'Each maintenance record must have exactly one Maintaining row before migration.',
            1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance AS m
        LEFT JOIN junction_table.Maintaining AS mt
            ON mt.maintenance_id = m.maintenance_id
        WHERE mt.maintenance_id IS NULL
    )
    BEGIN
        THROW 50014,
            'A Maintenance row without a Maintaining relationship cannot be migrated.',
            1;
    END;

END;
GO

BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.Booking', N'U') IS NOT NULL
        EXEC dbo.__mig_ValidateLegacyBooking;
    ELSE IF COL_LENGTH(N'dbo.BookingRequest', N'user_id') IS NULL
         OR COL_LENGTH(N'dbo.BookingRequest', N'space_id') IS NULL
        THROW 50016,
            'Booking is absent and the replacement BookingRequest columns are incomplete.',
            1;

    IF OBJECT_ID(N'junction_table.Maintaining', N'U') IS NOT NULL
        EXEC dbo.__mig_ValidateLegacyMaintaining;
    ELSE IF COL_LENGTH(N'dbo.Maintenance', N'technician_id') IS NULL
         OR COL_LENGTH(N'dbo.Maintenance', N'space_id') IS NULL
         OR COL_LENGTH(N'dbo.Maintenance', N'maintenance_start_time') IS NULL
         OR COL_LENGTH(N'dbo.Maintenance', N'maintenance_end_time') IS NULL
        THROW 50017,
            'Maintaining is absent and the replacement Maintenance columns are incomplete.',
            1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

    -- 0.3. drop triggers
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    DROP TRIGGER IF EXISTS dbo.trg_booking_request_capacity;
    DROP TRIGGER IF EXISTS dbo.trg_booker_acc_status;
    DROP TRIGGER IF EXISTS dbo.trg_booking_requested_time_fit_policy;
    DROP TRIGGER IF EXISTS dbo.trg_booking_maintenance_eligibility;
    DROP TRIGGER IF EXISTS dbo.trg_maintenance_result_note;
    DROP TRIGGER IF EXISTS dbo.trg_space_maintenance_status;
    DROP TRIGGER IF EXISTS dbo.trg_checked_in_space_in_use;

    DROP TRIGGER IF EXISTS junction_table.trg_no_overlapping_approved_requests;
    DROP TRIGGER IF EXISTS junction_table.trg_no_approved_review_during_maintaining;
    DROP TRIGGER IF EXISTS dbo.trg_no_overlapping_approved_requests;
    DROP TRIGGER IF EXISTS dbo.trg_no_approved_review_during_maintaining;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- ==========================================================================
-- BUSINESS REQUIREMENTS UPDATE FROM 08
-- ===========================================================================

------------------------------------------------
-- A1. Add MaintenanceImpactLevel
------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'lookup_table.MaintenanceImpactLevel', N'U') IS NULL
    BEGIN
        CREATE TABLE lookup_table.MaintenanceImpactLevel
        (
            maintenance_impact_level_id TINYINT IDENTITY(1, 1) NOT NULL,
            maintenance_impact_level_code VARCHAR(20) NOT NULL,
            maintenance_impact_level_name NVARCHAR(50) NOT NULL,

            CONSTRAINT PK_MaintenanceImpactLevel_maintenance_impact_level_id
                PRIMARY KEY (maintenance_impact_level_id),
            CONSTRAINT UK_MaintenanceImpactLevel_code
                UNIQUE (maintenance_impact_level_code),
            CONSTRAINT CHK_MaintenanceImpactLevel_code_uppercase
                CHECK
                (
                    maintenance_impact_level_code COLLATE Latin1_General_100_BIN2
                        = UPPER(maintenance_impact_level_code)
                            COLLATE Latin1_General_100_BIN2
                )
        );
    END;
    -- check before insert
    UPDATE lookup_table.MaintenanceImpactLevel
    SET maintenance_impact_level_name = N'Advisory'
    WHERE maintenance_impact_level_code = 'ADVISORY';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO lookup_table.MaintenanceImpactLevel
        (
            maintenance_impact_level_code,
            maintenance_impact_level_name
        )
        VALUES ('ADVISORY', N'Advisory');
    END;

    UPDATE lookup_table.MaintenanceImpactLevel
    SET maintenance_impact_level_name = N'Out-of-Service'
    WHERE maintenance_impact_level_code = 'OUT_OF_SERVICE';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO lookup_table.MaintenanceImpactLevel
        (
            maintenance_impact_level_code,
            maintenance_impact_level_name
        )
        VALUES ('OUT_OF_SERVICE', N'Out-of-Service');
    END;

    IF COL_LENGTH(N'dbo.Maintenance', N'maintenance_impact_level_id') IS NULL
    BEGIN
        ALTER TABLE dbo.Maintenance
        ADD maintenance_impact_level_id TINYINT NULL;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

----------------------------------------------------------
-- A2. Add maintenance_impact_level_id to Maintenance
----------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    DECLARE @out_of_service_id TINYINT;

    SELECT @out_of_service_id = maintenance_impact_level_id
    FROM lookup_table.MaintenanceImpactLevel
    WHERE maintenance_impact_level_code = 'OUT_OF_SERVICE';

    IF @out_of_service_id IS NULL
        THROW 50019, 'OUT_OF_SERVICE impact level is missing.', 1;

    UPDATE dbo.Maintenance
    SET maintenance_impact_level_id = @out_of_service_id
    WHERE maintenance_impact_level_id IS NULL;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance
        WHERE maintenance_impact_level_id IS NULL
    )
        THROW 50022, 'Maintenance impact-level backfill failed.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'maintenance_impact_level_id'
          AND is_nullable = 1
    )
    BEGIN
        ALTER TABLE dbo.Maintenance
        ALTER COLUMN maintenance_impact_level_id TINYINT NOT NULL;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'FK_MaintenanceImpactLevel_id'
    )
    BEGIN
        ALTER TABLE dbo.Maintenance WITH CHECK
        ADD CONSTRAINT FK_MaintenanceImpactLevel_id
            FOREIGN KEY (maintenance_impact_level_id)
            REFERENCES lookup_table.MaintenanceImpactLevel
                       (maintenance_impact_level_id);
    END;

    ALTER TABLE dbo.Maintenance WITH CHECK
    CHECK CONSTRAINT FK_MaintenanceImpactLevel_id;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

------------------------------------------------------------------------------
-- A3. Add advisory acknowledgement and instant-booking policy
------------------------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    IF COL_LENGTH(N'dbo.BookingRequest', N'advisory_acknowledged') IS NULL
    BEGIN
        ALTER TABLE dbo.BookingRequest
        ADD advisory_acknowledged BIT NULL;
    END;

    IF COL_LENGTH(N'dbo.SpacePolicy', N'requires_approval') IS NULL
    BEGIN
        ALTER TABLE dbo.SpacePolicy
        ADD requires_approval BIT NULL;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    UPDATE dbo.BookingRequest
    SET advisory_acknowledged = 0
    WHERE advisory_acknowledged IS NULL;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'advisory_acknowledged'
          AND is_nullable = 1
    )
    BEGIN
        ALTER TABLE dbo.BookingRequest
        ALTER COLUMN advisory_acknowledged BIT NOT NULL;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints AS dc
        INNER JOIN sys.columns AS c
            ON c.object_id = dc.parent_object_id
           AND c.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND c.name = N'advisory_acknowledged'
    )
    BEGIN
        ALTER TABLE dbo.BookingRequest
        ADD CONSTRAINT DF_BookingRequest_advisory_acknowledged
            DEFAULT (0) FOR advisory_acknowledged;
    END;

    UPDATE dbo.SpacePolicy
    SET requires_approval = 1
    WHERE requires_approval IS NULL;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.SpacePolicy')
          AND name = N'requires_approval'
          AND is_nullable = 1
    )
    BEGIN
        ALTER TABLE dbo.SpacePolicy
        ALTER COLUMN requires_approval BIT NOT NULL;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints AS dc
        INNER JOIN sys.columns AS c
            ON c.object_id = dc.parent_object_id
           AND c.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.SpacePolicy')
          AND c.name = N'requires_approval'
    )
    BEGIN
        ALTER TABLE dbo.SpacePolicy
        ADD CONSTRAINT DF_SpacePolicy_requires_approval
            DEFAULT (1) FOR requires_approval;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

---------------------------------------------------------------------------
-- A4. Concurrent maintenance windows require no schema migration
---------------------------------------------------------------------------
-- 08 explicitly allows several active maintenance records for one space,
-- including overlapping maintenance intervals. Neither the original
-- junction_table.Maintaining table nor the migrated dbo.Maintenance columns
-- impose a uniqueness rule on (space_id, maintenance_start_time,
-- maintenance_end_time), so no additional schema operation is required.
GO

-- ===========================================================================
-- SECOND VALIDATION FROM 08 — ORDER PRESERVED
-- ===========================================================================

------------------------------------------------------------
-- B1. phone_number is no longer unique
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.[User]')
          AND name = N'UK_User_phone_number'
    )
    BEGIN
        ALTER TABLE dbo.[User]
        DROP CONSTRAINT UK_User_phone_number;
    END;

    -- This second guard handles a standalone unique index with the same name.
    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.[User]')
          AND name = N'UK_User_phone_number'
          AND is_unique = 1
    )
    BEGIN
        DROP INDEX UK_User_phone_number ON dbo.[User];
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

---------------------------------------------------------------------------
-- B2. Decompose Booking and Maintaining into direct foreign-key attributes
---------------------------------------------------------------------------

-- B2.1. Add the destination columns first.
-- GO is required before later batches compile references to these columns.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    IF COL_LENGTH(N'dbo.BookingRequest', N'user_id') IS NULL
    BEGIN
        ALTER TABLE dbo.BookingRequest
        ADD user_id VARCHAR(8) NULL;
    END;

    IF COL_LENGTH(N'dbo.BookingRequest', N'space_id') IS NULL
    BEGIN
        ALTER TABLE dbo.BookingRequest
        ADD space_id VARCHAR(10) NULL;
    END;

    IF COL_LENGTH(N'dbo.Maintenance', N'technician_id') IS NULL
    BEGIN
        ALTER TABLE dbo.Maintenance
        ADD technician_id VARCHAR(8) NULL;
    END;

    IF COL_LENGTH(N'dbo.Maintenance', N'space_id') IS NULL
    BEGIN
        ALTER TABLE dbo.Maintenance
        ADD space_id VARCHAR(10) NULL;
    END;

    IF COL_LENGTH(N'dbo.Maintenance', N'maintenance_start_time') IS NULL
    BEGIN
        ALTER TABLE dbo.Maintenance
        ADD maintenance_start_time DATETIME NULL;
    END;

    IF COL_LENGTH(N'dbo.Maintenance', N'maintenance_end_time') IS NULL
    BEGIN
        ALTER TABLE dbo.Maintenance
        ADD maintenance_end_time DATETIME NULL;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- B2.2. Create temporary backfill procedures
CREATE OR ALTER PROCEDURE dbo.__mig_BackfillBookingRelationships
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.BookingRequest AS br
        INNER JOIN junction_table.Booking AS b
            ON b.booking_request_id = br.booking_request_id
        WHERE (br.user_id IS NOT NULL AND br.user_id <> b.user_id)
           OR (br.space_id IS NOT NULL AND br.space_id <> b.space_id)
    )
    BEGIN
        THROW 50020,
            'Existing BookingRequest values conflict with junction_table.Booking.',
            1;
    END;

    UPDATE br
    SET br.user_id = b.user_id,
        br.space_id = b.space_id
    FROM dbo.BookingRequest AS br
    INNER JOIN junction_table.Booking AS b
        ON b.booking_request_id = br.booking_request_id;
END;
GO


CREATE OR ALTER PROCEDURE dbo.__mig_BackfillMaintenanceRelationships
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance AS m
        INNER JOIN junction_table.Maintaining AS mt
            ON mt.maintenance_id = m.maintenance_id
        WHERE (m.technician_id IS NOT NULL
               AND m.technician_id <> mt.technician_id)
           OR (m.space_id IS NOT NULL AND m.space_id <> mt.space_id)
           OR (m.maintenance_start_time IS NOT NULL
               AND m.maintenance_start_time <> mt.maintenance_start_time)
           OR
           (
            -- Compare nullable end times by mapping NULL to a sentinel value.
               m.maintenance_end_time IS NOT NULL
               AND ISNULL(m.maintenance_end_time, CONVERT(DATETIME, '19000101', 112))
                   <> ISNULL(mt.maintenance_end_time, CONVERT(DATETIME, '19000101', 112))
           )
    )
    BEGIN
        THROW 50021,
            'Existing Maintenance values conflict with junction_table.Maintaining.',
            1;
    END;

    UPDATE m
    SET m.technician_id = mt.technician_id,
        m.space_id = mt.space_id,
        m.maintenance_start_time = mt.maintenance_start_time,
        m.maintenance_end_time = mt.maintenance_end_time
    FROM dbo.Maintenance AS m
    INNER JOIN junction_table.Maintaining AS mt
        ON mt.maintenance_id = m.maintenance_id;
END;
GO

-- B2.3. Create temporary copy-validation procedures
CREATE OR ALTER PROCEDURE dbo.__mig_ValidateBookingCopy
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.BookingRequest AS br
        INNER JOIN junction_table.Booking AS b
            ON b.booking_request_id = br.booking_request_id
        WHERE br.user_id <> b.user_id
           OR br.space_id <> b.space_id
    )
    BEGIN
        THROW 50025, 'Booking data changed during decomposition.', 1;
    END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.__mig_ValidateMaintenanceCopy
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance AS m
        INNER JOIN junction_table.Maintaining AS mt
            ON mt.maintenance_id = m.maintenance_id
        WHERE m.technician_id <> mt.technician_id
           OR m.space_id <> mt.space_id
           OR m.maintenance_start_time <> mt.maintenance_start_time
           OR ISNULL(m.maintenance_end_time, CONVERT(DATETIME, '19000101', 112))
              <> ISNULL(mt.maintenance_end_time, CONVERT(DATETIME, '19000101', 112))
    )
    BEGIN
        THROW 50026, 'Maintenance data changed during decomposition.', 1;
    END;
END;
GO

-- B2.4. Backfill, enforce NOT NULL, and add foreign keys
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.Booking', N'U') IS NOT NULL
        EXEC dbo.__mig_BackfillBookingRelationships;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.BookingRequest
        WHERE user_id IS NULL OR space_id IS NULL
    )
        THROW 50023, 'Booking relationship backfill failed.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'user_id'
          AND is_nullable = 1
    )
        ALTER TABLE dbo.BookingRequest ALTER COLUMN user_id VARCHAR(8) NOT NULL;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'space_id'
          AND is_nullable = 1
    )
        ALTER TABLE dbo.BookingRequest ALTER COLUMN space_id VARCHAR(10) NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'FK_BookingRequest_user'
    )
    BEGIN
        ALTER TABLE dbo.BookingRequest WITH CHECK
        ADD CONSTRAINT FK_BookingRequest_user
            FOREIGN KEY (user_id) REFERENCES dbo.[User](user_id);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'FK_BookingRequest_space'
    )
    BEGIN
        ALTER TABLE dbo.BookingRequest WITH CHECK
        ADD CONSTRAINT FK_BookingRequest_space
            FOREIGN KEY (space_id) REFERENCES dbo.Space(space_id);
    END;

    ALTER TABLE dbo.BookingRequest WITH CHECK
    CHECK CONSTRAINT FK_BookingRequest_user;

    ALTER TABLE dbo.BookingRequest WITH CHECK
    CHECK CONSTRAINT FK_BookingRequest_space;

    IF OBJECT_ID(N'junction_table.Maintaining', N'U') IS NOT NULL
        EXEC dbo.__mig_BackfillMaintenanceRelationships;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance
        WHERE technician_id IS NULL
           OR space_id IS NULL
           OR maintenance_start_time IS NULL
    )
        THROW 50024, 'Maintaining relationship backfill failed.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance
        WHERE maintenance_end_time IS NOT NULL
          AND maintenance_end_time <= maintenance_start_time
    )
        THROW 50027,
            'Maintenance end time must be later than its start time.',
            1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'technician_id'
          AND is_nullable = 1
    )
        ALTER TABLE dbo.Maintenance ALTER COLUMN technician_id VARCHAR(8) NOT NULL;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'space_id'
          AND is_nullable = 1
    )
        ALTER TABLE dbo.Maintenance ALTER COLUMN space_id VARCHAR(10) NOT NULL;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'maintenance_start_time'
          AND is_nullable = 1
    )
        ALTER TABLE dbo.Maintenance
        ALTER COLUMN maintenance_start_time DATETIME NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'FK_Maintenance_technician'
    )
    BEGIN
        ALTER TABLE dbo.Maintenance WITH CHECK
        ADD CONSTRAINT FK_Maintenance_technician
            FOREIGN KEY (technician_id) REFERENCES dbo.[User](user_id);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'FK_Maintenance_space'
    )
    BEGIN
        ALTER TABLE dbo.Maintenance WITH CHECK
        ADD CONSTRAINT FK_Maintenance_space
            FOREIGN KEY (space_id) REFERENCES dbo.Space(space_id);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'CHK_Maintenance_time_order'
    )
    BEGIN
        ALTER TABLE dbo.Maintenance WITH CHECK
        ADD CONSTRAINT CHK_Maintenance_time_order
            CHECK
            (
                maintenance_end_time IS NULL
                OR maintenance_end_time > maintenance_start_time
            );
    END;

    ALTER TABLE dbo.Maintenance WITH CHECK
    CHECK CONSTRAINT FK_Maintenance_technician;

    ALTER TABLE dbo.Maintenance WITH CHECK
    CHECK CONSTRAINT FK_Maintenance_space;

    ALTER TABLE dbo.Maintenance WITH CHECK
    CHECK CONSTRAINT CHK_Maintenance_time_order;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- B2.5. Validate copied values, then remove the redundant junction tables
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.Booking', N'U') IS NOT NULL
        EXEC dbo.__mig_ValidateBookingCopy;

    IF OBJECT_ID(N'junction_table.Maintaining', N'U') IS NOT NULL
        EXEC dbo.__mig_ValidateMaintenanceCopy;

    DROP TABLE IF EXISTS junction_table.Booking;
    DROP TABLE IF EXISTS junction_table.Maintaining;

    -- Remove temporary migration procedures.
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateLegacyBooking;
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateLegacyMaintaining;
    DROP PROCEDURE IF EXISTS dbo.__mig_BackfillBookingRelationships;
    DROP PROCEDURE IF EXISTS dbo.__mig_BackfillMaintenanceRelationships;
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateBookingCopy;
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateMaintenanceCopy;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

---------------------------------------------------------------------------
-- B3. Decision decomposition described in 08: NOT IMPLEMENTED IN THIS FILE
---------------------------------------------------------------------------
-- 08 requires lookup_table.Decision to be decomposed into:
--   1. lookup_table.RequestState: PENDING, REVIEWED, CANCELED
--   2. lookup_table.RequestDecision: APPROVED, REJECTED
-- It also requires BookingRequest.request_state_id and a repurposed
-- Review.request_decision_id.
--
-- This migration still keeps lookup_table.Decision and Review.decision_id.
-- Therefore, the Decision decomposition is intentionally documented here
-- as missing rather than silently implying that it has been migrated.
GO

---------------------------------------------------------------------------
-- B4. Review history redesign described in 08: NOT IMPLEMENTED IN THIS FILE
---------------------------------------------------------------------------
-- 08 requires Review to:
--   * become an operational table;
--   * receive review_id CHAR(9) as a surrogate primary key;
--   * enforce the lowercase alphanumeric format xxxx-xxxx;
--   * allow multiple reviews for one booking request;
--   * retain booking_request_id and reviewer_id as N:1 relationships.
--
-- This migration still uses junction_table.Review with booking_request_id
-- as its primary key, so one booking request can still have only one row.
GO

---------------------------------------------------------------------------
-- B5. VARCHAR-to-CHAR identifier conversion: NOT IMPLEMENTED IN THIS FILE
---------------------------------------------------------------------------
-- 08 requires these identifiers to use CHAR rather than VARCHAR:
--   user_id, booking_request_id, review_id, reservation_id,
--   maintenance_id, and space_policy_id.
--
-- Converting them safely requires dropping and recreating every dependent
-- primary key, foreign key, and check constraint. This migration leaves the
-- existing identifier data types unchanged.
GO

---------------------------------------------------------------------------
-- B6. ReservationCheckin redesign described in 08: NOT IMPLEMENTED HERE
---------------------------------------------------------------------------
-- 08 requires junction_table.ReservationCheckin to become the operational
-- table dbo.ReservationSession, with reservation_id as its key and direct
-- relationships for attendant_id, check_in_user_id, and Reservation.
--
-- This migration leaves junction_table.ReservationCheckin unchanged.
GO

------------------------------------------------------------
-- B7. Add the management-side canceled reservation status
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM lookup_table.ReservationStatus
        WHERE reservation_status_code = 'CAN'
    )
    BEGIN
        UPDATE lookup_table.ReservationStatus
        SET reservation_status_name = N'Canceled'
        WHERE reservation_status_code = 'CAN';
    END
    ELSE
    BEGIN
        INSERT INTO lookup_table.ReservationStatus
        (
            reservation_status_code,
            reservation_status_name
        )
        VALUES ('CAN', N'Canceled');
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

------------------------------------------------------
-- C. Recreate triggers for the implemented final schema
------------------------------------------------------
-- The Review/Decision triggers below intentionally target the legacy
-- junction_table.Review and lookup_table.Decision because B3 and B4
-- are documented as not implemented in this migration.
CREATE OR ALTER TRIGGER dbo.trg_booking_request_capacity
ON dbo.BookingRequest
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Space AS s
            ON s.space_id = i.space_id
        WHERE i.expected_participants > s.capacity
    )
    BEGIN
        THROW 51001,
            'Expected participants cannot exceed the space capacity.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_booker_acc_status
ON dbo.BookingRequest
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.[User] AS u
            ON u.user_id = i.user_id
        INNER JOIN lookup_table.UserStatus AS us
            ON us.user_status_id = u.user_status_id
        WHERE us.user_status_code <> 'ACTIVE'
    )
    BEGIN
        THROW 51002,
            'Only a user with an active account can book a space.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_booking_requested_time_fit_policy
ON dbo.BookingRequest
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Space AS s
            ON s.space_id = i.space_id
        INNER JOIN dbo.SpacePolicy AS sp
            ON sp.space_policy_id = s.space_policy_id
        WHERE DATEDIFF
              (
                  MINUTE,
                  i.requested_start_time,
                  i.requested_end_time
              ) NOT BETWEEN sp.min_duration_minutes
                        AND sp.max_duration_minutes
    )
    BEGIN
        THROW 51003,
            'Requested duration violates the selected space policy.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_booking_maintenance_eligibility
ON dbo.BookingRequest
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Maintenance AS m
            ON m.space_id = i.space_id
        INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
            ON mil.maintenance_impact_level_id
               = m.maintenance_impact_level_id
        WHERE i.requested_start_time
                < ISNULL
                  (
                      m.maintenance_end_time,
                      CONVERT(DATETIME, '99991231', 112)
                  )
          AND i.requested_end_time > m.maintenance_start_time
          AND mil.maintenance_impact_level_code = 'OUT_OF_SERVICE'
    )
    BEGIN
        THROW 51004,
            'The space is out of service during the requested time.',
            1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Maintenance AS m
            ON m.space_id = i.space_id
        INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
            ON mil.maintenance_impact_level_id
               = m.maintenance_impact_level_id
        WHERE i.requested_start_time
                < ISNULL
                  (
                      m.maintenance_end_time,
                      CONVERT(DATETIME, '99991231', 112)
                  )
          AND i.requested_end_time > m.maintenance_start_time
          AND mil.maintenance_impact_level_code = 'ADVISORY'
          AND i.advisory_acknowledged = 0
    )
    BEGIN
        THROW 51005,
            'Advisory maintenance must be acknowledged before booking.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_maintenance_result_note
ON dbo.Maintenance
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN lookup_table.MaintenanceStatus AS ms
            ON ms.maintenance_status_id = i.maintenance_status_id
        WHERE (i.result_note IS NOT NULL
               OR i.maintenance_end_time IS NOT NULL)
          AND ms.maintenance_status_code <> 'COMPLETED'
    )
    BEGIN
        THROW 51006,
            'A result note or end time requires completed maintenance.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_space_maintenance_status
ON dbo.Space
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Maintenance AS m
            ON m.space_id = i.space_id
        INNER JOIN lookup_table.MaintenanceStatus AS ms
            ON ms.maintenance_status_id = m.maintenance_status_id
        INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
            ON mil.maintenance_impact_level_id
               = m.maintenance_impact_level_id
        INNER JOIN lookup_table.SpaceStatus AS ss
            ON ss.space_status_id = i.space_status_id
        WHERE ms.maintenance_status_code <> 'COMPLETED'
          AND mil.maintenance_impact_level_code = 'OUT_OF_SERVICE'
          AND ss.space_status_code <> 'UNDER_MAINTENANCE'
    )
    BEGIN
        THROW 51007,
            'Out-of-service maintenance requires under-maintenance space status.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_checked_in_space_in_use
ON dbo.Reservation
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.BookingRequest AS br
            ON br.booking_request_id = i.booking_request_id
        INNER JOIN dbo.Space AS s
            ON s.space_id = br.space_id
        INNER JOIN lookup_table.ReservationStatus AS rs
            ON rs.reservation_status_id = i.reservation_status_id
        INNER JOIN lookup_table.SpaceStatus AS ss
            ON ss.space_status_id = s.space_status_id
        WHERE rs.reservation_status_code = 'CHECKED_IN'
          AND ss.space_status_code <> 'IN_USE'
    )
    BEGIN
        THROW 51008,
            'A checked-in reservation requires in-use space status.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER junction_table.trg_no_overlapping_approved_requests
ON junction_table.Review
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN lookup_table.Decision AS d1
            ON d1.decision_id = i.decision_id
        INNER JOIN dbo.BookingRequest AS br1
            ON br1.booking_request_id = i.booking_request_id
        INNER JOIN dbo.BookingRequest AS br2
            ON br2.space_id = br1.space_id
           AND br2.booking_request_id <> br1.booking_request_id
        INNER JOIN junction_table.Review AS r2
            ON r2.booking_request_id = br2.booking_request_id
        INNER JOIN lookup_table.Decision AS d2
            ON d2.decision_id = r2.decision_id
        WHERE d1.decision_code = 'APPROVED'
          AND d2.decision_code = 'APPROVED'
          AND br1.requested_start_time < br2.requested_end_time
          AND br1.requested_end_time > br2.requested_start_time
    )
    BEGIN
        THROW 51009,
            'Two approved requests for one space cannot overlap.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER junction_table.trg_no_approved_review_during_maintaining
ON junction_table.Review
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN lookup_table.Decision AS d
            ON d.decision_id = i.decision_id
        INNER JOIN dbo.BookingRequest AS br
            ON br.booking_request_id = i.booking_request_id
        INNER JOIN dbo.Maintenance AS m
            ON m.space_id = br.space_id
        INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
            ON mil.maintenance_impact_level_id
               = m.maintenance_impact_level_id
        WHERE d.decision_code = 'APPROVED'
          AND mil.maintenance_impact_level_code = 'OUT_OF_SERVICE'
          AND br.requested_start_time
                < ISNULL
                  (
                      m.maintenance_end_time,
                      CONVERT(DATETIME, '99991231', 112)
                  )
          AND br.requested_end_time > m.maintenance_start_time
    )
    BEGIN
        THROW 51010,
            'A request cannot be approved during out-of-service maintenance.',
            1;
    END;
END;
GO


------------------------------------------------------------
-- D. Final validation and commit
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50090, 'Migration transaction is not active.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.BookingRequest
        WHERE user_id IS NULL
           OR space_id IS NULL
           OR advisory_acknowledged IS NULL
    )
        THROW 50030, 'Final BookingRequest validation failed.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance
        WHERE technician_id IS NULL
           OR space_id IS NULL
           OR maintenance_start_time IS NULL
           OR maintenance_impact_level_id IS NULL
    )
        THROW 50031, 'Final Maintenance validation failed.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.SpacePolicy
        WHERE requires_approval IS NULL
    )
        THROW 50032, 'Final SpacePolicy validation failed.', 1;

    IF OBJECT_ID(N'junction_table.Booking', N'U') IS NOT NULL
        THROW 50033, 'Legacy table junction_table.Booking still exists.', 1;

    IF OBJECT_ID(N'junction_table.Maintaining', N'U') IS NOT NULL
        THROW 50034, 'Legacy table junction_table.Maintaining still exists.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.[User]')
          AND name = N'UK_User_phone_number'
    )
        THROW 50035, 'phone_number is still constrained as unique.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.MaintenanceImpactLevel
        WHERE maintenance_impact_level_code = 'ADVISORY'
    )
        THROW 50036, 'ADVISORY impact level is missing.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.MaintenanceImpactLevel
        WHERE maintenance_impact_level_code = 'OUT_OF_SERVICE'
    )
        THROW 50037, 'OUT_OF_SERVICE impact level is missing.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.ReservationStatus
        WHERE reservation_status_code = 'CAN'
    )
        THROW 50038, 'Canceled reservation status is missing.', 1;

    IF OBJECT_ID(N'dbo.trg_booking_request_capacity', N'TR') IS NULL
        THROW 50039, 'trg_booking_request_capacity was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_booker_acc_status', N'TR') IS NULL
        THROW 50040, 'trg_booker_acc_status was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_booking_requested_time_fit_policy', N'TR') IS NULL
        THROW 50041, 'trg_booking_requested_time_fit_policy was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_booking_maintenance_eligibility', N'TR') IS NULL
        THROW 50042, 'trg_booking_maintenance_eligibility was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_maintenance_result_note', N'TR') IS NULL
        THROW 50043, 'trg_maintenance_result_note was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_space_maintenance_status', N'TR') IS NULL
        THROW 50044, 'trg_space_maintenance_status was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_checked_in_space_in_use', N'TR') IS NULL
        THROW 50045, 'trg_checked_in_space_in_use was not created.', 1;

    IF OBJECT_ID(
           N'junction_table.trg_no_overlapping_approved_requests',
           N'TR'
       ) IS NULL
        THROW 50046,
            'trg_no_overlapping_approved_requests was not created.',
            1;

    IF OBJECT_ID(
           N'junction_table.trg_no_approved_review_during_maintaining',
           N'TR'
       ) IS NULL
        THROW 50047,
            'trg_no_approved_review_during_maintaining was not created.',
            1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
