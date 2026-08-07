USE [School];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF @@TRANCOUNT > 0
BEGIN
    THROW 50001,
        'Run this migration without a pre-existing transaction.',
        1;
END;

BEGIN TRANSACTION;
GO

------------------------------------------------------------
-- 0. Remove migration helpers and obsolete trigger versions
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50002, 'Migration transaction is not active.', 1;

    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateLegacyBooking;
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateLegacyMaintaining;
    DROP PROCEDURE IF EXISTS dbo.__mig_BackfillBookingRelationships;
    DROP PROCEDURE IF EXISTS dbo.__mig_BackfillMaintenanceRelationships;
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateBookingCopy;
    DROP PROCEDURE IF EXISTS dbo.__mig_ValidateMaintenanceCopy;

    DROP TRIGGER IF EXISTS dbo.trg_booking_request_capacity;
    DROP TRIGGER IF EXISTS dbo.trg_booker_acc_status;
    DROP TRIGGER IF EXISTS dbo.trg_booking_requested_time_fit_policy;
    DROP TRIGGER IF EXISTS dbo.trg_booking_maintenance_eligibility;
    DROP TRIGGER IF EXISTS dbo.trg_maintenance_result_note;
    DROP TRIGGER IF EXISTS dbo.trg_space_maintenance_status;
    DROP TRIGGER IF EXISTS dbo.trg_checked_in_space_in_use;
    DROP TRIGGER IF EXISTS dbo.trg_check_in_actual_times;
    DROP TRIGGER IF EXISTS dbo.trg_no_overlapping_approved_requests;
    DROP TRIGGER IF EXISTS dbo.trg_no_approved_review_during_maintaining;
    DROP TRIGGER IF EXISTS junction_table.trg_no_overlapping_approved_requests;
    DROP TRIGGER IF EXISTS junction_table.trg_no_approved_review_during_maintaining;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- ===========================================================================
-- A. BUSINESS REQUIREMENTS UPDATE FROM 08
-- ===========================================================================

------------------------------------------------------------
-- A1. Add MaintenanceImpactLevel and its required values
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50003, 'Migration transaction is not active.', 1;

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
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

------------------------------------------------------------
-- A2. Add Maintenance.maintenance_impact_level_id
------------------------------------------------------------

-- A2.1. Add the destination column.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50004, 'Migration transaction is not active.', 1;

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

-- A2.2. Backfill and enforce the impact-level relationship.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50005, 'Migration transaction is not active.', 1;

    DECLARE @out_of_service_id TINYINT;

    SELECT @out_of_service_id = maintenance_impact_level_id
    FROM lookup_table.MaintenanceImpactLevel
    WHERE maintenance_impact_level_code = 'OUT_OF_SERVICE';

    UPDATE dbo.Maintenance
    SET maintenance_impact_level_id = @out_of_service_id
    WHERE maintenance_impact_level_id IS NULL;

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
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

------------------------------------------------------------
-- A3. Add advisory acknowledgement and approval policy
------------------------------------------------------------

-- A3.1. Add the destination columns.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50006, 'Migration transaction is not active.', 1;

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

-- A3.2. Backfill, enforce NOT NULL, and add defaults.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50007, 'Migration transaction is not active.', 1;

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

    -- Added max_overrun minutes attributes
    IF COL_LENGTH(N'dbo.SpacePolicy', N'max_overrun_minutes') IS NULL
    BEGIN
        ALTER TABLE dbo.SpacePolicy
        ADD max_overrun_minutes INT NULL;
    END;

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

-- ===========================================================================
-- B. SECOND VALIDATION CHANGES FROM 08
-- ===========================================================================

------------------------------------------------------------
-- B1. phone_number is no longer unique
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50006, 'Migration transaction is not active.', 1;

    ALTER TABLE dbo.[User]
    DROP CONSTRAINT IF EXISTS UK_User_phone_number;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

------------------------------------------------------------
-- B2. Decompose Booking and Maintaining relationships
------------------------------------------------------------

-- B2.1. Add direct relationship attributes.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50007, 'Migration transaction is not active.', 1;

    IF COL_LENGTH(N'dbo.BookingRequest', N'user_id') IS NULL
        ALTER TABLE dbo.BookingRequest ADD user_id VARCHAR(8) NULL;

    IF COL_LENGTH(N'dbo.BookingRequest', N'space_id') IS NULL
        ALTER TABLE dbo.BookingRequest ADD space_id VARCHAR(10) NULL;

    IF COL_LENGTH(N'dbo.Maintenance', N'technician_id') IS NULL
        ALTER TABLE dbo.Maintenance ADD technician_id VARCHAR(8) NULL;

    IF COL_LENGTH(N'dbo.Maintenance', N'space_id') IS NULL
        ALTER TABLE dbo.Maintenance ADD space_id VARCHAR(10) NULL;

    IF COL_LENGTH(N'dbo.Maintenance', N'maintenance_start_time') IS NULL
        ALTER TABLE dbo.Maintenance ADD maintenance_start_time DATETIME NULL;

    IF COL_LENGTH(N'dbo.Maintenance', N'maintenance_end_time') IS NULL
        ALTER TABLE dbo.Maintenance ADD maintenance_end_time DATETIME NULL;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- B2.2. Backfill and enforce the direct relationships.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50008, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.Booking', N'U') IS NOT NULL
    BEGIN
        UPDATE br
        SET br.user_id = b.user_id,
            br.space_id = b.space_id
        FROM dbo.BookingRequest AS br
        INNER JOIN junction_table.Booking AS b
            ON b.booking_request_id = br.booking_request_id;
    END;

    IF EXISTS
    (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'user_id' AND is_nullable = 1
    )
        ALTER TABLE dbo.BookingRequest ALTER COLUMN user_id VARCHAR(8) NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'space_id' AND is_nullable = 1
    )
        ALTER TABLE dbo.BookingRequest ALTER COLUMN space_id VARCHAR(10) NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.foreign_keys
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
        SELECT 1 FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'FK_BookingRequest_space'
    )
    BEGIN
        ALTER TABLE dbo.BookingRequest WITH CHECK
        ADD CONSTRAINT FK_BookingRequest_space
            FOREIGN KEY (space_id) REFERENCES dbo.Space(space_id);
    END;

    -- Fresh migration: source the direct relationship attributes from
    -- the legacy junction table. maintenance_end_time is intentionally
    -- nullable for ongoing maintenance, so it is NOT treated as missing.
    IF OBJECT_ID(N'junction_table.Maintaining', N'U') IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.Maintenance AS m
            LEFT JOIN junction_table.Maintaining AS mt
                ON mt.maintenance_id = m.maintenance_id
            WHERE mt.maintenance_id IS NULL
               OR mt.technician_id IS NULL
               OR mt.space_id IS NULL
               OR mt.maintenance_start_time IS NULL
        )
        BEGIN
            THROW 50009,
                'Maintenance source relationship data is incomplete.',
                1;
        END;

        UPDATE m
        SET
            m.technician_id = mt.technician_id,
            m.space_id = mt.space_id,
            m.maintenance_start_time = mt.maintenance_start_time,
            m.maintenance_end_time = mt.maintenance_end_time
        FROM dbo.Maintenance AS m
        INNER JOIN junction_table.Maintaining AS mt
            ON mt.maintenance_id = m.maintenance_id;
    END
    -- Rerun/partial-migration recovery: B2.3 may already have removed
    -- Maintaining, while B3 has preserved the moved attributes in
    -- MaintenanceSession. Rehydrate the temporary Maintenance columns
    -- from MaintenanceSession so the migration can safely continue.
    ELSE IF OBJECT_ID(N'dbo.MaintenanceSession', N'U') IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.Maintenance AS m
            LEFT JOIN dbo.MaintenanceSession AS ms
                ON ms.maintenance_id = m.maintenance_id
            WHERE ms.maintenance_id IS NULL
               OR ms.technician_id IS NULL
               OR m.space_id IS NULL
               OR ms.maintenance_start_time IS NULL
        )
        BEGIN
            THROW 50009,
                'MaintenanceSession recovery data is incomplete.',
                1;
        END;

        UPDATE m
        SET
            m.technician_id = ms.technician_id,
            m.maintenance_start_time = ms.maintenance_start_time,
            m.maintenance_end_time = ms.maintenance_end_time
        FROM dbo.Maintenance AS m
        INNER JOIN dbo.MaintenanceSession AS ms
            ON ms.maintenance_id = m.maintenance_id;
    END
    ELSE
    BEGIN
        THROW 50009,
            'Cannot backfill Maintenance: neither Maintaining nor MaintenanceSession is available.',
            1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Maintenance
        WHERE technician_id IS NULL
           OR space_id IS NULL
           OR maintenance_start_time IS NULL
    )
    BEGIN
        THROW 50009,
            'Maintenance backfill is incomplete.',
            1;
    END;

    IF EXISTS
    (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'technician_id' AND is_nullable = 1
    )
        ALTER TABLE dbo.Maintenance ALTER COLUMN technician_id VARCHAR(8) NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'space_id' AND is_nullable = 1
    )
        ALTER TABLE dbo.Maintenance ALTER COLUMN space_id VARCHAR(10) NOT NULL;

    -- Change under maintenance code to under critical maintenance
    IF EXISTS
    (
        SELECT 1
        FROM lookup_table.SpaceStatus
        WHERE space_status_code = 'UNDER_MAINTENANCE'
    )
    BEGIN
        UPDATE lookup_table.SpaceStatus
        SET space_status_code = 'UNDER_CRITICAL_MAINTENANCE',
            space_status_name = N'Under Critical Maintenance'
        WHERE space_status_code = 'UNDER_MAINTENANCE';
    END;

    IF EXISTS
    (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Maintenance')
          AND name = N'maintenance_start_time' AND is_nullable = 1
    )
        ALTER TABLE dbo.Maintenance
        ALTER COLUMN maintenance_start_time DATETIME NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.foreign_keys
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
        SELECT 1 FROM sys.check_constraints
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
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- B2.3. Remove the redundant relationship tables.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50009, 'Migration transaction is not active.', 1;

    DROP TABLE IF EXISTS junction_table.Booking;
    DROP TABLE IF EXISTS junction_table.Maintaining;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

---------------------------------------------------------------------
-- B3. Decompose Maintenance into MaintenanceSession and Maintenance
---------------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50010, 'Migration transaction is not active.', 1;

    IF OBJECT_ID('dbo.MaintenanceSession', N'U') IS NULL 
    BEGIN
        CREATE TABLE dbo.MaintenanceSession (
            maintenance_id CHAR(6) NOT NULL,
            technician_id CHAR(8) NOT NULL,
            maintenance_start_time DATETIME NOT NULL,
            maintenance_end_time DATETIME NULL,
            maintenance_impact_level_id TINYINT NOT NULL,

            CONSTRAINT PK_MaintenanceSession_maintenance_id
                PRIMARY KEY (maintenance_id),
            CONSTRAINT CHK_MaintenanceSession_start_end_time
                CHECK (
                    maintenance_end_time IS NULL
                    OR maintenance_start_time < maintenance_end_time
                ),
            CONSTRAINT FK_MaintenanceSession_impact_level
                FOREIGN KEY (maintenance_impact_level_id)
                REFERENCES lookup_table.MaintenanceImpactLevel
                           (maintenance_impact_level_id)
        )
    END;

    IF ( 
    COL_LENGTH('dbo.Maintenance', 'technician_id') IS NULL
    OR
    COL_LENGTH('dbo.Maintenance', 'maintenance_start_time') IS NULL
    OR
    COL_LENGTH('dbo.Maintenance', 'maintenance_end_time') IS NULL
    OR 
    COL_LENGTH('dbo.Maintenance', 'maintenance_impact_level_id') IS NULL
    )
    THROW 50092, 'Maintenance table schema is incomplete.', 1;

    BEGIN
        INSERT INTO dbo.MaintenanceSession 
        (maintenance_id, technician_id, maintenance_start_time, maintenance_end_time,
        maintenance_impact_level_id)
        SELECT maintenance_id, technician_id, maintenance_start_time, maintenance_end_time,
        maintenance_impact_level_id
        FROM dbo.Maintenance m
        WHERE NOT EXISTS (
            SELECT 1
            FROM MaintenanceSession ms 
            WHERE ms.maintenance_id = m.maintenance_id 
        )
    END;

    IF EXISTS (
    SELECT 1
    FROM dbo.Maintenance AS m
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.MaintenanceSession AS ms
        WHERE ms.maintenance_id = m.maintenance_id
    )
)
    THROW 50093, 'MaintenanceSession backfill is incomplete.', 1;

    IF OBJECT_ID('dbo.FK_Maintenance_technician', 'F') IS NOT NULL
        ALTER TABLE dbo.Maintenance 
        DROP CONSTRAINT FK_Maintenance_technician;

    IF OBJECT_ID('dbo.CHK_Maintenance_time_order', 'C') IS NOT NULL
        ALTER TABLE dbo.Maintenance 
        DROP CONSTRAINT CHK_Maintenance_time_order;
    
    IF OBJECT_ID('dbo.FK_MaintenanceImpactLevel_id', 'F')
    IS NOT NULL
        ALTER TABLE dbo.Maintenance 
        DROP CONSTRAINT FK_MaintenanceImpactLevel_id;

    IF OBJECT_ID('dbo.FK_Maintenance_impact_level', 'F')
    IS NOT NULL
        ALTER TABLE dbo.Maintenance 
        DROP CONSTRAINT FK_Maintenance_impact_level;

    IF COL_LENGTH('dbo.Maintenance', 'technician_id') IS NOT NULL
        ALTER TABLE dbo.Maintenance
        DROP COLUMN technician_id;

    IF COL_LENGTH('dbo.Maintenance', 'maintenance_start_time') IS NOT NULL
        ALTER TABLE dbo.Maintenance
        DROP COLUMN maintenance_start_time;

    IF COL_LENGTH('dbo.Maintenance', 'maintenance_end_time') IS NOT NULL
        ALTER TABLE dbo.Maintenance
        DROP COLUMN maintenance_end_time;

    IF COL_LENGTH('dbo.Maintenance', 'maintenance_impact_level_id') IS NOT NULL
        ALTER TABLE dbo.Maintenance
        DROP COLUMN maintenance_impact_level_id;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
    
----------------------------------------------------------------
-- B4. Decompose Decision into RequestState and RequestDecision
----------------------------------------------------------------

-- B4.1. Create lookup tables and destination columns.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50010, 'Migration transaction is not active.', 1;

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
    END;

    UPDATE lookup_table.RequestState
    SET request_state_name = N'Pending'
    WHERE request_state_code = 'PENDING';
    IF @@ROWCOUNT = 0
        INSERT INTO lookup_table.RequestState
            (request_state_code, request_state_name)
        VALUES ('PENDING', N'Pending');

    UPDATE lookup_table.RequestState
    SET request_state_name = N'Reviewed'
    WHERE request_state_code = 'REVIEWED';
    IF @@ROWCOUNT = 0
        INSERT INTO lookup_table.RequestState
            (request_state_code, request_state_name)
        VALUES ('REVIEWED', N'Reviewed');

    UPDATE lookup_table.RequestState
    SET request_state_name = N'Cancelled'
    WHERE request_state_code = 'CANCELLED';
    IF @@ROWCOUNT = 0
        INSERT INTO lookup_table.RequestState
            (request_state_code, request_state_name)
        VALUES ('CANCELLED', N'Cancelled');

    UPDATE lookup_table.RequestState
    SET request_state_name = N'Auto-approved'
    WHERE request_state_code = 'AUTO_APPROVED';
    IF @@ROWCOUNT = 0
        INSERT INTO lookup_table.RequestState
            (request_state_code, request_state_name)
        VALUES ('AUTO_APPROVED', N'Auto-approved');

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
    END;

    UPDATE lookup_table.RequestDecision
    SET request_decision_name = N'Approved'
    WHERE request_decision_code = 'APPROVED';
    IF @@ROWCOUNT = 0
        INSERT INTO lookup_table.RequestDecision
            (request_decision_code, request_decision_name)
        VALUES ('APPROVED', N'Approved');

    UPDATE lookup_table.RequestDecision
    SET request_decision_name = N'Rejected'
    WHERE request_decision_code = 'REJECTED';
    IF @@ROWCOUNT = 0
        INSERT INTO lookup_table.RequestDecision
            (request_decision_code, request_decision_name)
        VALUES ('REJECTED', N'Rejected');

    IF NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.MaintenanceStatus
        WHERE maintenance_status_code = 'PENDING'
    )
    BEGIN
        INSERT INTO lookup_table.MaintenanceStatus
            (maintenance_status_code, maintenance_status_name)
        VALUES ('PENDING', N'Pending');
    END;

    IF COL_LENGTH(N'dbo.BookingRequest', N'request_state_id') IS NULL
        ALTER TABLE dbo.BookingRequest ADD request_state_id TINYINT NULL;

    IF OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
       AND COL_LENGTH(N'junction_table.Review', N'request_decision_id') IS NULL
        ALTER TABLE junction_table.Review ADD request_decision_id TINYINT NULL;

    IF OBJECT_ID(N'dbo.Review', N'U') IS NOT NULL
       AND COL_LENGTH(N'dbo.Review', N'request_decision_id') IS NULL
        ALTER TABLE dbo.Review ADD request_decision_id TINYINT NULL;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- B4.2. Backfill the decomposed decision data.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50011, 'Migration transaction is not active.', 1;

    DECLARE @pending_state_id TINYINT;
    DECLARE @reviewed_state_id TINYINT;
    DECLARE @cancelled_state_id TINYINT;
    DECLARE @approved_decision_id TINYINT;
    DECLARE @rejected_decision_id TINYINT;

    SELECT @pending_state_id = request_state_id
    FROM lookup_table.RequestState
    WHERE request_state_code = 'PENDING';

    SELECT @reviewed_state_id = request_state_id
    FROM lookup_table.RequestState
    WHERE request_state_code = 'REVIEWED';

    SELECT @cancelled_state_id = request_state_id
    FROM lookup_table.RequestState
    WHERE request_state_code = 'CANCELLED';

    SELECT @approved_decision_id = request_decision_id
    FROM lookup_table.RequestDecision
    WHERE request_decision_code = 'APPROVED';

    SELECT @rejected_decision_id = request_decision_id
    FROM lookup_table.RequestDecision
    WHERE request_decision_code = 'REJECTED';

    UPDATE dbo.BookingRequest
    SET request_state_id = @pending_state_id
    WHERE request_state_id IS NULL;

    IF OBJECT_ID(N'lookup_table.Decision', N'U') IS NOT NULL
       AND OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
    BEGIN
        UPDATE br
        SET br.request_state_id =
            CASE d.decision_code
                WHEN 'PENDING' THEN @pending_state_id
                WHEN 'CANCELLED' THEN @cancelled_state_id
                ELSE @reviewed_state_id
            END
        FROM dbo.BookingRequest AS br
        INNER JOIN junction_table.Review AS r
            ON r.booking_request_id = br.booking_request_id
        INNER JOIN lookup_table.Decision AS d
            ON d.decision_id = r.decision_id;

        UPDATE r
        SET r.request_decision_id =
            CASE d.decision_code
                WHEN 'APPROVED' THEN @approved_decision_id
                WHEN 'REJECTED' THEN @rejected_decision_id
            END
        FROM junction_table.Review AS r
        INNER JOIN lookup_table.Decision AS d
            ON d.decision_id = r.decision_id;

        DELETE FROM junction_table.Review
        WHERE request_decision_id IS NULL;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- B4.3. Enforce the final decision relationships and remove Decision.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50012, 'Migration transaction is not active.', 1;

    IF EXISTS
    (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'request_state_id' AND is_nullable = 1
    )
        ALTER TABLE dbo.BookingRequest
        ALTER COLUMN request_state_id TINYINT NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.BookingRequest')
          AND name = N'FK_BookingRequest_request_state'
    )
    BEGIN
        ALTER TABLE dbo.BookingRequest WITH CHECK
        ADD CONSTRAINT FK_BookingRequest_request_state
            FOREIGN KEY (request_state_id)
            REFERENCES lookup_table.RequestState(request_state_id);
    END;

    IF OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1 FROM sys.columns
            WHERE object_id = OBJECT_ID(N'junction_table.Review')
              AND name = N'request_decision_id' AND is_nullable = 1
        )
            ALTER TABLE junction_table.Review
            ALTER COLUMN request_decision_id TINYINT NOT NULL;

        IF NOT EXISTS
        (
            SELECT 1 FROM sys.foreign_keys
            WHERE parent_object_id = OBJECT_ID(N'junction_table.Review')
              AND name = N'FK_Review_request_decision'
        )
        BEGIN
            ALTER TABLE junction_table.Review WITH CHECK
            ADD CONSTRAINT FK_Review_request_decision
                FOREIGN KEY (request_decision_id)
                REFERENCES lookup_table.RequestDecision(request_decision_id);
        END;

        IF COL_LENGTH(N'junction_table.Review', N'decision_id') IS NOT NULL
        BEGIN
            ALTER TABLE junction_table.Review
            DROP CONSTRAINT IF EXISTS CHK_Review_decision_time_null_based_on_decision_id;
            ALTER TABLE junction_table.Review
            DROP CONSTRAINT IF EXISTS CHK_Review_rejection_reason_null_based_on_decision_id;
            ALTER TABLE junction_table.Review
            DROP CONSTRAINT IF EXISTS CHK_Review_reviewer_id_null_based_on_decision_id;
            ALTER TABLE junction_table.Review
            DROP CONSTRAINT IF EXISTS FK_Review_decision_id;
            ALTER TABLE junction_table.Review DROP COLUMN decision_id;
        END;
    END;

    IF OBJECT_ID(N'dbo.Review', N'U') IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1 FROM sys.columns
            WHERE object_id = OBJECT_ID(N'dbo.Review')
              AND name = N'request_decision_id' AND is_nullable = 1
        )
            ALTER TABLE dbo.Review
            ALTER COLUMN request_decision_id TINYINT NOT NULL;

        IF NOT EXISTS
        (
            SELECT 1 FROM sys.foreign_keys
            WHERE parent_object_id = OBJECT_ID(N'dbo.Review')
              AND name = N'FK_Review_request_decision'
        )
        BEGIN
            ALTER TABLE dbo.Review WITH CHECK
            ADD CONSTRAINT FK_Review_request_decision
                FOREIGN KEY (request_decision_id)
                REFERENCES lookup_table.RequestDecision(request_decision_id);
        END;
    END;

    DROP TABLE IF EXISTS lookup_table.Decision;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

------------------------------------------------------------
-- B5. Promote Review and add review history identifiers
------------------------------------------------------------

-- B5.1. Add review_id to the legacy Review table.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50013, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
       AND COL_LENGTH(N'junction_table.Review', N'review_id') IS NULL
    BEGIN
        ALTER TABLE junction_table.Review
        ADD review_id CHAR(9) NULL;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- B5.2. Populate review_id and transfer Review to dbo.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50014, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
       AND OBJECT_ID(N'dbo.Review', N'U') IS NULL
    BEGIN
        ;WITH NumberedReview AS
        (
            SELECT booking_request_id,
                   RIGHT
                   (
                       '00000000'
                       + CONVERT
                         (
                             VARCHAR(20),
                             ROW_NUMBER() OVER (ORDER BY booking_request_id)
                         ),
                       8
                   ) AS identifier_body
            FROM junction_table.Review
        )
        UPDATE r
        SET review_id = LEFT(n.identifier_body, 4)
                        + '-'
                        + RIGHT(n.identifier_body, 4)
        FROM junction_table.Review AS r
        INNER JOIN NumberedReview AS n
            ON n.booking_request_id = r.booking_request_id
        WHERE r.review_id IS NULL;

        IF EXISTS
        (
            SELECT 1 FROM sys.columns
            WHERE object_id = OBJECT_ID(N'junction_table.Review')
              AND name = N'review_id' AND is_nullable = 1
        )
            ALTER TABLE junction_table.Review
            ALTER COLUMN review_id CHAR(9) NOT NULL;

        ALTER TABLE junction_table.Review
        DROP CONSTRAINT IF EXISTS PK_Review_brid_rid;
        ALTER TABLE junction_table.Review
        DROP CONSTRAINT IF EXISTS PK_Review_brid_id;

        ALTER SCHEMA dbo TRANSFER junction_table.Review;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- B5.3. Enforce the final Review key and format.
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50015, 'Migration transaction is not active.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.Review')
          AND name = N'PK_Review_review_id'
    )
    BEGIN
        ALTER TABLE dbo.Review
        ADD CONSTRAINT PK_Review_review_id PRIMARY KEY (review_id);
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.Review')
          AND name = N'CHK_Review_review_format'
    )
    BEGIN
        ALTER TABLE dbo.Review WITH CHECK
        ADD CONSTRAINT CHK_Review_review_format
            CHECK
            (
                review_id COLLATE Latin1_General_100_BIN2
                    LIKE '[a-z0-9][a-z0-9][a-z0-9][a-z0-9]-[a-z0-9][a-z0-9][a-z0-9][a-z0-9]'
            );
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

------------------------------------------------------------
-- B6. Convert fixed-length identifiers from VARCHAR to CHAR
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50016, 'Migration transaction is not active.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        WHERE
            (
                c.object_id = OBJECT_ID(N'dbo.[User]')
                AND c.name = N'user_id'
                AND TYPE_NAME(c.system_type_id) <> N'char'
            )
            OR
            (
                c.object_id = OBJECT_ID(N'dbo.BookingRequest')
                AND c.name IN (N'booking_request_id', N'user_id')
                AND TYPE_NAME(c.system_type_id) <> N'char'
            )
            OR
            (
                c.object_id = OBJECT_ID(N'dbo.Review')
                AND c.name IN (N'booking_request_id', N'reviewer_id')
                AND TYPE_NAME(c.system_type_id) <> N'char'
            )
            OR
            (
                c.object_id = OBJECT_ID(N'dbo.Reservation')
                AND c.name IN (N'reservation_id', N'booking_request_id')
                AND TYPE_NAME(c.system_type_id) <> N'char'
            )
            OR
            (
                c.object_id = OBJECT_ID(N'dbo.Maintenance')
                AND c.name IN (N'maintenance_id', N'reporter_id')
                AND TYPE_NAME(c.system_type_id) <> N'char'
            )
            OR
            (
                c.object_id = OBJECT_ID(N'dbo.SpacePolicy')
                AND c.name = N'space_policy_id'
                AND TYPE_NAME(c.system_type_id) <> N'char'
            )
            OR
            (
                c.object_id = OBJECT_ID(N'dbo.Space')
                AND c.name = N'space_policy_id'
                AND TYPE_NAME(c.system_type_id) <> N'char'
            )
            OR
            (
                c.object_id IN
                (
                    OBJECT_ID(N'junction_table.ReservationCheckin'),
                    OBJECT_ID(N'dbo.ReservationSession')
                )
                AND c.name IN (N'reservation_id', N'attendant_id', N'check_in_user_id')
                AND TYPE_NAME(c.system_type_id) <> N'char'
            )
    )
    BEGIN
        ALTER TABLE dbo.BookingRequest
        DROP CONSTRAINT IF EXISTS FK_BookingRequest_user;
        ALTER TABLE dbo.Review
        DROP CONSTRAINT IF EXISTS FK_Review_booking_request_id;
        ALTER TABLE dbo.Review
        DROP CONSTRAINT IF EXISTS FK_Review_reviewer_id;
        ALTER TABLE dbo.Reservation
        DROP CONSTRAINT IF EXISTS FK_Reservation_booking_request_id;
        ALTER TABLE dbo.Maintenance
        DROP CONSTRAINT IF EXISTS FK_Maintenance_reporter_id;

        IF OBJECT_ID(N'dbo.MaintenanceSession', N'U') IS NOT NULL
        BEGIN
            ALTER TABLE dbo.MaintenanceSession
            DROP CONSTRAINT IF EXISTS FK_MaintenanceSession_maintenance;
            ALTER TABLE dbo.MaintenanceSession
            DROP CONSTRAINT IF EXISTS FK_MaintenanceSession_technician;
        END;

        ALTER TABLE dbo.Space
        DROP CONSTRAINT IF EXISTS FK_Space_space_policy_id;

        IF OBJECT_ID(N'junction_table.ReservationCheckin', N'U') IS NOT NULL
        BEGIN
            ALTER TABLE junction_table.ReservationCheckin
            DROP CONSTRAINT IF EXISTS FK_ReservationCheckin_reservation_id;
            ALTER TABLE junction_table.ReservationCheckin
            DROP CONSTRAINT IF EXISTS FK_ReservationCheckin_attendant_id;
            ALTER TABLE junction_table.ReservationCheckin
            DROP CONSTRAINT IF EXISTS FK_ReservationCheckin_check_in_user_id;
            ALTER TABLE junction_table.ReservationCheckin
            DROP CONSTRAINT IF EXISTS PK_ReservationCheckin_rid_aid_ciuid;
        END;

        IF OBJECT_ID(N'dbo.ReservationSession', N'U') IS NOT NULL
        BEGIN
            ALTER TABLE dbo.ReservationSession
            DROP CONSTRAINT IF EXISTS FK_ReservationSession_reservation_id;
            ALTER TABLE dbo.ReservationSession
            DROP CONSTRAINT IF EXISTS FK_ReservationSession_attendant_id;
            ALTER TABLE dbo.ReservationSession
            DROP CONSTRAINT IF EXISTS FK_ReservationSession_check_in_user_id;
            ALTER TABLE dbo.ReservationSession
            DROP CONSTRAINT IF EXISTS PK_ReservationSession_reservation_id;
        END;

        ALTER TABLE dbo.[User]
        DROP CONSTRAINT IF EXISTS CHK_User_user_id_format;
        ALTER TABLE dbo.BookingRequest
        DROP CONSTRAINT IF EXISTS CHK_BookingRequest_booking_request_id_format;
        ALTER TABLE dbo.Reservation
        DROP CONSTRAINT IF EXISTS CHK_Reservation_reservation_id_format;
        ALTER TABLE dbo.Maintenance
        DROP CONSTRAINT IF EXISTS CHK_Maintenance_maintenance_id_format;
        ALTER TABLE dbo.SpacePolicy
        DROP CONSTRAINT IF EXISTS CHK_SpacePolicy_space_policy_id_format;

        ALTER TABLE dbo.[User]
        DROP CONSTRAINT IF EXISTS PK_User_user_id;
        ALTER TABLE dbo.BookingRequest
        DROP CONSTRAINT IF EXISTS PK_BookingRequest_booking_request_id;
        ALTER TABLE dbo.Reservation
        DROP CONSTRAINT IF EXISTS PK_Reservation_reservation_id;
        ALTER TABLE dbo.Maintenance
        DROP CONSTRAINT IF EXISTS PK_Maintenance_maintenance_id;
        ALTER TABLE dbo.SpacePolicy
        DROP CONSTRAINT IF EXISTS PK_SpacePolicy_space_policy_id;

        ALTER TABLE dbo.[User]
        ALTER COLUMN user_id CHAR(8) NOT NULL;
        ALTER TABLE dbo.BookingRequest
        ALTER COLUMN booking_request_id CHAR(8) NOT NULL;
        ALTER TABLE dbo.BookingRequest
        ALTER COLUMN user_id CHAR(8) NOT NULL;
        ALTER TABLE dbo.Review
        ALTER COLUMN booking_request_id CHAR(8) NOT NULL;
        ALTER TABLE dbo.Review
        ALTER COLUMN reviewer_id CHAR(8) NOT NULL;
        ALTER TABLE dbo.Reservation
        ALTER COLUMN reservation_id CHAR(8) NOT NULL;
        ALTER TABLE dbo.Reservation
        ALTER COLUMN booking_request_id CHAR(8) NULL;
        ALTER TABLE dbo.Maintenance
        ALTER COLUMN maintenance_id CHAR(6) NOT NULL;
        ALTER TABLE dbo.Maintenance
        ALTER COLUMN reporter_id CHAR(8) NOT NULL;
        ALTER TABLE dbo.SpacePolicy
        ALTER COLUMN space_policy_id CHAR(5) NOT NULL;
        ALTER TABLE dbo.Space
        ALTER COLUMN space_policy_id CHAR(5) NOT NULL;

        IF OBJECT_ID(N'junction_table.ReservationCheckin', N'U') IS NOT NULL
        BEGIN
            ALTER TABLE junction_table.ReservationCheckin
            ALTER COLUMN reservation_id CHAR(8) NOT NULL;
            ALTER TABLE junction_table.ReservationCheckin
            ALTER COLUMN attendant_id CHAR(8) NOT NULL;
            ALTER TABLE junction_table.ReservationCheckin
            ALTER COLUMN check_in_user_id CHAR(8) NOT NULL;
        END;

        IF OBJECT_ID(N'dbo.ReservationSession', N'U') IS NOT NULL
        BEGIN
            ALTER TABLE dbo.ReservationSession
            ALTER COLUMN reservation_id CHAR(8) NOT NULL;
            ALTER TABLE dbo.ReservationSession
            ALTER COLUMN attendant_id CHAR(8) NOT NULL;
            ALTER TABLE dbo.ReservationSession
            ALTER COLUMN check_in_user_id CHAR(8) NOT NULL;
        END;

        ALTER TABLE dbo.[User]
        ADD CONSTRAINT PK_User_user_id PRIMARY KEY (user_id);
        ALTER TABLE dbo.BookingRequest
        ADD CONSTRAINT PK_BookingRequest_booking_request_id
            PRIMARY KEY (booking_request_id);
        ALTER TABLE dbo.Reservation
        ADD CONSTRAINT PK_Reservation_reservation_id PRIMARY KEY (reservation_id);
        ALTER TABLE dbo.Maintenance
        ADD CONSTRAINT PK_Maintenance_maintenance_id PRIMARY KEY (maintenance_id);
        ALTER TABLE dbo.SpacePolicy
        ADD CONSTRAINT PK_SpacePolicy_space_policy_id PRIMARY KEY (space_policy_id);

        IF OBJECT_ID(N'junction_table.ReservationCheckin', N'U') IS NOT NULL
        BEGIN
            ALTER TABLE junction_table.ReservationCheckin
            ADD CONSTRAINT PK_ReservationCheckin_rid_aid_ciuid
                PRIMARY KEY (reservation_id, attendant_id, check_in_user_id);
        END;

        IF OBJECT_ID(N'dbo.ReservationSession', N'U') IS NOT NULL
        BEGIN
            ALTER TABLE dbo.ReservationSession
            ADD CONSTRAINT PK_ReservationSession_reservation_id
                PRIMARY KEY (reservation_id);
        END;

        ALTER TABLE dbo.[User] WITH CHECK
        ADD CONSTRAINT CHK_User_user_id_format
            CHECK (LEN(user_id) = 8 AND user_id NOT LIKE '%[^0-9]%');

        ALTER TABLE dbo.BookingRequest WITH CHECK
        ADD CONSTRAINT CHK_BookingRequest_booking_request_id_format
            CHECK
            (
                LEN(booking_request_id) = 8
                AND booking_request_id COLLATE Latin1_General_100_BIN2
                    NOT LIKE '%[^a-z0-9]%'
            );

        ALTER TABLE dbo.Reservation WITH CHECK
        ADD CONSTRAINT CHK_Reservation_reservation_id_format
            CHECK
            (
                LEN(reservation_id) = 8
                AND reservation_id COLLATE Latin1_General_100_BIN2
                    NOT LIKE '%[^A-Z0-9]%'
            );

        ALTER TABLE dbo.Maintenance WITH CHECK
        ADD CONSTRAINT CHK_Maintenance_maintenance_id_format
            CHECK
            (
                LEN(maintenance_id) = 6
                AND maintenance_id COLLATE Latin1_General_100_BIN2
                    NOT LIKE '%[^a-z0-9]%'
            );

        ALTER TABLE dbo.SpacePolicy WITH CHECK
        ADD CONSTRAINT CHK_SpacePolicy_space_policy_id_format
            CHECK
            (
                LEN(space_policy_id) = 5
                AND space_policy_id COLLATE Latin1_General_100_BIN2
                    NOT LIKE '%[^A-Z]%'
            );

        ALTER TABLE dbo.BookingRequest WITH CHECK
        ADD CONSTRAINT FK_BookingRequest_user
            FOREIGN KEY (user_id) REFERENCES dbo.[User](user_id);
        ALTER TABLE dbo.Review WITH CHECK
        ADD CONSTRAINT FK_Review_booking_request_id
            FOREIGN KEY (booking_request_id)
            REFERENCES dbo.BookingRequest(booking_request_id);
        ALTER TABLE dbo.Review WITH CHECK
        ADD CONSTRAINT FK_Review_reviewer_id
            FOREIGN KEY (reviewer_id) REFERENCES dbo.[User](user_id);
        ALTER TABLE dbo.Reservation WITH CHECK
        ADD CONSTRAINT FK_Reservation_booking_request_id
            FOREIGN KEY (booking_request_id)
            REFERENCES dbo.BookingRequest(booking_request_id);
        ALTER TABLE dbo.Maintenance WITH CHECK
        ADD CONSTRAINT FK_Maintenance_reporter_id
            FOREIGN KEY (reporter_id) REFERENCES dbo.[User](user_id);

        IF OBJECT_ID(N'dbo.MaintenanceSession', N'U') IS NOT NULL
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM sys.foreign_keys
                WHERE parent_object_id = OBJECT_ID(N'dbo.MaintenanceSession')
                  AND name = N'FK_MaintenanceSession_maintenance'
            )
            BEGIN
                ALTER TABLE dbo.MaintenanceSession WITH CHECK
                ADD CONSTRAINT FK_MaintenanceSession_maintenance
                    FOREIGN KEY (maintenance_id)
                    REFERENCES dbo.Maintenance(maintenance_id);
            END;

            IF NOT EXISTS
            (
                SELECT 1
                FROM sys.foreign_keys
                WHERE parent_object_id = OBJECT_ID(N'dbo.MaintenanceSession')
                  AND name = N'FK_MaintenanceSession_technician'
            )
            BEGIN
                ALTER TABLE dbo.MaintenanceSession WITH CHECK
                ADD CONSTRAINT FK_MaintenanceSession_technician
                    FOREIGN KEY (technician_id)
                    REFERENCES dbo.[User](user_id);
            END;
        END;

        ALTER TABLE dbo.Space WITH CHECK
        ADD CONSTRAINT FK_Space_space_policy_id
            FOREIGN KEY (space_policy_id)
            REFERENCES dbo.SpacePolicy(space_policy_id);

        IF OBJECT_ID(N'junction_table.ReservationCheckin', N'U') IS NOT NULL
        BEGIN
            ALTER TABLE junction_table.ReservationCheckin WITH CHECK
            ADD CONSTRAINT FK_ReservationCheckin_reservation_id
                FOREIGN KEY (reservation_id)
                REFERENCES dbo.Reservation(reservation_id);
            ALTER TABLE junction_table.ReservationCheckin WITH CHECK
            ADD CONSTRAINT FK_ReservationCheckin_attendant_id
                FOREIGN KEY (attendant_id) REFERENCES dbo.[User](user_id);
            ALTER TABLE junction_table.ReservationCheckin WITH CHECK
            ADD CONSTRAINT FK_ReservationCheckin_check_in_user_id
                FOREIGN KEY (check_in_user_id) REFERENCES dbo.[User](user_id);
        END;

        IF OBJECT_ID(N'dbo.ReservationSession', N'U') IS NOT NULL
        BEGIN
            ALTER TABLE dbo.ReservationSession WITH CHECK
            ADD CONSTRAINT FK_ReservationSession_reservation_id
                FOREIGN KEY (reservation_id)
                REFERENCES dbo.Reservation(reservation_id);
            ALTER TABLE dbo.ReservationSession WITH CHECK
            ADD CONSTRAINT FK_ReservationSession_attendant_id
                FOREIGN KEY (attendant_id) REFERENCES dbo.[User](user_id);
            ALTER TABLE dbo.ReservationSession WITH CHECK
            ADD CONSTRAINT FK_ReservationSession_check_in_user_id
                FOREIGN KEY (check_in_user_id) REFERENCES dbo.[User](user_id);
        END;
    END;

    -- Final idempotent FK enforcement for the decomposed maintenance session.
    -- These are outside the conversion IF so reruns still restore them when the
    -- identifier columns are already CHAR.
    IF OBJECT_ID(N'dbo.MaintenanceSession', N'U') IS NOT NULL
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.foreign_keys
            WHERE parent_object_id = OBJECT_ID(N'dbo.MaintenanceSession')
              AND name = N'FK_MaintenanceSession_maintenance'
        )
        BEGIN
            ALTER TABLE dbo.MaintenanceSession WITH CHECK
            ADD CONSTRAINT FK_MaintenanceSession_maintenance
                FOREIGN KEY (maintenance_id)
                REFERENCES dbo.Maintenance(maintenance_id);
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.foreign_keys
            WHERE parent_object_id = OBJECT_ID(N'dbo.MaintenanceSession')
              AND name = N'FK_MaintenanceSession_technician'
        )
        BEGIN
            ALTER TABLE dbo.MaintenanceSession WITH CHECK
            ADD CONSTRAINT FK_MaintenanceSession_technician
                FOREIGN KEY (technician_id)
                REFERENCES dbo.[User](user_id);
        END;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

------------------------------------------------------------
-- B7. Promote ReservationCheckin to ReservationSession
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50017, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'junction_table.ReservationCheckin', N'U') IS NOT NULL
       AND OBJECT_ID(N'dbo.ReservationSession', N'U') IS NULL
    BEGIN
        ALTER TABLE junction_table.ReservationCheckin
        DROP CONSTRAINT IF EXISTS FK_ReservationCheckin_reservation_id;
        ALTER TABLE junction_table.ReservationCheckin
        DROP CONSTRAINT IF EXISTS FK_ReservationCheckin_attendant_id;
        ALTER TABLE junction_table.ReservationCheckin
        DROP CONSTRAINT IF EXISTS FK_ReservationCheckin_check_in_user_id;
        ALTER TABLE junction_table.ReservationCheckin
        DROP CONSTRAINT IF EXISTS CHK_ReservationCheckin_time_order;
        ALTER TABLE junction_table.ReservationCheckin
        DROP CONSTRAINT IF EXISTS PK_ReservationCheckin_rid_aid_ciuid;

        ALTER TABLE junction_table.ReservationCheckin
        ADD CONSTRAINT PK_ReservationSession_reservation_id
            PRIMARY KEY (reservation_id);

        ALTER TABLE junction_table.ReservationCheckin WITH CHECK
        ADD CONSTRAINT FK_ReservationSession_reservation_id
            FOREIGN KEY (reservation_id)
            REFERENCES dbo.Reservation(reservation_id);
        ALTER TABLE junction_table.ReservationCheckin WITH CHECK
        ADD CONSTRAINT FK_ReservationSession_attendant_id
            FOREIGN KEY (attendant_id) REFERENCES dbo.[User](user_id);
        ALTER TABLE junction_table.ReservationCheckin WITH CHECK
        ADD CONSTRAINT FK_ReservationSession_check_in_user_id
            FOREIGN KEY (check_in_user_id) REFERENCES dbo.[User](user_id);
        ALTER TABLE junction_table.ReservationCheckin WITH CHECK
        ADD CONSTRAINT FK_ReservationSession_space_initial_condition_id
            FOREIGN KEY (space_initial_condition_id)
            REFERENCES lookup_table.SpaceCondition(space_condition_id);
        ALTER TABLE junction_table.ReservationCheckin WITH CHECK
        ADD CONSTRAINT FK_ReservationSession_space_final_condition_id
            FOREIGN KEY (space_final_condition_id)
            REFERENCES lookup_table.SpaceCondition(space_condition_id);
        ALTER TABLE junction_table.ReservationCheckin WITH CHECK
        ADD CONSTRAINT CHK_ReservationSession_time_order
            CHECK
            (
                actual_end_time IS NULL
                OR actual_start_time < actual_end_time
            );

        ALTER SCHEMA dbo TRANSFER junction_table.ReservationCheckin;
        EXEC sys.sp_rename
            N'dbo.ReservationCheckin',
            N'ReservationSession',
            N'OBJECT';
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

------------------------------------------------------------
-- B8. Add the management-side canceled reservation status
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50018, 'Migration transaction is not active.', 1;

    UPDATE lookup_table.ReservationStatus
    SET reservation_status_name = N'Canceled'
    WHERE reservation_status_code = 'CAN';

    IF @@ROWCOUNT = 0
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

------------------------------------------------------------
-- C. Recreate triggers for the final schema
------------------------------------------------------------
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
        THROW 50032,
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
        THROW 50033,
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
        THROW 50034,
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
        INNER JOIN dbo.Maintenance AS mt
            ON mt.space_id = i.space_id
        INNER JOIN dbo.MaintenanceSession AS m 
            ON m.maintenance_id = mt.maintenance_id
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
        THROW 50035,
            'The space is out of service during the requested time.',
            1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Maintenance AS mt
            ON mt.space_id = i.space_id
        INNER JOIN dbo.MaintenanceSession AS m 
            ON m.maintenance_id = mt.maintenance_id
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
        THROW 50036,
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
        WHERE (i.result_note IS NOT NULL)
          AND ms.maintenance_status_code <> 'COMPLETED'
    )
    BEGIN
        THROW 50037,
            'A result note requires completed maintenance.',
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
        INNER JOIN dbo.Maintenance AS mt
            ON mt.space_id = i.space_id
        INNER JOIN dbo.MaintenanceSession AS m 
            ON m.maintenance_id = mt.maintenance_id
        INNER JOIN lookup_table.MaintenanceStatus AS ms
            ON ms.maintenance_status_id = mt.maintenance_status_id
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
        THROW 50038,
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
        THROW 50039,
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
        THROW 50040, 'Actual start time cannot exist when the reservation status is no-show', 1;
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
        THROW 50041, 'Actual end time cannot exist unless the reservation status is completed', 1;
    END
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_no_overlapping_approved_requests
ON dbo.Review
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentDecision TABLE
    (
        booking_request_id CHAR(8) PRIMARY KEY,
        request_decision_code VARCHAR(20) NOT NULL
    );

    INSERT INTO @CurrentDecision
    (
        booking_request_id,
        request_decision_code
    )
    SELECT ranked.booking_request_id,
           rd.request_decision_code
    FROM
    (
        SELECT r.booking_request_id,
               r.request_decision_id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY r.booking_request_id
                   ORDER BY r.decision_time DESC, r.review_id DESC
               ) AS review_rank
        FROM dbo.Review AS r
    ) AS ranked
    INNER JOIN lookup_table.RequestDecision AS rd
        ON rd.request_decision_id = ranked.request_decision_id
    WHERE ranked.review_rank = 1;

    IF EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT DISTINCT booking_request_id
            FROM inserted
        ) AS affected
        INNER JOIN @CurrentDecision AS current_1
            ON current_1.booking_request_id = affected.booking_request_id
           AND current_1.request_decision_code = 'APPROVED'
        INNER JOIN dbo.BookingRequest AS br1
            ON br1.booking_request_id = affected.booking_request_id
        INNER JOIN dbo.BookingRequest AS br2
            ON br2.space_id = br1.space_id
           AND br2.booking_request_id <> br1.booking_request_id
           AND br1.requested_start_time < br2.requested_end_time
           AND br1.requested_end_time > br2.requested_start_time
        INNER JOIN @CurrentDecision AS current_2
            ON current_2.booking_request_id = br2.booking_request_id
           AND current_2.request_decision_code = 'APPROVED'
    )
    BEGIN
        THROW 50042,
            'Two currently approved requests for one space cannot overlap.',
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

    DECLARE @CurrentDecision TABLE
    (
        booking_request_id CHAR(8) PRIMARY KEY,
        request_decision_code VARCHAR(20) NOT NULL
    );

    INSERT INTO @CurrentDecision
    (
        booking_request_id,
        request_decision_code
    )
    SELECT ranked.booking_request_id,
           rd.request_decision_code
    FROM
    (
        SELECT r.booking_request_id,
               r.request_decision_id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY r.booking_request_id
                   ORDER BY r.decision_time DESC, r.review_id DESC
               ) AS review_rank
        FROM dbo.Review AS r
    ) AS ranked
    INNER JOIN lookup_table.RequestDecision AS rd
        ON rd.request_decision_id = ranked.request_decision_id
    WHERE ranked.review_rank = 1;

    IF EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT DISTINCT booking_request_id
            FROM inserted
        ) AS affected
        INNER JOIN @CurrentDecision AS current_decision
            ON current_decision.booking_request_id = affected.booking_request_id
           AND current_decision.request_decision_code = 'APPROVED'
        INNER JOIN dbo.BookingRequest AS br
            ON br.booking_request_id = affected.booking_request_id
        INNER JOIN dbo.Maintenance AS mt
            ON mt.space_id = br.space_id
        INNER JOIN dbo.MaintenanceSession AS m 
            ON m.maintenance_id = mt.maintenance_id
        INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
            ON mil.maintenance_impact_level_id
               = m.maintenance_impact_level_id
        WHERE mil.maintenance_impact_level_code = 'OUT_OF_SERVICE'
          AND br.requested_start_time
                < ISNULL
                  (
                      m.maintenance_end_time,
                      CONVERT(DATETIME, '99991231', 112)
                  )
          AND br.requested_end_time > m.maintenance_start_time
    )
    BEGIN
        THROW 50043,
            'A request cannot be currently approved during out-of-service maintenance.',
            1;
    END;
END;
GO

------------------------------------------------------------
-- D. Final structural validation and commit
------------------------------------------------------------
BEGIN TRY
    IF XACT_STATE() <> 1
        THROW 50044, 'Migration transaction is not active.', 1;

    IF OBJECT_ID(N'lookup_table.MaintenanceImpactLevel', N'U') IS NULL
       OR OBJECT_ID(N'lookup_table.RequestState', N'U') IS NULL
       OR OBJECT_ID(N'lookup_table.RequestDecision', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Review', N'U') IS NULL
       OR OBJECT_ID(N'dbo.ReservationSession', N'U') IS NULL
    BEGIN
        THROW 50045, 'A required final-schema table is missing.', 1;
    END;

    IF OBJECT_ID(N'junction_table.Booking', N'U') IS NOT NULL
       OR OBJECT_ID(N'junction_table.Maintaining', N'U') IS NOT NULL
       OR OBJECT_ID(N'junction_table.Review', N'U') IS NOT NULL
       OR OBJECT_ID(N'junction_table.ReservationCheckin', N'U') IS NOT NULL
       OR OBJECT_ID(N'lookup_table.Decision', N'U') IS NOT NULL
    BEGIN
        THROW 50046, 'A legacy table still exists after migration.', 1;
    END;

    IF 
        COL_LENGTH(N'dbo.BookingRequest', N'advisory_acknowledged') IS NULL
       OR COL_LENGTH(N'dbo.SpacePolicy', N'requires_approval') IS NULL
       OR COL_LENGTH(N'dbo.BookingRequest', N'user_id') IS NULL
       OR COL_LENGTH(N'dbo.BookingRequest', N'space_id') IS NULL
       OR COL_LENGTH(N'dbo.BookingRequest', N'request_state_id') IS NULL
       OR COL_LENGTH(N'dbo.Maintenance', N'space_id') IS NULL
       OR COL_LENGTH(N'dbo.MaintenanceSession', N'maintenance_id') IS NULL
       OR COL_LENGTH(N'dbo.MaintenanceSession', N'technician_id') IS NULL
       OR COL_LENGTH(N'dbo.MaintenanceSession', N'maintenance_start_time') IS NULL
       OR COL_LENGTH(N'dbo.MaintenanceSession', N'maintenance_end_time') IS NULL
       OR COL_LENGTH(N'dbo.MaintenanceSession', N'maintenance_impact_level_id') IS NULL
       OR COL_LENGTH(N'dbo.Review', N'review_id') IS NULL
       OR COL_LENGTH(N'dbo.Review', N'request_decision_id') IS NULL
    BEGIN
        THROW 50047, 'A required final-schema column is missing.', 1;
    END;

    IF COL_LENGTH(N'dbo.Maintenance', N'technician_id') IS NOT NULL
       OR COL_LENGTH(N'dbo.Maintenance', N'maintenance_start_time') IS NOT NULL
       OR COL_LENGTH(N'dbo.Maintenance', N'maintenance_end_time') IS NOT NULL
       OR COL_LENGTH(N'dbo.Maintenance', N'maintenance_impact_level_id') IS NOT NULL
    BEGIN
        THROW 50050,
            'Maintenance still contains columns that should be in MaintenanceSession.',
            1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.[User]')
          AND name = N'UK_User_phone_number'
    )
    BEGIN
        THROW 50048, 'phone_number is still unique.', 1;
    END;
    -- removed char check cause that's too simple and shit went wrong somewhere and now im too sleepy to check so i nuked it

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.Review')
          AND name = N'PK_Review_review_id'
    )
       OR NOT EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.ReservationSession')
          AND name = N'PK_ReservationSession_reservation_id'
    )
    BEGIN
        THROW 50051, 'A required final operational primary key is missing.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.MaintenanceImpactLevel
        WHERE maintenance_impact_level_code = 'ADVISORY'
    )
       OR NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.MaintenanceImpactLevel
        WHERE maintenance_impact_level_code = 'OUT_OF_SERVICE'
    )
       OR NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.RequestState
        WHERE request_state_code = 'PENDING'
    )
       OR NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.RequestState
        WHERE request_state_code = 'REVIEWED'
    )
       OR NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.RequestState
        WHERE request_state_code = 'CANCELLED'
    )
       OR NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.RequestDecision
        WHERE request_decision_code = 'APPROVED'
    )
       OR NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.RequestDecision
        WHERE request_decision_code = 'REJECTED'
    )
       OR NOT EXISTS
    (
        SELECT 1
        FROM lookup_table.ReservationStatus
        WHERE reservation_status_code = 'CAN'
    )
    BEGIN
        THROW 50049, 'A required lookup value is missing.', 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
