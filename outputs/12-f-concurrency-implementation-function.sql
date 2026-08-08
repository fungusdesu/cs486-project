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
    SELECT m.maintenance_id, m.maintenance_description, mts.maintenance_status_name
    FROM Maintenance m  
    JOIN MaintenanceSession ms ON m.maintenance_id = ms.maintenance_id
    JOIN lookup_table.MaintenanceStatus mts ON m.maintenance_status_id = mts.maintenance_status_id
    WHERE ms.maintenance_impact_level_id IN (
        SELECT maintenance_impact_level_id 
        FROM lookup_table.MaintenanceImpactLevel 
        WHERE maintenance_impact_level_name = 'Advisory'
    )
);

GO  



    