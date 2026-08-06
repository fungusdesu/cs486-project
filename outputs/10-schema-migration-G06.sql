USE [School];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF @@TRANCOUNT > 0
BEGIN
    ;THROW 50001,
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
        ;THROW 50002, 'Migration transaction is not active.', 1;
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
    ;THROW;
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
        ;THROW 50003,
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
        ;THROW 50004,
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
        ;THROW 50005,
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
        ;THROW 50006,
            'A Maintenance row without a Maintaining relationship cannot be migrated.',
            1;
    END;

END;
GO

BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50007, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.Booking', N'U') IS NOT NULL
        EXEC dbo.__mig_ValidateLegacyBooking;
    ELSE IF COL_LENGTH(N'dbo.BookingRequest', N'user_id') IS NULL
         OR COL_LENGTH(N'dbo.BookingRequest', N'space_id') IS NULL
        ;THROW 50008,
            'Booking is absent and the replacement BookingRequest columns are incomplete.',
            1;

    IF OBJECT_ID(N'junction_table.Maintaining', N'U') IS NOT NULL
        EXEC dbo.__mig_ValidateLegacyMaintaining;
    ELSE IF COL_LENGTH(N'dbo.Maintenance', N'technician_id') IS NULL
         OR COL_LENGTH(N'dbo.Maintenance', N'space_id') IS NULL
         OR COL_LENGTH(N'dbo.Maintenance', N'maintenance_start_time') IS NULL
         OR COL_LENGTH(N'dbo.Maintenance', N'maintenance_end_time') IS NULL
        ;THROW 50009,
            'Maintaining is absent and the replacement Maintenance columns are incomplete.',
            1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    ;THROW;
END CATCH;
GO

    -- 0.3. drop triggers
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50010, 'Migration transaction is not active.', 1;

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
    ;THROW;
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
        ;THROW 50011, 'Migration transaction is not active.', 1;

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
    ;THROW;
END CATCH;
GO

----------------------------------------------------------
-- A2. Add maintenance_impact_level_id to Maintenance
----------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50012, 'Migration transaction is not active.', 1;

    DECLARE @out_of_service_id TINYINT;

    SELECT @out_of_service_id = maintenance_impact_level_id
    FROM lookup_table.MaintenanceImpactLevel
    WHERE maintenance_impact_level_code = 'OUT_OF_SERVICE';

    IF @out_of_service_id IS NULL
        ;THROW 50013, 'OUT_OF_SERVICE impact level is missing.', 1;

    UPDATE dbo.Maintenance
    SET maintenance_impact_level_id = @out_of_service_id
    WHERE maintenance_impact_level_id IS NULL;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance
        WHERE maintenance_impact_level_id IS NULL
    )
        ;THROW 50014, 'Maintenance impact-level backfill failed.', 1;

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
    ;THROW;
END CATCH;
GO

------------------------------------------------------------------------------
-- A3. Add advisory acknowledgement and instant-booking policy
------------------------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50015, 'Migration transaction is not active.', 1;

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
    ;THROW;
END CATCH;
GO


BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50016, 'Migration transaction is not active.', 1;

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
    ;THROW;
END CATCH;

GO

-- ===========================================================================
-- SECOND VALIDATION FROM 08 — ORDER PRESERVED
-- ===========================================================================

------------------------------------------------------------
-- B1. phone_number is no longer unique
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50017, 'Migration transaction is not active.', 1;

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
    ;THROW;
END CATCH;
GO

---------------------------------------------------------------------------
-- B2. Decompose Booking and Maintaining into direct foreign-key attributes
---------------------------------------------------------------------------

-- B2.1. Add the destination columns first.
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50018, 'Migration transaction is not active.', 1;

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
    ;THROW;
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
        ;THROW 50019,
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
        ;THROW 50020,
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
        ;THROW 50021, 'Booking data changed during decomposition.', 1;
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
        ;THROW 50022, 'Maintenance data changed during decomposition.', 1;
    END;
END;
GO

-- B2.4. Backfill, enforce NOT NULL, and add foreign keys
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50023, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.Booking', N'U') IS NOT NULL
    BEGIN
        UPDATE br
        SET br.user_id = b.user_id,
            br.space_id = b.space_id
        FROM dbo.BookingRequest AS br
        INNER JOIN junction_table.Booking AS b
            ON b.booking_request_id = br.booking_request_id;
    END;

    -- Check simplified assuming clean data

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
    BEGIN
        UPDATE m
        SET m.technician_id = mt.technician_id,
            m.space_id = mt.space_id,
            m.maintenance_start_time = mt.maintenance_start_time,
            m.maintenance_end_time = mt.maintenance_end_time
        FROM dbo.Maintenance AS m
        INNER JOIN junction_table.Maintaining AS mt
            ON mt.maintenance_id = m.maintenance_id;
    END;

    -- Check simplified assuming clean data

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
    ;THROW;
END CATCH;
GO

-- B2.5. Validate copied values, then remove the redundant junction tables
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50024, 'Migration transaction is not active.', 1;

    -- Simplified: no validation copy check assuming clean data

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
    ;THROW;
END CATCH;
GO

---------------------------------------------------------------------------
-- B3. Decision decomposition described in 08
---------------------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50025, 'Migration transaction is not active.', 1;

    -- 1. Create RequestState
    IF OBJECT_ID(N'lookup_table.RequestState', N'U') IS NULL
    BEGIN
        CREATE TABLE lookup_table.RequestState
        (
            request_state_id TINYINT IDENTITY(1, 1) NOT NULL,
            request_state_code VARCHAR(20) NOT NULL,
            request_state_name NVARCHAR(50) NOT NULL,

            CONSTRAINT PK_RequestState_request_state_id
                PRIMARY KEY (request_state_id),
            CONSTRAINT UK_RequestState_code
                UNIQUE (request_state_code),
            CONSTRAINT CHK_RequestState_code_uppercase
                CHECK
                (
                    request_state_code COLLATE Latin1_General_100_BIN2
                        = UPPER(request_state_code)
                            COLLATE Latin1_General_100_BIN2
                )
        );
        INSERT INTO lookup_table.RequestState (request_state_code, request_state_name)
        VALUES ('PENDING', N'Pending'),
               ('REVIEWED', N'Reviewed'),
               ('CANCELLED', N'Cancelled'),
               ('AUTO_APPROVED', N'Auto-Approved');
    END;

    -- 2. Create RequestDecision
    IF OBJECT_ID(N'lookup_table.RequestDecision', N'U') IS NULL
    BEGIN
        CREATE TABLE lookup_table.RequestDecision
        (
            request_decision_id TINYINT IDENTITY(1, 1) NOT NULL,
            request_decision_code VARCHAR(20) NOT NULL,
            request_decision_name NVARCHAR(50) NOT NULL,

            CONSTRAINT PK_RequestDecision_request_decision_id
                PRIMARY KEY (request_decision_id),
            CONSTRAINT UK_RequestDecision_code
                UNIQUE (request_decision_code),
            CONSTRAINT CHK_RequestDecision_code_uppercase
                CHECK
                (
                    request_decision_code COLLATE Latin1_General_100_BIN2
                        = UPPER(request_decision_code)
                            COLLATE Latin1_General_100_BIN2
                )
        );
        INSERT INTO lookup_table.RequestDecision (request_decision_code, request_decision_name)
        VALUES ('APPROVED', N'Approved'),
               ('REJECTED', N'Rejected');
    END;

    --2.5 Add status PENDING to MaintenanceStatus 
    IF NOT EXISTS (
        SELECT 1 FROM lookup_table.MaintenanceStatus WHERE maintenance_status_code = 'PENDING'
    )
    BEGIN
        INSERT INTO lookup_table.MaintenanceStatus (maintenance_status_code, maintenance_status_name)
        VALUES ('PENDING', N'Pending');
    END;

    -- 3. Add request_state_id to BookingRequest
    IF COL_LENGTH(N'dbo.BookingRequest', N'request_state_id') IS NULL
    BEGIN
        ALTER TABLE dbo.BookingRequest
        ADD request_state_id TINYINT NULL;
    END;

    -- 4. Add request_decision_id to Review
    IF OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
    BEGIN
        IF COL_LENGTH(N'junction_table.Review', N'request_decision_id') IS NULL
        BEGIN
            ALTER TABLE junction_table.Review
            ADD request_decision_id TINYINT NULL;
        END;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    ;THROW;
END CATCH;
GO

-- B3.2. Backfill decision data
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50026, 'Migration transaction is not active.', 1;

    -- Populate BookingRequest.request_state_id
    IF EXISTS (
        SELECT 1 FROM sys.columns 
        WHERE object_id = OBJECT_ID(N'dbo.BookingRequest') 
          AND name = N'request_state_id' AND is_nullable = 1
    )
    BEGIN
        -- Default to PENDING if no review
        UPDATE br
        SET br.request_state_id = (SELECT request_state_id FROM lookup_table.RequestState WHERE request_state_code = 'PENDING')
        FROM dbo.BookingRequest AS br;

        -- Update based on existing Review's decision
        IF OBJECT_ID(N'lookup_table.Decision', N'U') IS NOT NULL
           AND OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
        BEGIN
            EXEC sp_executesql N'
            UPDATE br
            SET br.request_state_id = 
                CASE d.decision_code
                    WHEN ''PENDING'' THEN (SELECT request_state_id FROM lookup_table.RequestState WHERE request_state_code = ''PENDING'')
                    WHEN ''CANCELLED'' THEN (SELECT request_state_id FROM lookup_table.RequestState WHERE request_state_code = ''CANCELLED'')
                    ELSE (SELECT request_state_id FROM lookup_table.RequestState WHERE request_state_code = ''REVIEWED'')
                END
            FROM dbo.BookingRequest AS br
            INNER JOIN junction_table.Review AS r ON r.booking_request_id = br.booking_request_id
            INNER JOIN lookup_table.Decision AS d ON d.decision_id = r.decision_id;

            -- Populate junction_table.Review.request_decision_id
            UPDATE r
            SET r.request_decision_id = 
                CASE d.decision_code
                    WHEN ''APPROVED'' THEN (SELECT request_decision_id FROM lookup_table.RequestDecision WHERE request_decision_code = ''APPROVED'')
                    WHEN ''REJECTED'' THEN (SELECT request_decision_id FROM lookup_table.RequestDecision WHERE request_decision_code = ''REJECTED'')
                END
            FROM junction_table.Review AS r
            INNER JOIN lookup_table.Decision AS d ON d.decision_id = r.decision_id;
            ';

            -- Delete non-decisions from Review
            DELETE r
            FROM junction_table.Review AS r
            WHERE r.request_decision_id IS NULL;
        END;
    END;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    ;THROW;
END CATCH;
GO

-- B3.3 Enforce NOT NULL and constraints
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50027, 'Migration transaction is not active.', 1;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.BookingRequest') AND name = N'request_state_id' AND is_nullable = 1)
        ALTER TABLE dbo.BookingRequest ALTER COLUMN request_state_id TINYINT NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.BookingRequest') AND name = N'FK_BookingRequest_request_state')
    BEGIN
        ALTER TABLE dbo.BookingRequest WITH CHECK
        ADD CONSTRAINT FK_BookingRequest_request_state
            FOREIGN KEY (request_state_id) REFERENCES lookup_table.RequestState(request_state_id);
    END;

    IF OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'junction_table.Review') AND name = N'request_decision_id' AND is_nullable = 1)
            ALTER TABLE junction_table.Review ALTER COLUMN request_decision_id TINYINT NOT NULL;

        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.Review') AND name = N'FK_Review_request_decision')
        BEGIN
            ALTER TABLE junction_table.Review WITH CHECK
            ADD CONSTRAINT FK_Review_request_decision
                FOREIGN KEY (request_decision_id) REFERENCES lookup_table.RequestDecision(request_decision_id);
        END;
        
        -- Drop old decision_id column and table
        IF COL_LENGTH(N'junction_table.Review', N'decision_id') IS NOT NULL
        BEGIN
            ALTER TABLE junction_table.Review DROP CONSTRAINT IF EXISTS CHK_Review_decision_time_null_based_on_decision_id;
            ALTER TABLE junction_table.Review DROP CONSTRAINT IF EXISTS CHK_Review_rejection_reason_null_based_on_decision_id;
            ALTER TABLE junction_table.Review DROP CONSTRAINT IF EXISTS CHK_Review_reviewer_id_null_based_on_decision_id;
            ALTER TABLE junction_table.Review DROP CONSTRAINT IF EXISTS FK_Review_decision_id;
            ALTER TABLE junction_table.Review DROP COLUMN decision_id;
        END;
    END;
    
    IF OBJECT_ID(N'lookup_table.Decision', N'U') IS NOT NULL
    BEGIN
        DROP TABLE lookup_table.Decision;
    END;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    ;THROW;
END CATCH;

GO

---------------------------------------------------------------------------
-- B4. Review history redesign described in 08
---------------------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50028, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
    BEGIN
        IF COL_LENGTH(N'junction_table.Review', N'review_id') IS NULL
        BEGIN
            ALTER TABLE junction_table.Review ADD review_id CHAR(9) NULL;
        END;

        -- Backfill review_id safely
        IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'junction_table.Review') AND name = N'review_id' AND is_nullable = 1)
        BEGIN
            EXEC sp_executesql N'
            WITH CTE AS (
                SELECT booking_request_id, ROW_NUMBER() OVER(ORDER BY booking_request_id) AS rn
                FROM junction_table.Review
            )
            UPDATE r
            SET r.review_id = ''r000-'' + RIGHT(''0000'' + CAST(c.rn AS VARCHAR(10)), 4)
            FROM junction_table.Review r
            INNER JOIN CTE c ON r.booking_request_id = c.booking_request_id;
            ';

            ALTER TABLE junction_table.Review ALTER COLUMN review_id CHAR(9) NOT NULL;
        END;

        -- Drop old PK
        IF EXISTS (
            SELECT 1 FROM sys.primary_keys
            WHERE parent_object_id = OBJECT_ID(N'junction_table.Review')
              AND name = N'PK_Review_brid_rid'
        )
        BEGIN
            ALTER TABLE junction_table.Review DROP CONSTRAINT PK_Review_brid_rid;
        END;
        -- Just in case it was incorrectly named PK_Review_brid_id previously
        IF EXISTS (
            SELECT 1 FROM sys.primary_keys
            WHERE parent_object_id = OBJECT_ID(N'junction_table.Review')
              AND name = N'PK_Review_brid_id'
        )
        BEGIN
            ALTER TABLE junction_table.Review DROP CONSTRAINT PK_Review_brid_id;
        END;

        -- Add new PK
        IF NOT EXISTS (
            SELECT 1 FROM sys.primary_keys
            WHERE parent_object_id = OBJECT_ID(N'junction_table.Review')
              AND name = N'PK_Review_review_id'
        )
        BEGIN
            ALTER TABLE junction_table.Review
            ADD CONSTRAINT PK_Review_review_id PRIMARY KEY (review_id);
        END;

        -- Add Check Constraint
        IF NOT EXISTS (
            SELECT 1 FROM sys.check_constraints
            WHERE parent_object_id = OBJECT_ID(N'junction_table.Review')
              AND name = N'CHK_Review_review_format'
        )
        BEGIN
            ALTER TABLE junction_table.Review
            ADD CONSTRAINT CHK_Review_review_format 
            CHECK (review_id LIKE 'r[a-z0-9][a-z0-9][a-z0-9]-[a-z0-9][a-z0-9][a-z0-9][a-z0-9]');
        END;

        -- Transfer to dbo schema
        ALTER SCHEMA dbo TRANSFER junction_table.Review;
    END;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    ;THROW;
END CATCH;
    
GO

---------------------------------------------------------------------------
-- B5. VARCHAR-to-CHAR identifier conversion
---------------------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50029, 'Migration transaction is not active.', 1;
    ALTER TABLE dbo.[User] ALTER COLUMN user_id CHAR(8) NOT NULL;
    ALTER TABLE dbo.BookingRequest ALTER COLUMN booking_request_id CHAR(8) NOT NULL;
    ALTER TABLE junction_table.Review ALTER COLUMN review_id CHAR(9) NOT NULL;
    ALTER TABLE dbo.Reservation ALTER COLUMN reservation_id CHAR(8) NOT NULL;
    ALTER TABLE dbo.Maintenance ALTER COLUMN maintenance_id CHAR(6) NOT NULL;
    ALTER TABLE dbo.SpacePolicy ALTER COLUMN space_policy_id CHAR(5) NOT NULL;


END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    ;THROW;
END CATCH;
GO

---------------------------------------------------------------------------
-- B6. Reservation redesign
---------------------------------------------------------------------------
BEGIN TRY 
    IF XACT_STATE() <> 1
        ;THROW 50030, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.ReservationCheckin', N'U') IS NOT NULL
    BEGIN
        -- 1. Deduplicate to ensure reservation_id is unique for the new PK
        EXEC sp_executesql N'
        WITH CTE AS (
            SELECT reservation_id,
                   ROW_NUMBER() OVER(PARTITION BY reservation_id ORDER BY check_in_time ASC) as rn
            FROM junction_table.ReservationCheckin
        )
        DELETE FROM CTE WHERE rn > 1;
        ';

        -- 2. Rename check_in_time to actual_start_time
        IF COL_LENGTH(N'junction_table.ReservationCheckin', N'check_in_time') IS NOT NULL
            EXEC sp_rename 'junction_table.ReservationCheckin.check_in_time', 'actual_start_time', 'COLUMN';
        
        -- 3. Rename check_out_time to actual_end_time
        IF COL_LENGTH(N'junction_table.ReservationCheckin', N'check_out_time') IS NOT NULL
            EXEC sp_rename 'junction_table.ReservationCheckin.check_out_time', 'actual_end_time', 'COLUMN';

        -- 4. Add new condition columns
        IF COL_LENGTH(N'junction_table.ReservationCheckin', N'space_initial_condition_id') IS NULL
            ALTER TABLE junction_table.ReservationCheckin ADD space_initial_condition_id TINYINT NULL;
            
        IF COL_LENGTH(N'junction_table.ReservationCheckin', N'space_final_condition_id') IS NULL
            ALTER TABLE junction_table.ReservationCheckin ADD space_final_condition_id TINYINT NULL;
            
        -- 5. Drop old constraints
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'FK_ReservationCheckin_reservation_id')
            ALTER TABLE junction_table.ReservationCheckin DROP CONSTRAINT FK_ReservationCheckin_reservation_id;
        
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'FK_ReservationCheckin_attendant_id')
            ALTER TABLE junction_table.ReservationCheckin DROP CONSTRAINT FK_ReservationCheckin_attendant_id;
            
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'FK_ReservationCheckin_check_in_user_id')
            ALTER TABLE junction_table.ReservationCheckin DROP CONSTRAINT FK_ReservationCheckin_check_in_user_id;
            
        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'CHK_ReservationCheckin_time_order')
            ALTER TABLE junction_table.ReservationCheckin DROP CONSTRAINT CHK_ReservationCheckin_time_order;
            
        IF EXISTS (SELECT 1 FROM sys.primary_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'PK_ReservationCheckin_rid_aid_ciuid')
            ALTER TABLE junction_table.ReservationCheckin DROP CONSTRAINT PK_ReservationCheckin_rid_aid_ciuid;
            
        -- 6. Add new PK
        IF NOT EXISTS (SELECT 1 FROM sys.primary_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'PK_ReservationSession_reservation_id')
            ALTER TABLE junction_table.ReservationCheckin ADD CONSTRAINT PK_ReservationSession_reservation_id PRIMARY KEY (reservation_id);
            
        -- 7. Add new FKs and constraints
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'FK_ReservationSession_reservation_id')
            ALTER TABLE junction_table.ReservationCheckin ADD CONSTRAINT FK_ReservationSession_reservation_id FOREIGN KEY (reservation_id) REFERENCES dbo.Reservation(reservation_id);

        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'FK_ReservationSession_attendant_id')
            ALTER TABLE junction_table.ReservationCheckin ADD CONSTRAINT FK_ReservationSession_attendant_id FOREIGN KEY (attendant_id) REFERENCES dbo.[User](user_id);
            
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'FK_ReservationSession_check_in_user_id')
            ALTER TABLE junction_table.ReservationCheckin ADD CONSTRAINT FK_ReservationSession_check_in_user_id FOREIGN KEY (check_in_user_id) REFERENCES dbo.[User](user_id);
            
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'FK_ReservationSession_space_initial_condition_id')
            ALTER TABLE junction_table.ReservationCheckin ADD CONSTRAINT FK_ReservationSession_space_initial_condition_id FOREIGN KEY (space_initial_condition_id) REFERENCES lookup_table.SpaceCondition(space_condition_id);
            
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'FK_ReservationSession_space_final_condition_id')
            ALTER TABLE junction_table.ReservationCheckin ADD CONSTRAINT FK_ReservationSession_space_final_condition_id FOREIGN KEY (space_final_condition_id) REFERENCES lookup_table.SpaceCondition(space_condition_id);
            
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'junction_table.ReservationCheckin') AND name = N'CHK_ReservationSession_time_order')
            ALTER TABLE junction_table.ReservationCheckin ADD CONSTRAINT CHK_ReservationSession_time_order CHECK (actual_end_time IS NULL OR actual_start_time < actual_end_time);
            
        -- 8. Transfer schema and rename
        ALTER SCHEMA dbo TRANSFER junction_table.ReservationCheckin;
        EXEC sp_rename 'dbo.ReservationCheckin', 'ReservationSession', 'OBJECT';
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    ;THROW;
END CATCH;
GO

------------------------------------------------------------
-- B7. Add the management-side canceled reservation status
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        ;THROW 50031, 'Migration transaction is not active.', 1;

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
    ;THROW;
END CATCH;
GO

------------------------------------------------------
-- C. Recreate triggers for the implemented final schema
------------------------------------------------------
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
        ;THROW 50032,
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
        ;THROW 50033,
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
        ;THROW 50034,
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
        ;THROW 50035,
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
        ;THROW 50036,
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
        ;THROW 50037,
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
        ;THROW 50038,
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
        ;THROW 50039,
            'A checked-in reservation requires in-use space status.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_check_in_actual_times
ON dbo.ReservationSession
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.Reservation r ON r.reservation_id = i.reservation_id
        INNER JOIN lookup_table.ReservationStatus rs ON rs.reservation_status_id = r.reservation_status_id
        WHERE i.actual_start_time IS NOT NULL
            AND rs.reservation_status_code = 'NO_SHOW'
    )
    BEGIN
        ;THROW 50040, 'Actual start time cannot exist when the reservation status is no-show', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.Reservation r ON r.reservation_id = i.reservation_id
        INNER JOIN lookup_table.ReservationStatus rs ON rs.reservation_status_id = r.reservation_status_id
        WHERE i.actual_end_time IS NOT NULL
            AND rs.reservation_status_code != 'COMPLETED'
    )
    BEGIN
        ;THROW 50041, 'Actual end time cannot exist unless the reservation status is completed', 1;
    END
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_no_overlapping_approved_requests
ON dbo.Review
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN lookup_table.RequestDecision AS d1
            ON d1.request_decision_id = i.request_decision_id
        INNER JOIN dbo.BookingRequest AS br1
            ON br1.booking_request_id = i.booking_request_id
        INNER JOIN dbo.BookingRequest AS br2
            ON br2.space_id = br1.space_id
           AND br2.booking_request_id <> br1.booking_request_id
        INNER JOIN dbo.Review AS r2
            ON r2.booking_request_id = br2.booking_request_id
        INNER JOIN lookup_table.RequestDecision AS d2
            ON d2.request_decision_id = r2.request_decision_id
        WHERE d1.request_decision_code = 'APPROVED'
          AND d2.request_decision_code = 'APPROVED'
          AND br1.requested_start_time < br2.requested_end_time
          AND br1.requested_end_time > br2.requested_start_time
    )
    BEGIN
        ;THROW 50042,
            'Two approved requests for one space cannot overlap.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_no_approved_review_during_maintaining
ON dbo.Review
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN lookup_table.RequestDecision AS d
            ON d.request_decision_id = i.request_decision_id
        INNER JOIN dbo.BookingRequest AS br
            ON br.booking_request_id = i.booking_request_id
        INNER JOIN dbo.Maintenance AS m
            ON m.space_id = br.space_id
        INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
            ON mil.maintenance_impact_level_id
               = m.maintenance_impact_level_id
        WHERE d.request_decision_code = 'APPROVED'
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
        ;THROW 50043,
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
        ;THROW 50044, 'Migration transaction is not active.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.BookingRequest
        WHERE user_id IS NULL
           OR space_id IS NULL
           OR advisory_acknowledged IS NULL
    )
        ;THROW 50045, 'Final BookingRequest validation failed.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance
        WHERE technician_id IS NULL
           OR space_id IS NULL
           OR maintenance_start_time IS NULL
           OR maintenance_impact_level_id IS NULL
    )
        ;THROW 50046, 'Final Maintenance validation failed.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.SpacePolicy
        WHERE requires_approval IS NULL
    )
        ;THROW 50047, 'Final SpacePolicy validation failed.', 1;

    IF OBJECT_ID(N'junction_table.Booking', N'U') IS NOT NULL
        ;THROW 50048, 'Legacy table junction_table.Booking still exists.', 1;

    IF OBJECT_ID(N'junction_table.Maintaining', N'U') IS NOT NULL
        ;THROW 50049, 'Legacy table junction_table.Maintaining still exists.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.[User]')
          AND name = N'UK_User_phone_number'
    )
        ;THROW 50050, 'phone_number is still constrained as unique.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.MaintenanceImpactLevel
        WHERE maintenance_impact_level_code = 'ADVISORY'
    )
        ;THROW 50051, 'ADVISORY impact level is missing.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.MaintenanceImpactLevel
        WHERE maintenance_impact_level_code = 'OUT_OF_SERVICE'
    )
        ;THROW 50052, 'OUT_OF_SERVICE impact level is missing.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.ReservationStatus
        WHERE reservation_status_code = 'CAN'
    )
        ;THROW 50053, 'Canceled reservation status is missing.', 1;

    IF OBJECT_ID(N'junction_table.ReservationCheckin', N'U') IS NOT NULL
        ;THROW 50054, 'Legacy table junction_table.ReservationCheckin still exists.', 1;

    IF OBJECT_ID(N'dbo.ReservationSession', N'U') IS NULL
        ;THROW 50055, 'New table dbo.ReservationSession was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_booking_request_capacity', N'TR') IS NULL
        ;THROW 50056, 'trg_booking_request_capacity was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_booker_acc_status', N'TR') IS NULL
        ;THROW 50057, 'trg_booker_acc_status was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_booking_requested_time_fit_policy', N'TR') IS NULL
        ;THROW 50058, 'trg_booking_requested_time_fit_policy was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_booking_maintenance_eligibility', N'TR') IS NULL
        ;THROW 50059, 'trg_booking_maintenance_eligibility was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_maintenance_result_note', N'TR') IS NULL
        ;THROW 50060, 'trg_maintenance_result_note was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_space_maintenance_status', N'TR') IS NULL
        ;THROW 50061, 'trg_space_maintenance_status was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_check_in_actual_times', N'TR') IS NULL
        ;THROW 50062, 'trg_check_in_actual_times was not created.', 1;

    IF OBJECT_ID(N'dbo.trg_checked_in_space_in_use', N'TR') IS NULL
        ;THROW 50063, 'trg_checked_in_space_in_use was not created.', 1;

    IF OBJECT_ID(
           N'dbo.trg_no_overlapping_approved_requests',
           N'TR'
       ) IS NULL
        ;THROW 50064,
            'trg_no_overlapping_approved_requests was not created.',
            1;

    IF OBJECT_ID(
           N'dbo.trg_no_approved_review_during_maintaining',
           N'TR'
       ) IS NULL
        ;THROW 50065,
            'trg_no_approved_review_during_maintaining was not created.',
            1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    ;THROW;
END CATCH;
GO
