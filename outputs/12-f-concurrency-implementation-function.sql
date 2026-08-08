USE School;
GO 
------------------------------------------------------
-- Function 1: GetAllAdvisories
------------------------------------------------------
GO

CREATE OR ALTER FUNCTION GetAllAdvisories
    (@space_id VARCHAR(10))
RETURNS TABLE 
AS
RETURN (
    SELECT m.maintenance_id, m.maintenance_name, ms.maintenance_session_id, ms.maintenance_impact_level_id
    FROM Maintenance m  
    JOIN MaintenanceSession ms ON m.maintenance_id = ms.maintenance_id
    WHERE ms.maintenance_impact_level_id IN (
        SELECT maintenance_impact_level_id 
        FROM MaintenanceImpactLevel 
        WHERE maintenance_impact_level_name = 'Advisory'
    )
);

GO  


    