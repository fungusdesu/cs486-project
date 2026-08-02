SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION 

    -- Business requirement: Refine the maintenance impact levels to include a new level for advisory maintenance. This will allow users to acknowledge advisory maintenance statuses in the BookingRequest table.
    CREATE TABLE lookup_table.MaintenanceImpactLevel (
        impact_level_id TININT IDENTITY(1,1),
        impact_level_code VARCHAR(20) NOT NULL,
        impact_level_name NVARCHAR(50) NOT NULL,

        CONSTRAINT PK_MIL_impact_level_id 
        PRIMARY KEY (impact_level_id),
        CONSTRAINT UK_MIL_impact_level_code
        UNIQUE (impact_level_code),
        CONSTRAINT CHK_MIL_impact_level_code_uppercase
        CHECK (impact_level_code COLLATE SQL_Latin1_General_CP1_UPPER = UPPER(impact_level_code) )
    )

    INSERT INTO lookup_table.MaintenanceImpactLevel (impact_level_code, impact_level_name)
    VALUES
    ('ADV', 'Advisory'),
    ('OOS', 'Out of Service');

        -- Validation: confirm the current Maintenance data is ready for the schema change.
        SELECT 'Maintenance' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN reporter_id IS NULL THEN 1 ELSE 0 END) AS missing_reporter_rows
        FROM Maintenance;

    -- Add a new column to the Maintenance table to reference the maintenance impact level
    ALTER TABLE Maintenance 
    ADD maintenance_impact_level_id TINYINT NULL;

        -- Validation: confirm BookingRequest rows still satisfy the current time-order assumption before adding the new column.
        SELECT 'BookingRequest' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN requested_end_time <= requested_start_time THEN 1 ELSE 0 END) AS invalid_time_range_rows
        FROM BookingRequest;

    -- Add a foreign key constraint to the BookingRequest table to reflect user acknowledgment of maintenance statuses
    ALTER TABLE BookingRequest
    ADD advisory_acknowledged BIT NULL; 


    -- Second validation: 
    -- 1. Phone number is no longer unique
        SELECT 'User' AS table_name, COUNT(*) AS total_rows,
            COUNT(*) - COUNT(DISTINCT phone_number) AS duplicate_phone_numbers
        FROM [User];

    ALTER TABLE [User]
    DROP CONSTRAINT UK_User_phone_number;

    -- 2. Decompose Booking and Maintaining tables
    
    -- 2.1. Decompose Booking
    SELECT 'BookingRequest' AS table_name, COUNT(*) AS total_rows,
           COUNT(*) - COUNT(DISTINCT booking_request_id) AS duplicate_booking_request_ids
    FROM BookingRequest;

    CREATE TABLE junction_table.MakesRequest (
        user_id INT NOT NULL,
        booking_request_id INT NOT NULL,
        
        CONSTRAINT PK_MakesRequest_user_id_booking_request_id
        PRIMARY KEY (user_id, booking_request_id),
        CONSTRAINT FK_MakesRequest_user_id
        FOREIGN KEY (user_id) REFERENCES [User](user_id),
        CONSTRAINT FK_MakesRequest_booking_request_id
        FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id)
    )

    CREATE TABLE junction_table.RequestsSpace (
        booking_request_id INT NOT NULL,
        space_id INT NOT NULL,

        CONSTRAINT PK_RequestsSpace_booking_request_id_space_id
        PRIMARY KEY (booking_request_id, space_id),
        CONSTRAINT FK_RequestsSpace_booking_request_id
        FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id),
        CONSTRAINT FK_RequestsSpace_space_id
        FOREIGN KEY (space_id) REFERENCES Space(space_id)
    )
    -- insert into the tables
    INSERT INTO junction_table.MakesRequest (user_id, booking_request_id)
    SELECT user_id, booking_request_id
    FROM BookingRequest;

    INSERT INTO junction_table.RequestsSpace (booking_request_id, space_id)
    SELECT booking_request_id, space_id
    FROM BookingRequest;

    -- 2.2. Decompose Maintaining
    -- Validation: confirm the current Maintenance data is ready for the schema change.
    SELECT 'Maintenance' AS table_name, COUNT(*) AS total_rows,
           SUM(CASE WHEN maintenance_status_id IS NULL THEN 1 ELSE 0 END) AS missing_status_rows
    FROM Maintenance;

    CREATE TABLE junction_table.CarriesOut (
        user_id INT NOT NULL,
        maintenance_id INT NOT NULL,

        CONSTRAINT PK_CarriesOut_user_id_maintenance_id
        PRIMARY KEY (user_id, maintenance_id),
        CONSTRAINT FK_CarriesOut_user_id
        FOREIGN KEY (user_id) REFERENCES [User](user_id),
        CONSTRAINT FK_CarriesOut_maintenance_id
        FOREIGN KEY (maintenance_id) REFERENCES Maintenance(maintenance_id)
    )

    CREATE TABLE junction_table.Services (
        maintenance_id INT NOT NULL,
        space_id INT NOT NULL,

        CONSTRAINT PK_Services_maintenance_id_space_id
        PRIMARY KEY (maintenance_id, space_id),
        CONSTRAINT FK_Services_maintenance_id
        FOREIGN KEY (maintenance_id) REFERENCES Maintenance(maintenance_id),
        CONSTRAINT FK_Services_space_id
        FOREIGN KEY (space_id) REFERENCES Space(space_id)
    )

    -- insert into the tables
    INSERT INTO junction_table.CarriesOut (user_id, maintenance_id)
    SELECT user_id, maintenance_id
    FROM Maintenance;   

    INSERT INTO junction_table.Services (maintenance_id, space_id)
    SELECT maintenance_id, space_id
    FROM Maintenance;

    -- 2.3. Add attribute maintenance_time_slot from Maintaining to Maintenance table
    -- Validation: confirm the current Maintaining data is ready for the schema change.
        SELECT 'junction_table.Maintaining' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN maintenance_end_time IS NOT NULL AND maintenance_end_time <= maintenance_start_time THEN 1 ELSE 0 END) AS invalid_time_range_rows
        FROM junction_table.Maintaining;

    ALTER TABLE Maintenance
    ADD maintenance_time_slot DATETIME NOT NULL;

    INSERT INTO Maintenance (maintenance_id, maintenance_time_slot)
    SELECT maintenance_id, DATEDIFF(MINUTE, maintenance_start_time, maintenance_end_time) AS maintenance_time_slot
    FROM junction_table.Maintaining;

    -- 3. Decompose Decision table
    CREATE TABLE lookup_table.RequestState (
        request_state_id TINYINT IDENTITY(1,1),
        request_state_code VARCHAR(20) NOT NULL,
        request_state_name NVARCHAR(50) NOT NULL,

        CONSTRAINT PK_RequestState_request_state_id 
        PRIMARY KEY (request_state_id),
        CONSTRAINT UK_RequestState_request_state_code
        UNIQUE (request_state_code),
        CONSTRAINT CHK_RequestState_request_state_code_uppercase
        CHECK (request_state_code COLLATE SQL_Latin1_General_CP1_UPPER = UPPER(request_state_code) )
    )

    INSERT INTO lookup_table.RequestState (request_state_code, request_state_name)
    VALUES
    ('PEN', 'Pending'),
    ('REV', 'Reviewed'),
    ('CAN', 'Cancelled');

        -- Validation: confirm the current BookingRequest data is ready for the schema change.
        SELECT 'BookingRequest' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN booking_request_id IS NULL THEN 1 ELSE 0 END) AS missing_booking_request_ids
        FROM BookingRequest;

    ALTER TABLE BookingRequest
    ADD request_state_id TINYINT NULL;

    CREATE TABLE lookup_table.RequestDecision (
        request_decision_id TINYINT IDENTITY(1,1),
        request_decision_code VARCHAR(20) NOT NULL,
        request_decision_name NVARCHAR(50) NOT NULL,

        CONSTRAINT PK_RequestDecision_request_decision_id 
        PRIMARY KEY (request_decision_id),
        CONSTRAINT UK_RequestDecision_request_decision_code
        UNIQUE (request_decision_code),
        CONSTRAINT CHK_RequestDecision_request_decision_code_uppercase
        CHECK (request_decision_code COLLATE SQL_Latin1_General_CP1_UPPER = UPPER(request_decision_code) )
    )
    INSERT INTO lookup_table.RequestDecision (request_decision_code, request_decision_name)
    VALUES
    ('APP', 'Approved'),
    ('REJ', 'Rejected');
    -- Validation: confirm the current Review data is ready for the schema change.
        SELECT 'Review' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN booking_request_id IS NULL THEN 1 ELSE 0 END) AS missing_booking_request_ids
        FROM Review;

    ALTER TABLE Review
    ADD request_decision_id TINYINT NULL;

    -- 4. Modification to the Review table: adding attribute review_id
    -- Validation: confirm the current Review data is ready for the schema change.
        SELECT 'Review' AS table_name, COUNT(*) AS total_rows,
            COUNT(*) - COUNT(DISTINCT booking_request_id) AS duplicate_booking_request_links
        FROM Review;

    ALTER TABLE Review
    ADD review_id VARCHAR(9) PRIMARY KEY;
    ALTER TABLE Review
    ADD CONSTRAINT CHK_Review_review_id_format
    CHECK (
        review_id COLLATE SQL_Latin1_General_100_BIN2 
        LIKE '[a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]-[a-z0-9][a-z0-9][a-z0-9][a-z0-9]'
    )

    -- 5. Decompose BookingRequest and [User]'s relationships

    CREATE TABLE junction_table.Evaluates (
        review_id VARCHAR(9) NOT NULL,
        booking_request_id VARCHAR(8) NOT NULL,
        CONSTRAINT PK_Evaluates_review_id_booking_request_id
        PRIMARY KEY (review_id, booking_request_id),
        CONSTRAINT FK_Evaluates_review_id
        FOREIGN KEY (review_id) REFERENCES Review(review_id),
        CONSTRAINT FK_Evaluates_booking_request_id
        FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id)
    )

    CREATE TABLE junction_table.Determines (
        user_id VARCHAR(8) NOT NULL,
        review_id VARCHAR(9) NOT NULL,
        CONSTRAINT PK_Determines_user_id_review_id
        PRIMARY KEY (user_id, review_id),
        CONSTRAINT FK_Determines_user_id
        FOREIGN KEY (user_id) REFERENCES [User](user_id),
        CONSTRAINT FK_Determines_review_id
        FOREIGN KEY (review_id) REFERENCES Review(review_id)
    )

    -- Insert into the tables
    INSERT INTO junction_table.Evaluates (review_id, booking_request_id)
    SELECT review_id, booking_request_id
    FROM Review;

    INSERT INTO junction_table.Determines (user_id, review_id)
    SELECT b.user_id, r.review_id
    FROM Review r
    JOIN junction_table.Booking b ON r.booking_request_id = b.booking_request_id;

    -- 6. Update data type of certain columns to accommodate new requirements
    -- Validation: confirm the current data is ready for the schema change.
        SELECT 'User' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN LEN(user_id) <> 8 THEN 1 ELSE 0 END) AS invalid_user_id_length_rows
        FROM [User];

    ALTER TABLE [User]
    ALTER COLUMN user_id CHAR(8) NOT NULL;
    -- Validation: confirm the current data is ready for the schema change.
        SELECT 'BookingRequest' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN LEN(booking_request_id) <> 8 THEN 1 ELSE 0 END) AS invalid_booking_request_id_length_rows
        FROM BookingRequest;

    ALTER TABLE BookingRequest
    ALTER COLUMN booking_request_id CHAR(8) NOT NULL; 
    -- Validation: confirm the current data is ready for the schema change.
        SELECT 'Review' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN LEN(review_id) <> 9 THEN 1 ELSE 0 END) AS invalid_review_id_length_rows
        FROM Review;

    ALTER TABLE Review
    ALTER COLUMN review_id CHAR(9) NOT NULL;
    -- Validation: confirm the current data is ready for the schema change.
        SELECT 'Reservation' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN LEN(reservation_id) <> 8 THEN 1 ELSE 0 END) AS invalid_reservation_id_length_rows
        FROM Reservation;

    ALTER TABLE Reservation
    ALTER COLUMN reservation_id CHAR(8) NOT NULL;
    -- Validation: confirm the current data is ready for the schema change.
        SELECT 'Maintenance' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN LEN(maintenance_id) <> 6 THEN 1 ELSE 0 END) AS invalid_maintenance_id_length_rows
        FROM Maintenance;

    ALTER TABLE Maintenance
    ALTER COLUMN maintenance_id CHAR(6) NOT NULL;
    -- Validation: confirm the current data is ready for the schema change.
        SELECT 'SpacePolicy' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN LEN(space_policy_id) <> 5 THEN 1 ELSE 0 END) AS invalid_space_policy_id_length_rows
        FROM SpacePolicy;

    ALTER TABLE SpacePolicy
    ALTER COLUMN space_policy_id CHAR(5) NOT NULL;

    -- 7. Modify ReservationCheckIn 
    -- 7.1. Rename table ReservationCheckIn to ReservationSession, add a new column reservation_session_id as primary key, and drop constraint on existing primary key
    -- Validation: confirm the current ReservationCheckIn data is ready for the schema change.
        SELECT 'junction_table.ReservationCheckIn' AS table_name, COUNT(*) AS total_rows,
            SUM(CASE WHEN actual_end_time IS NOT NULL AND actual_end_time <= actual_start_time THEN 1 ELSE 0 END) AS invalid_time_range_rows
        FROM junction_table.ReservationCheckIn;

    EXEC sp_rename 'junction_table.ReservationCheckIn', 'ReservationSession';

    ALTER TABLE junction_table.ReservationSession
    ADD reservation_session_id CHAR(8) NOT NULL PRIMARY KEY;
    ALTER TABLE junction_table.ReservationSession
    DROP CONSTRAINT PK_ReservationCheckIn_user_id_rid_aid_ciuid;
    
    -- 7.2. Decompose ReservationSession table's relationships with Reservation and [User] tables
    CREATE TABLE junction_table.Attends (
        user_id CHAR(8) NOT NULL,
        reservation_id CHAR(8) NOT NULL,
        CONSTRAINT PK_Attends_user_id_reservation_id
        PRIMARY KEY (user_id, reservation_id),
        CONSTRAINT FK_Attends_user_id
        FOREIGN KEY (user_id) REFERENCES [User](user_id),
        CONSTRAINT FK_Attends_reservation_id
        FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id)
    )

    CREATE TABLE junction_table.ChecksIn (
        user_id CHAR(8) NOT NULL,
        reservation_id CHAR(8) NOT NULL,
        CONSTRAINT PK_ChecksIn_user_id_reservation_id
        PRIMARY KEY (user_id, reservation_id),
        CONSTRAINT FK_ChecksIn_user_id
        FOREIGN KEY (user_id) REFERENCES [User](user_id),
        CONSTRAINT FK_ChecksIn_reservation_id
        FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id)
    )
    -- insert into the tables
    INSERT INTO junction_table.Attends (user_id, reservation_id)
    SELECT user_id, reservation_id
    FROM junction_table.ReservationSession;

    INSERT INTO junction_table.ChecksIn (user_id, reservation_id)
    SELECT user_id, reservation_id
    FROM junction_table.ReservationSession;

    CREATE TABLE junction_table.FromReservation(
        reservation_id CHAR(8) NOT NULL,
        reservation_session_id CHAR(8) NOT NULL,
        CONSTRAINT PK_FromReservation_reservation_id_reservation_session_id
        PRIMARY KEY (reservation_id, reservation_session_id),
        CONSTRAINT FK_FromReservation_reservation_id
        FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id),
        CONSTRAINT FK_FromReservation_reservation_session_id
        FOREIGN KEY (reservation_session_id) REFERENCES junction_table.ReservationSession(reservation_session_id)
    )


    COMMIT TRANSACTION;
END TRY
BEGIN CATCH 
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    SELECT 
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();

    RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;
