USE School;
GO
SET NOCOUNT ON;
GO
/* G06 Phase 2 analytical procedures. Approved means AUTO_APPROVED or the
   latest Review decision is APPROVED. All time ranges are half-open [start,end). */

CREATE OR ALTER PROCEDURE dbo.USP_GetApprovedHoursPerSpace
 @semester_start DATETIME, @semester_end DATETIME
AS
BEGIN
 SET NOCOUNT ON;
 IF @semester_start IS NULL OR @semester_end IS NULL OR @semester_start >= @semester_end THROW 50160, 'Invalid semester range.', 1;
 ;WITH Approved AS (
  SELECT br.space_id, br.requested_start_time, br.requested_end_time
  FROM dbo.BookingRequest br
  JOIN lookup_table.RequestState rs ON rs.request_state_id=br.request_state_id
  OUTER APPLY (SELECT TOP (1) rd.request_decision_code FROM dbo.Review rv JOIN lookup_table.RequestDecision rd ON rd.request_decision_id=rv.request_decision_id WHERE rv.booking_request_id=br.booking_request_id ORDER BY rv.decision_time DESC,rv.review_id DESC) latest
  WHERE (rs.request_state_code='AUTO_APPROVED' OR latest.request_decision_code='APPROVED')
    AND br.requested_start_time < @semester_end AND br.requested_end_time > @semester_start
 )
 SELECT s.space_id,s.space_name,CAST(SUM(DATEDIFF(MINUTE,CASE WHEN a.requested_start_time<@semester_start THEN @semester_start ELSE a.requested_start_time END,CASE WHEN a.requested_end_time>@semester_end THEN @semester_end ELSE a.requested_end_time END))/60.0 AS DECIMAL(18,2)) total_approved_hours
 FROM Approved a JOIN dbo.Space s ON s.space_id=a.space_id
 GROUP BY s.space_id,s.space_name ORDER BY total_approved_hours DESC,s.space_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.USP_GetApprovedBookingCountByWeekdayHour
 @semester_start DATETIME, @semester_end DATETIME
AS
BEGIN
 SET NOCOUNT ON;
 IF @semester_start IS NULL OR @semester_end IS NULL OR @semester_start >= @semester_end THROW 50161, 'Invalid semester range.', 1;
 ;WITH Approved AS (
  SELECT br.booking_request_id,br.requested_start_time
  FROM dbo.BookingRequest br JOIN lookup_table.RequestState rs ON rs.request_state_id=br.request_state_id
  OUTER APPLY (SELECT TOP (1) rd.request_decision_code FROM dbo.Review rv JOIN lookup_table.RequestDecision rd ON rd.request_decision_id=rv.request_decision_id WHERE rv.booking_request_id=br.booking_request_id ORDER BY rv.decision_time DESC,rv.review_id DESC) latest
  WHERE (rs.request_state_code='AUTO_APPROVED' OR latest.request_decision_code='APPROVED') AND br.requested_start_time>=@semester_start AND br.requested_start_time<@semester_end
 )
 SELECT ((DATEDIFF(DAY,'19000101',CAST(requested_start_time AS DATE))%7)+1) weekday_number,
        DATENAME(WEEKDAY,requested_start_time) weekday_name,DATEPART(HOUR,requested_start_time) start_hour,COUNT_BIG(*) approved_booking_count
 FROM Approved GROUP BY ((DATEDIFF(DAY,'19000101',CAST(requested_start_time AS DATE))%7)+1),DATENAME(WEEKDAY,requested_start_time),DATEPART(HOUR,requested_start_time)
 ORDER BY weekday_number,start_hour;
END;
GO

IF TYPE_ID(N'dbo.FacilityRequirementTable') IS NULL
 EXEC(N'CREATE TYPE dbo.FacilityRequirementTable AS TABLE (facility_type_code VARCHAR(20) NOT NULL PRIMARY KEY);');
GO
CREATE OR ALTER PROCEDURE dbo.USP_FindAvailableSpaces
 @period_start DATETIME,@period_end DATETIME,@required_capacity INT,@facility_table dbo.FacilityRequirementTable READONLY
AS
BEGIN
 SET NOCOUNT ON;
 IF @period_start IS NULL OR @period_end IS NULL OR @period_start>=@period_end THROW 50162,'Invalid requested range.',1;
 IF @required_capacity IS NULL OR @required_capacity<1 THROW 50163,'Required capacity must be positive.',1;
 SELECT s.space_id,s.space_name,s.capacity,s.building,s.floor,s.room_number
 FROM dbo.Space s JOIN lookup_table.SpaceStatus ss ON ss.space_status_id=s.space_status_id
 WHERE ss.space_status_code='AVAILABLE' AND s.capacity>=@required_capacity
 AND NOT EXISTS (SELECT 1 FROM dbo.BookingRequest br JOIN lookup_table.RequestState rs ON rs.request_state_id=br.request_state_id OUTER APPLY (SELECT TOP(1) rd.request_decision_code FROM dbo.Review rv JOIN lookup_table.RequestDecision rd ON rd.request_decision_id=rv.request_decision_id WHERE rv.booking_request_id=br.booking_request_id ORDER BY rv.decision_time DESC,rv.review_id DESC) latest WHERE br.space_id=s.space_id AND (rs.request_state_code='AUTO_APPROVED' OR latest.request_decision_code='APPROVED') AND br.requested_start_time<@period_end AND br.requested_end_time>@period_start)
 AND NOT EXISTS (SELECT 1 FROM dbo.Maintenance m JOIN dbo.MaintenanceSession ms ON ms.maintenance_id=m.maintenance_id JOIN lookup_table.MaintenanceImpactLevel mil ON mil.maintenance_impact_level_id=ms.maintenance_impact_level_id WHERE m.space_id=s.space_id AND mil.maintenance_impact_level_code='OUT_OF_SERVICE' AND ms.maintenance_start_time<@period_end AND ms.maintenance_end_time>@period_start)
 AND NOT EXISTS (SELECT 1 FROM @facility_table req WHERE NOT EXISTS (SELECT 1 FROM dbo.Facility f JOIN lookup_table.FacilityType ft ON ft.facility_type_id=f.facility_type_id WHERE f.space_id=s.space_id AND ft.facility_type_code=req.facility_type_code))
 ORDER BY s.capacity,s.space_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.USP_GetBookingsAffectedByMaintenance
 @maintenance_id CHAR(6)
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.Maintenance WHERE maintenance_id=@maintenance_id) THROW 50164,'Maintenance record not found.',1;
 SELECT br.booking_request_id,br.user_id requester_id,br.space_id,br.requested_start_time booking_start,br.requested_end_time booking_end,
        CASE WHEN br.requested_start_time>ms.maintenance_start_time THEN br.requested_start_time ELSE ms.maintenance_start_time END overlap_start,
        CASE WHEN br.requested_end_time<ms.maintenance_end_time THEN br.requested_end_time ELSE ms.maintenance_end_time END overlap_end
 FROM dbo.Maintenance m JOIN dbo.MaintenanceSession ms ON ms.maintenance_id=m.maintenance_id
 JOIN dbo.BookingRequest br ON br.space_id=m.space_id JOIN lookup_table.RequestState rs ON rs.request_state_id=br.request_state_id
 OUTER APPLY (SELECT TOP(1) rd.request_decision_code FROM dbo.Review rv JOIN lookup_table.RequestDecision rd ON rd.request_decision_id=rv.request_decision_id WHERE rv.booking_request_id=br.booking_request_id ORDER BY rv.decision_time DESC,rv.review_id DESC) latest
 WHERE m.maintenance_id=@maintenance_id AND (rs.request_state_code='AUTO_APPROVED' OR latest.request_decision_code='APPROVED')
   AND br.requested_start_time<ms.maintenance_end_time AND br.requested_end_time>ms.maintenance_start_time
 ORDER BY overlap_start,br.booking_request_id;
END;
GO
SET NOCOUNT OFF;
GO