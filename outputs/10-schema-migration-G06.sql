SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION 

    -- First requirement: Create a lookup table for maintenance impact levels
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
    ('ADV', 'Avidsory'),
    ('OOS', 'Out of Service');

    -- Add a new column to the Maintenance table to reference the maintenance impact level
    ALTER TABLE Maintenance 
    ADD maintenance_impact_level_id TINYINT NULL;

    -- Add a foreign key constraint to the BookingRequest table to reflect user acknowledgment of maintenance statuses
    ALTER TABLE BookingRequest
    ADD advisory_acknowledged BIT NULL; 


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
