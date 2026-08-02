SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.ConcurrencyTestBooking', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ConcurrencyTestBooking (
        booking_id VARCHAR(20) NOT NULL PRIMARY KEY,
        space_id VARCHAR(20) NOT NULL,
        start_time DATETIME2 NOT NULL,
        end_time DATETIME2 NOT NULL,
        approved_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_ConcurrencyTestBooking_Time CHECK (end_time > start_time)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ConcurrencyTest_Unsafe
    @booking_id VARCHAR(20),
    @space_id VARCHAR(20),
    @start_time DATETIME2,
    @end_time DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.ConcurrencyTestBooking
        WHERE space_id = @space_id
          AND start_time < @end_time
          AND end_time > @start_time
    )
    BEGIN
        WAITFOR DELAY '00:00:01';
        INSERT dbo.ConcurrencyTestBooking (booking_id, space_id, start_time, end_time)
        VALUES (@booking_id, @space_id, @start_time, @end_time);
    END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ConcurrencyTest_Safe
    @booking_id VARCHAR(20),
    @space_id VARCHAR(20),
    @start_time DATETIME2,
    @end_time DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @lock_result INT;
        DECLARE @lock_resource NVARCHAR(255) = CONCAT(N'G06_BOOKING_SPACE_', @space_id);
        EXEC @lock_result = sys.sp_getapplock
            @Resource = @lock_resource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 10000;

        IF @lock_result < 0
            THROW 51001, 'Could not acquire the per-space booking lock.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.ConcurrencyTestBooking WITH (UPDLOCK, HOLDLOCK)
            WHERE space_id = @space_id
              AND start_time < @end_time
              AND end_time > @start_time
        )
            THROW 51002, 'An overlapping approved booking already exists.', 1;

        WAITFOR DELAY '00:00:01';
        INSERT dbo.ConcurrencyTestBooking (booking_id, space_id, start_time, end_time)
        VALUES (@booking_id, @space_id, @start_time, @end_time);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
