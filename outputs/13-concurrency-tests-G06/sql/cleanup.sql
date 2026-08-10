SET NOCOUNT ON;
SET XACT_ABORT ON;

DROP PROCEDURE IF EXISTS dbo.usp_ConcurrencyTest_InstantApprove;
DROP PROCEDURE IF EXISTS dbo.usp_ConcurrencyTest_StaffApprove;
DROP PROCEDURE IF EXISTS dbo.usp_ConcurrencyTest_Safe;
DROP PROCEDURE IF EXISTS dbo.usp_ConcurrencyTest_Unsafe;
DROP TABLE IF EXISTS dbo.ConcurrencyTestAcknowledgement;
DROP TABLE IF EXISTS dbo.ConcurrencyTestBooking;
DROP TABLE IF EXISTS dbo.ConcurrencyTestMaintenance;
GO
