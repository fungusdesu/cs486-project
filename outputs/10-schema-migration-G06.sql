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

    -- Add a new column to the Maintenance table to reference the maintenance impact level
    ALTER TABLE Maintenance 
    ADD maintenance_impact_level_id TINYINT NULL;

    -- Add a foreign key constraint to the BookingRequest table to reflect user acknowledgment of maintenance statuses
    ALTER TABLE BookingRequest
    ADD advisory_acknowledged BIT NULL; 


    -- Second validation: 
    -- 1. Phone number is no longer unique
    ALTER TABLE [User]
    DROP CONSTRAINT UK_User_phone_number;

    -- 2. Decompose Booking and Maintaining tables
    
    -- 2.1. Decompose Booking
    CREATE TABLE junction_table.Makes_Request (
        user_id INT NOT NULL,
        booking_request_id INT NOT NULL,
        
        CONSTRAINT PK_Makes_Request_user_id_booking_request_id
        PRIMARY KEY (user_id, booking_request_id),
        CONSTRAINT FK_Makes_Request_user_id
        FOREIGN KEY (user_id) REFERENCES [User](user_id),
        CONSTRAINT FK_Makes_Request_booking_request_id
        FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id)
    )

    CREATE TABLE junction_table.Requests_Space (
        booking_request_id INT NOT NULL,
        space_id INT NOT NULL,

        CONSTRAINT PK_Requests_Space_booking_request_id_space_id
        PRIMARY KEY (booking_request_id, space_id),
        CONSTRAINT FK_Requests_Space_booking_request_id
        FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id),
        CONSTRAINT FK_Requests_Space_space_id
        FOREIGN KEY (space_id) REFERENCES Space(space_id)
    )
    -- insert into the tables
    INSERT INTO junction_table.Makes_Request (user_id, booking_request_id)
    SELECT user_id, booking_request_id
    FROM BookingRequest;

    INSERT INTO junction_table.Requests_Space (booking_request_id, space_id)
    SELECT booking_request_id, space_id
    FROM BookingRequest;

    -- 2.2. Decompose Maintaining
    CREATE TABLE junction_table.Carries_Out (
        user_id INT NOT NULL,
        maintenance_id INT NOT NULL,

        CONSTRAINT PK_Carries_Out_user_id_maintenance_id
        PRIMARY KEY (user_id, maintenance_id),
        CONSTRAINT FK_Carries_Out_user_id
        FOREIGN KEY (user_id) REFERENCES [User](user_id),
        CONSTRAINT FK_Carries_Out_maintenance_id
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
    INSERT INTO junction_table.Carries_Out (user_id, maintenance_id)
    SELECT user_id, maintenance_id
    FROM Maintenance;   

    INSERT INTO junction_table.Services (maintenance_id, space_id)
    SELECT maintenance_id, space_id
    FROM Maintenance;

    -- 2.3. Add attribute maintenance_time_slot from Maintaining to Maintenance table
    ALTER TABLE Maintenance
    ADD maintenance_time_slot DATETIME NOT NULL;

    INSERT INTO Maintenance (maintenance_id, maintenance_time_slot)
    SELECT maintenance_id, DATEDIFF(MINUTE, maintenance_start_time, maintenance_end_time) AS maintenance_time_slot
    FROM junction_table.Maintaining;




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
