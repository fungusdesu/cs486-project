USE School;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    --------------------------------------------------------------------------
    -- A. Validate the old relationship data before changing the schema
    --------------------------------------------------------------------------

    IF EXISTS
    (
        SELECT b.booking_request_id
        FROM junction_table.Booking AS b
        GROUP BY b.booking_request_id
        HAVING COUNT(*) <> 1
    )
    BEGIN
        ;THROW 50001,
              'Each booking request must have exactly one Booking row before migration.',
              1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM BookingRequest AS br
        LEFT JOIN junction_table.Booking AS b
            ON b.booking_request_id = br.booking_request_id
        WHERE b.booking_request_id IS NULL
    )
    BEGIN
        ;THROW 50002,
              'A BookingRequest without a Booking relationship cannot be migrated.',
              1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM Maintenance AS m
        LEFT JOIN junction_table.Maintaining AS mt
            ON mt.maintenance_id = m.maintenance_id
        WHERE mt.maintenance_id IS NULL
    )
    BEGIN
        ;THROW 50003,
              'A Maintenance row without a Maintaining relationship cannot be migrated.',
              1;
    END;



    --------------------------------------------------------------------------
    -- B. Temporarily remove triggers that reference Booking or Maintaining
    --------------------------------------------------------------------------

    DROP TRIGGER IF EXISTS dbo.trg_booking_request_capacity;
    DROP TRIGGER IF EXISTS dbo.trg_maintenance_result_note;
    DROP TRIGGER IF EXISTS dbo.trg_booker_acc_status;
    DROP TRIGGER IF EXISTS dbo.trg_booking_requested_time_fit_policy;
    DROP TRIGGER IF EXISTS dbo.trg_space_maintenance_status;
    DROP TRIGGER IF EXISTS dbo.trg_no_overlapping_approved_requests;
    DROP TRIGGER IF EXISTS dbo.trg_no_approved_review_during_maintaining;
    DROP TRIGGER IF EXISTS dbo.trg_checked_in_space_in_use;

    --------------------------------------------------------------------------
    -- C. Requirement 1: maintenance impact and instant booking
    --------------------------------------------------------------------------

    CREATE TABLE lookup_table.MaintenanceImpactLevel
    (
        maintenance_impact_level_id TINYINT IDENTITY(1, 1),
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

    INSERT INTO lookup_table.MaintenanceImpactLevel
    (
        maintenance_impact_level_code,
        maintenance_impact_level_name
    )
    VALUES
        ('ADVISORY', N'Advisory'),
        ('OUT_OF_SERVICE', N'Out-of-Service');

    ALTER TABLE dbo.Maintenance
    ADD maintenance_impact_level_id TINYINT NULL;

    -- Compile this block only after the new column exists.
    EXEC sys.sp_executesql N'
        UPDATE dbo.Maintenance
        SET maintenance_impact_level_id =
        (
            SELECT mil.maintenance_impact_level_id
            FROM lookup_table.MaintenanceImpactLevel AS mil
            WHERE mil.maintenance_impact_level_code = ''OUT_OF_SERVICE''
        );

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Maintenance
            WHERE maintenance_impact_level_id IS NULL
        )
        BEGIN
            THROW 50005, ''Maintenance impact-level backfill failed.'', 1;
        END;

        ALTER TABLE dbo.Maintenance
        ALTER COLUMN maintenance_impact_level_id TINYINT NOT NULL;

        ALTER TABLE dbo.Maintenance
        ADD CONSTRAINT FK_Maintenance_impact_level
            FOREIGN KEY (maintenance_impact_level_id)
            REFERENCES lookup_table.MaintenanceImpactLevel
                       (maintenance_impact_level_id);
    ';

    ALTER TABLE BookingRequest
    ADD advisory_acknowledged BIT NOT NULL
        CONSTRAINT DF_BookingRequest_advisory_acknowledged DEFAULT (0);

    ALTER TABLE SpacePolicy
    ADD requires_approval BIT NOT NULL
        CONSTRAINT DF_SpacePolicy_requires_approval DEFAULT (1);

    ------------------------------------------------------------------
    -- Requirement 1.2: add 'Cancelled' to ReservationStatus
    ------------------------------------------------------------------
    INSERT INTO lookup_table.ReservationStatus 
    (reservation_status_code, reservation_status_name) 
    VALUES 
    ('CAN', 'Cancelled');

    --------------------------------------------------------------------------
    -- D. Requirement 2.1: phone_number is no longer a candidate key
    --------------------------------------------------------------------------

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

    --------------------------------------------------------------------------
    -- E. Requirement 2.2: implement 1:N relationships with direct foreign keys
    --
    -- User 1 ---- N BookingRequest N ---- 1 Space
    -- User 1 ---- N Maintenance    N ---- 1 Space
    --------------------------------------------------------------------------

    ALTER TABLE dbo.BookingRequest
    ADD user_id VARCHAR(8) NULL,
        space_id VARCHAR(10) NULL;

    -- Defer compilation until user_id and space_id exist.
    EXEC sys.sp_executesql N'
        UPDATE br
        SET br.user_id = b.user_id,
            br.space_id = b.space_id
        FROM dbo.BookingRequest AS br
        INNER JOIN junction_table.Booking AS b
            ON b.booking_request_id = br.booking_request_id;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.BookingRequest
            WHERE user_id IS NULL OR space_id IS NULL
        )
        BEGIN
            THROW 50006, ''Booking relationship backfill failed.'', 1;
        END;

        ALTER TABLE dbo.BookingRequest
        ALTER COLUMN user_id VARCHAR(8) NOT NULL;

        ALTER TABLE dbo.BookingRequest
        ALTER COLUMN space_id VARCHAR(10) NOT NULL;

        ALTER TABLE dbo.BookingRequest
        ADD CONSTRAINT FK_BookingRequest_user
                FOREIGN KEY (user_id) REFERENCES dbo.[User](user_id),
            CONSTRAINT FK_BookingRequest_space
                FOREIGN KEY (space_id) REFERENCES dbo.Space(space_id);
    ';

    ALTER TABLE dbo.Maintenance
    ADD technician_id VARCHAR(8) NULL,
        space_id VARCHAR(10) NULL,
        maintenance_start_time DATETIME NULL,
        maintenance_end_time DATETIME NULL;

    -- Defer compilation until the four new columns exist.
    EXEC sys.sp_executesql N'
        UPDATE m
        SET m.technician_id = mt.technician_id,
            m.space_id = mt.space_id,
            m.maintenance_start_time = mt.maintenance_start_time,
            m.maintenance_end_time = mt.maintenance_end_time
        FROM dbo.Maintenance AS m
        INNER JOIN junction_table.Maintaining AS mt
            ON mt.maintenance_id = m.maintenance_id;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Maintenance
            WHERE technician_id IS NULL
               OR space_id IS NULL
               OR maintenance_start_time IS NULL
        )
        BEGIN
            THROW 50007, ''Maintaining relationship backfill failed.'', 1;
        END;

        ALTER TABLE dbo.Maintenance
        ALTER COLUMN technician_id VARCHAR(8) NOT NULL;

        ALTER TABLE dbo.Maintenance
        ALTER COLUMN space_id VARCHAR(10) NOT NULL;

        ALTER TABLE dbo.Maintenance
        ALTER COLUMN maintenance_start_time DATETIME NOT NULL;

        ALTER TABLE dbo.Maintenance
        ADD CONSTRAINT FK_Maintenance_technician
                FOREIGN KEY (technician_id) REFERENCES dbo.[User](user_id),
            CONSTRAINT FK_Maintenance_space
                FOREIGN KEY (space_id) REFERENCES dbo.Space(space_id),
            CONSTRAINT CHK_Maintenance_time_order
                CHECK
                (
                    maintenance_end_time IS NULL
                    OR maintenance_end_time > maintenance_start_time
                );
    ';

    --------------------------------------------------------------------------
    -- F. Validate the copied data before removing the old tables
    --------------------------------------------------------------------------

    EXEC sys.sp_executesql N'
        IF EXISTS
        (
            SELECT br.booking_request_id
            FROM dbo.BookingRequest AS br
            INNER JOIN junction_table.Booking AS b
                ON b.booking_request_id = br.booking_request_id
            WHERE br.user_id <> b.user_id
               OR br.space_id <> b.space_id
        )
        BEGIN
            THROW 50008, ''Booking data changed during decomposition.'', 1;
        END;

        IF EXISTS
        (
            SELECT m.maintenance_id
            FROM dbo.Maintenance AS m
            INNER JOIN junction_table.Maintaining AS mt
                ON mt.maintenance_id = m.maintenance_id
            WHERE m.technician_id <> mt.technician_id
               OR m.space_id <> mt.space_id
               OR m.maintenance_start_time <> mt.maintenance_start_time
               OR ISNULL(m.maintenance_end_time, ''19000101'')
                    <> ISNULL(mt.maintenance_end_time, ''19000101'')
        )
        BEGIN
            THROW 50009, ''Maintenance data changed during decomposition.'', 1;
        END;
    ';

    DROP TABLE junction_table.Booking;
    DROP TABLE junction_table.Maintaining;

    --------------------------------------------------------------------------
    -- G. Recreate affected business-rule triggers for the final schema
    --------------------------------------------------------------------------

    EXEC('
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
            INNER JOIN dbo.Space AS s ON s.space_id = i.space_id
            WHERE i.expected_participants > s.capacity
        )
        BEGIN
            THROW 51001, ''Expected participants cannot exceed the space capacity.'', 1;
        END;
    END;');


    EXEC('
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
            INNER JOIN dbo.[User] AS u ON u.user_id = i.user_id
            INNER JOIN lookup_table.UserStatus AS us
                ON us.user_status_id = u.user_status_id
            WHERE us.user_status_code <> ''ACTIVE''
        )
        BEGIN
            THROW 51002, ''Only a user with an active account can book a space.'', 1;
        END;
    END;');


    EXEC('
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
            INNER JOIN dbo.Space AS s ON s.space_id = i.space_id
            INNER JOIN dbo.SpacePolicy AS sp
                ON sp.space_policy_id = s.space_policy_id
            WHERE DATEDIFF(MINUTE, i.requested_start_time,
                                   i.requested_end_time)
                    NOT BETWEEN sp.min_duration_minutes
                            AND sp.max_duration_minutes
        )
        BEGIN 
            THROW 51003, ''Requested duration violates the selected space policy.'', 1;
        END;
    END;');


    EXEC('
    CREATE OR ALTER TRIGGER dbo.trg_booking_maintenance_eligibility
    ON dbo.BookingRequest
    AFTER INSERT, UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;

        -- An overlapping OUT_OF_SERVICE window cannot be booked.
        IF EXISTS
        (
            SELECT 1
            FROM inserted AS i
            INNER JOIN dbo.Maintenance AS m ON m.space_id = i.space_id
            INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
                ON mil.maintenance_impact_level_id
                   = m.maintenance_impact_level_id
            WHERE i.requested_start_time
                    < ISNULL(m.maintenance_end_time, CONVERT(DATETIME, ''99991231''))
              AND i.requested_end_time > m.maintenance_start_time
              AND mil.maintenance_impact_level_code = ''OUT_OF_SERVICE''
        )
        BEGIN
            THROW 51004, ''The space is out of service during the requested time.'', 1;
        END;

        -- An overlapping ADVISORY window requires explicit acknowledgement.
        IF EXISTS
        (
            SELECT 1
            FROM inserted AS i
            INNER JOIN dbo.Maintenance AS m ON m.space_id = i.space_id
            INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
                ON mil.maintenance_impact_level_id
                   = m.maintenance_impact_level_id
            WHERE i.requested_start_time
                    < ISNULL(m.maintenance_end_time, CONVERT(DATETIME, ''99991231''))
              AND i.requested_end_time > m.maintenance_start_time
              AND mil.maintenance_impact_level_code = ''ADVISORY''
              AND i.advisory_acknowledged = 0
        )
        BEGIN
            THROW 51005, ''Advisory maintenance must be acknowledged before booking.'', 1;
        END;
    END;');


    EXEC('
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
            WHERE (i.result_note IS NOT NULL OR i.maintenance_end_time IS NOT NULL)
              AND ms.maintenance_status_code <> ''COMPLETED''
        )
        BEGIN
            THROW 51006, ''A result note or end time requires completed maintenance.'', 1;
        END;
    END;');


    EXEC('
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
            INNER JOIN dbo.Maintenance AS m ON m.space_id = i.space_id
            INNER JOIN lookup_table.MaintenanceStatus AS ms
                ON ms.maintenance_status_id = m.maintenance_status_id
            INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
                ON mil.maintenance_impact_level_id
                   = m.maintenance_impact_level_id
            INNER JOIN lookup_table.SpaceStatus AS ss
                ON ss.space_status_id = i.space_status_id
            WHERE ms.maintenance_status_code <> ''COMPLETED''
              AND mil.maintenance_impact_level_code = ''OUT_OF_SERVICE''
              AND ss.space_status_code <> ''UNDER_MAINTENANCE''
        )
        BEGIN
            THROW 51007, ''Out-of-service maintenance requires under-maintenance space status.'', 1;
        END;
    END;');


    EXEC('
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
            INNER JOIN dbo.Space AS s ON s.space_id = br.space_id
            INNER JOIN lookup_table.ReservationStatus AS rs
                ON rs.reservation_status_id = i.reservation_status_id
            INNER JOIN lookup_table.SpaceStatus AS ss
                ON ss.space_status_id = s.space_status_id
            WHERE rs.reservation_status_code = ''CHECKED_IN''
              AND ss.space_status_code <> ''IN_USE''
        )
        BEGIN
            THROW 51008, ''A checked-in reservation requires in-use space status.'', 1;
        END;
    END;');


    EXEC('
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
            WHERE d1.decision_code = ''APPROVED''
              AND d2.decision_code = ''APPROVED''
              AND br1.requested_start_time < br2.requested_end_time
              AND br1.requested_end_time > br2.requested_start_time
        )
        BEGIN
            THROW 51009, ''Two approved requests for one space cannot overlap.'', 1;
        END;
    END;');


    EXEC('
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
            INNER JOIN dbo.Maintenance AS m ON m.space_id = br.space_id
            INNER JOIN lookup_table.MaintenanceImpactLevel AS mil
                ON mil.maintenance_impact_level_id
                   = m.maintenance_impact_level_id
            WHERE d.decision_code = ''APPROVED''
              AND mil.maintenance_impact_level_code = ''OUT_OF_SERVICE''
              AND br.requested_start_time
                    < ISNULL(m.maintenance_end_time,
                             CONVERT(DATETIME, ''99991231''))
              AND br.requested_end_time > m.maintenance_start_time
        )
        BEGIN
            THROW 51010, ''A request cannot be approved during out-of-service maintenance.'', 1;
        END;
    END;');


    --------------------------------------------------------------------------
    -- H. Final automated validation
    --------------------------------------------------------------------------

    EXEC sys.sp_executesql N'
        IF EXISTS
        (
            SELECT 1
            FROM dbo.BookingRequest
            WHERE user_id IS NULL OR space_id IS NULL
        )
        BEGIN
            THROW 50010, ''Final BookingRequest validation failed.'', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Maintenance
            WHERE technician_id IS NULL
               OR space_id IS NULL
               OR maintenance_start_time IS NULL
               OR maintenance_impact_level_id IS NULL
        )
        BEGIN
            THROW 50011, ''Final Maintenance validation failed.'', 1;
        END;
    ';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
