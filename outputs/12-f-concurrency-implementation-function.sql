USE School;
GO 
------------------------------------------------------
-- Function 1: GetAllAdvisories
------------------------------------------------------
GO

CREATE OR ALTER FUNCTION UF_GetAllAdvisories
    (@space_id VARCHAR(10))
RETURNS TABLE 
AS
RETURN (
    SELECT m.maintenance_id, m.maintenance_description, mts.maintenance_status_name
    FROM Maintenance m  
    JOIN MaintenanceSession ms ON m.maintenance_id = ms.maintenance_id
    JOIN lookup_table.MaintenanceStatus mts ON m.maintenance_status_id = mts.maintenance_status_id
    WHERE ms.maintenance_impact_level_id IN (
        SELECT maintenance_impact_level_id 
        FROM lookup_table.MaintenanceImpactLevel 
        WHERE maintenance_impact_level_name = 'Advisory'
    ) AND m.space_id = @space_id
);

GO  

------------------------------------------------------
-- Function 2: GetReservationsFromCriticalSpace
-----------------------------------------------------
CREATE OR ALTER FUNCTION UF_GetReservationsFromCriticalSpace
    (@maintenance_id CHAR(6))
RETURNS TABLE
AS
RETURN (
    SELECT r.reservation_id
    FROM Reservation r
    JOIN BookingRequest br ON r.booking_request_id = br.booking_request_id
    JOIN Maintenance m ON m.space_id = br.space_id
    JOIN MaintenanceSession ms ON m.maintenance_id = ms.maintenance_id
    JOIN lookup_table.MaintenanceImpactLevel mil ON ms.maintenance_impact_level_id = mil.maintenance_impact_level_id
    JOIN lookup_table.ReservationStatus rs ON r.reservation_status_id = rs.reservation_status_id
    WHERE m.maintenance_id = @maintenance_id 
    AND mil.maintenance_impact_level_name = 'Out-of-service' 
    AND rs.reservation_status_name = 'Pending' OR rs.reservation_status_name = 'Checked in'
);

GO  

------------------------------------------
-- Function 3: GetReservationTimePerSpace
------------------------------------------
CREATE OR ALTER FUNCTION UF_GetReservationTimePerSpace

    