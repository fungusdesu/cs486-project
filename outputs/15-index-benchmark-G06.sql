USE School;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID('tempdb..#metrics') IS NOT NULL DROP TABLE #metrics;
CREATE TABLE #metrics(phase varchar(10),target varchar(30),repetition int,elapsed_ms decimal(18,3),cpu_ms bigint,logical_reads bigint);
DECLARE @term_start datetime='2023-08-01',@term_end datetime='2024-08-01',@period_start datetime='2024-02-12T10:00:00',@period_end datetime='2024-02-12T11:00:00';

IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.BookingRequest') AND name='IX_G06_P14_BookingRequest_SpaceWindow') DROP INDEX IX_G06_P14_BookingRequest_SpaceWindow ON dbo.BookingRequest;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Review') AND name='IX_G06_P14_Review_CurrentDecision') DROP INDEX IX_G06_P14_Review_CurrentDecision ON dbo.Review;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.BookingRequest') AND name='IX_G06_P15_BookingRequest_ReportStart') DROP INDEX IX_G06_P15_BookingRequest_ReportStart ON dbo.BookingRequest;

DECLARE @phase varchar(10),@rep int,@t datetime2,@cpu bigint,@reads bigint,@dummy bigint;
DECLARE @hours TABLE(space_id varchar(10),space_name nvarchar(60),total_approved_hours decimal(18,2));
DECLARE @weekday TABLE(weekday_number int,weekday_name nvarchar(30),start_hour int,approved_booking_count bigint);
DECLARE @rooms TABLE(space_id varchar(10),space_name nvarchar(60),capacity smallint,building char(1),floor tinyint,room_number tinyint);
DECLARE @fac dbo.FacilityRequirementTable;
SET @phase='baseline';
WHILE @phase IS NOT NULL
BEGIN
 SET @rep=0;
 WHILE @rep<=5
 BEGIN
  DELETE FROM @hours; SET @t=SYSUTCDATETIME(); SELECT @cpu=cpu_time,@reads=logical_reads FROM sys.dm_exec_sessions WHERE session_id=@@SPID;
  INSERT @hours EXEC dbo.USP_GetApprovedHoursPerSpace @term_start,@term_end;
  IF @rep>0 INSERT #metrics SELECT @phase,'approved-hours',@rep,DATEDIFF_BIG(MICROSECOND,@t,SYSUTCDATETIME())/1000.0,cpu_time-@cpu,logical_reads-@reads FROM sys.dm_exec_sessions WHERE session_id=@@SPID;

  DELETE FROM @weekday; SET @t=SYSUTCDATETIME(); SELECT @cpu=cpu_time,@reads=logical_reads FROM sys.dm_exec_sessions WHERE session_id=@@SPID;
  INSERT @weekday EXEC dbo.USP_GetApprovedBookingCountByWeekdayHour @term_start,@term_end;
  IF @rep>0 INSERT #metrics SELECT @phase,'weekday-hour',@rep,DATEDIFF_BIG(MICROSECOND,@t,SYSUTCDATETIME())/1000.0,cpu_time-@cpu,logical_reads-@reads FROM sys.dm_exec_sessions WHERE session_id=@@SPID;

  DELETE FROM @rooms; SET @t=SYSUTCDATETIME(); SELECT @cpu=cpu_time,@reads=logical_reads FROM sys.dm_exec_sessions WHERE session_id=@@SPID;
  INSERT @rooms EXEC dbo.USP_FindAvailableSpaces @period_start,@period_end,20,@fac;
  IF @rep>0 INSERT #metrics SELECT @phase,'room-finder',@rep,DATEDIFF_BIG(MICROSECOND,@t,SYSUTCDATETIME())/1000.0,cpu_time-@cpu,logical_reads-@reads FROM sys.dm_exec_sessions WHERE session_id=@@SPID;

  SET @t=SYSUTCDATETIME(); SELECT @cpu=cpu_time,@reads=logical_reads FROM sys.dm_exec_sessions WHERE session_id=@@SPID;
  SELECT @dummy=COUNT_BIG(*) FROM dbo.BookingRequest br JOIN lookup_table.RequestState rs ON rs.request_state_id=br.request_state_id OUTER APPLY(SELECT TOP(1) rd.request_decision_code FROM dbo.Review rv JOIN lookup_table.RequestDecision rd ON rd.request_decision_id=rv.request_decision_id WHERE rv.booking_request_id=br.booking_request_id ORDER BY rv.decision_time DESC,rv.review_id DESC) latest WHERE br.space_id='S0001' AND (rs.request_state_code='AUTO_APPROVED' OR latest.request_decision_code='APPROVED') AND br.requested_start_time<@term_end AND br.requested_end_time>@term_start;
  IF @rep>0 INSERT #metrics SELECT @phase,'conflict-check',@rep,DATEDIFF_BIG(MICROSECOND,@t,SYSUTCDATETIME())/1000.0,cpu_time-@cpu,logical_reads-@reads FROM sys.dm_exec_sessions WHERE session_id=@@SPID;
  SET @rep+=1;
 END;
 IF @phase='baseline'
 BEGIN
  CREATE NONCLUSTERED INDEX IX_G06_P14_BookingRequest_SpaceWindow ON dbo.BookingRequest(space_id,requested_start_time,requested_end_time,booking_request_id) INCLUDE(request_state_id);
  CREATE NONCLUSTERED INDEX IX_G06_P14_Review_CurrentDecision ON dbo.Review(booking_request_id,decision_time DESC,review_id DESC) INCLUDE(request_decision_id);
  CREATE NONCLUSTERED INDEX IX_G06_P15_BookingRequest_ReportStart ON dbo.BookingRequest(requested_start_time) INCLUDE(requested_end_time,space_id,request_state_id);
  UPDATE STATISTICS dbo.BookingRequest WITH FULLSCAN; UPDATE STATISTICS dbo.Review WITH FULLSCAN;
  SET @phase='indexed';
 END ELSE SET @phase=NULL;
END;
SELECT phase,target,CAST(AVG(elapsed_ms) AS decimal(18,3)) avg_elapsed_ms,MIN(elapsed_ms) min_elapsed_ms,MAX(elapsed_ms) max_elapsed_ms,AVG(cpu_ms) avg_cpu_ms,AVG(logical_reads) avg_logical_reads FROM #metrics GROUP BY phase,target ORDER BY target,phase;
SELECT @@VERSION AS sql_server_version,(SELECT COUNT_BIG(*) FROM dbo.BookingRequest) booking_request_rows,(SELECT COUNT_BIG(*) FROM dbo.Review) review_rows;
GO