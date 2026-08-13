DROP TABLE IF EXISTS staging_phase2.AdvisoryAcknowledgements;
DROP TABLE IF EXISTS staging_phase2.Reservations;
DROP TABLE IF EXISTS staging_phase2.Reviews;
DROP TABLE IF EXISTS staging_phase2.Bookings;
DROP TABLE IF EXISTS staging_phase2.BookingRequests;
DROP TABLE IF EXISTS staging_phase2.Maintenance;
DROP TABLE IF EXISTS staging_phase2.Spaces;
DROP TABLE IF EXISTS staging_phase2.Users;
GO

IF SCHEMA_ID(N'staging_phase2') IS NOT NULL
    EXEC(N'DROP SCHEMA staging_phase2');
GO
