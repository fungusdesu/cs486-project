SET NOCOUNT ON;
SET XACT_ABORT ON;

DROP PROCEDURE IF EXISTS dbo.usp_ConcurrencyTest_InstantApprove;
DROP PROCEDURE IF EXISTS dbo.usp_ConcurrencyTest_StaffApprove;
DROP PROCEDURE IF EXISTS dbo.usp_ConcurrencyTest_Safe;
DROP PROCEDURE IF EXISTS dbo.usp_ConcurrencyTest_Unsafe;
DROP TABLE IF EXISTS dbo.ConcurrencyTestAcknowledgement;
DROP TABLE IF EXISTS dbo.ConcurrencyTestBooking;
DROP TABLE IF EXISTS dbo.ConcurrencyTestMaintenance;

CREATE TABLE dbo.ConcurrencyTestBooking
(
    booking_id VARCHAR(20) NOT NULL PRIMARY KEY,
    space_id VARCHAR(20) NOT NULL,
    start_time DATETIME2 NOT NULL,
    end_time DATETIME2 NOT NULL,
    approval_mode VARCHAR(10) NOT NULL,
    advisory_acknowledged BIT NOT NULL,
    approved_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_ConcurrencyTestBooking_Time CHECK (end_time > start_time),
    CONSTRAINT CK_ConcurrencyTestBooking_Mode CHECK (approval_mode IN ('INSTANT', 'STAFF'))
);

CREATE TABLE dbo.ConcurrencyTestMaintenance
(
    maintenance_id VARCHAR(20) NOT NULL PRIMARY KEY,
    space_id VARCHAR(20) NOT NULL,
    start_time DATETIME2 NOT NULL,
    end_time DATETIME2 NOT NULL,
    impact VARCHAR(20) NOT NULL,
    CONSTRAINT CK_ConcurrencyTestMaintenance_Time CHECK (end_time > start_time),
    CONSTRAINT CK_ConcurrencyTestMaintenance_Impact CHECK (impact IN ('ADVISORY', 'OUT_OF_SERVICE'))
);

CREATE TABLE dbo.ConcurrencyTestAcknowledgement
(
    booking_id VARCHAR(20) NOT NULL,
    maintenance_id VARCHAR(20) NOT NULL,
    CONSTRAINT PK_ConcurrencyTestAcknowledgement PRIMARY KEY (booking_id, maintenance_id),
    CONSTRAINT FK_ConcurrencyTestAcknowledgement_Booking FOREIGN KEY (booking_id)
        REFERENCES dbo.ConcurrencyTestBooking(booking_id),
    CONSTRAINT FK_ConcurrencyTestAcknowledgement_Maintenance FOREIGN KEY (maintenance_id)
        REFERENCES dbo.ConcurrencyTestMaintenance(maintenance_id)
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_ConcurrencyTest_Unsafe
    @booking_id VARCHAR(20),
    @space_id VARCHAR(20),
    @start_time DATETIME2,
    @end_time DATETIME2,
    @advisory_acknowledged BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ConcurrencyTestBooking
        WHERE space_id = @space_id
          AND start_time < @end_time
          AND end_time > @start_time
    )
    BEGIN
        WAITFOR DELAY '00:00:00.200';
        INSERT dbo.ConcurrencyTestBooking
            (booking_id, space_id, start_time, end_time, approval_mode, advisory_acknowledged)
        VALUES
            (@booking_id, @space_id, @start_time, @end_time, 'STAFF', @advisory_acknowledged);
    END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ConcurrencyTest_Safe
    @booking_id VARCHAR(20),
    @space_id VARCHAR(20),
    @start_time DATETIME2,
    @end_time DATETIME2,
    @approval_mode VARCHAR(10),
    @advisory_acknowledged BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @end_time <= @start_time
        THROW 51000, 'Booking end time must be after start time.', 1;
    IF @approval_mode NOT IN ('INSTANT', 'STAFF')
        THROW 51001, 'Unknown approval mode.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @lock_result INT;
        DECLARE @resource NVARCHAR(255) = CONCAT(N'G06_BOOKING_SPACE_', @space_id);
        EXEC @lock_result = sys.sp_getapplock
            @Resource = @resource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 10000;
        IF @lock_result < 0
            THROW 51002, 'Could not acquire the per-space booking lock.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ConcurrencyTestMaintenance WITH (UPDLOCK, HOLDLOCK)
            WHERE space_id = @space_id
              AND impact = 'OUT_OF_SERVICE'
              AND start_time < @end_time
              AND end_time > @start_time
        )
            THROW 51003, 'Out-of-service maintenance blocks this booking.', 1;

        IF @advisory_acknowledged = 0
           AND EXISTS
           (
               SELECT 1
               FROM dbo.ConcurrencyTestMaintenance WITH (UPDLOCK, HOLDLOCK)
               WHERE space_id = @space_id
                 AND impact = 'ADVISORY'
                 AND start_time < @end_time
                 AND end_time > @start_time
           )
            THROW 51004, 'Active advisory maintenance must be acknowledged.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ConcurrencyTestBooking WITH (UPDLOCK, HOLDLOCK)
            WHERE space_id = @space_id
              AND start_time < @end_time
              AND end_time > @start_time
        )
            THROW 51005, 'Overlapping approved booking exists.', 1;

        WAITFOR DELAY '00:00:00.200';
        INSERT dbo.ConcurrencyTestBooking
            (booking_id, space_id, start_time, end_time, approval_mode, advisory_acknowledged)
        VALUES
            (@booking_id, @space_id, @start_time, @end_time, @approval_mode, @advisory_acknowledged);

        INSERT dbo.ConcurrencyTestAcknowledgement (booking_id, maintenance_id)
        SELECT @booking_id, maintenance_id
        FROM dbo.ConcurrencyTestMaintenance
        WHERE space_id = @space_id
          AND impact = 'ADVISORY'
          AND start_time < @end_time
          AND end_time > @start_time;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ConcurrencyTest_InstantApprove
    @booking_id VARCHAR(20),
    @space_id VARCHAR(20),
    @start_time DATETIME2,
    @end_time DATETIME2,
    @advisory_acknowledged BIT = 0
AS
BEGIN
    EXEC dbo.usp_ConcurrencyTest_Safe
        @booking_id = @booking_id,
        @space_id = @space_id,
        @start_time = @start_time,
        @end_time = @end_time,
        @approval_mode = 'INSTANT',
        @advisory_acknowledged = @advisory_acknowledged;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ConcurrencyTest_StaffApprove
    @booking_id VARCHAR(20),
    @space_id VARCHAR(20),
    @start_time DATETIME2,
    @end_time DATETIME2,
    @advisory_acknowledged BIT = 0
AS
BEGIN
    EXEC dbo.usp_ConcurrencyTest_Safe
        @booking_id = @booking_id,
        @space_id = @space_id,
        @start_time = @start_time,
        @end_time = @end_time,
        @approval_mode = 'STAFF',
        @advisory_acknowledged = @advisory_acknowledged;
END;
GO