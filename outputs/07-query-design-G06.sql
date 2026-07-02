USE School;
GO

----------------------------------------------------------------------------------------------
-- Business question	- How to get approved requests after a date?
-- Target users      	- Casual end users, naive end users
-- Explanation 			- This query is useful to obtain a list of approved bookings to verify
--						integrity with respect to reservations, or to simply obtain a list of
--						approved bookings from a date onwards. 
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_GetApprovedRequestsAfterDate
	@date DATETIME = NULL
AS
BEGIN
	SELECT 
		br.booking_request_id,
		br.requested_start_time,
		br.requested_end_time,
		s.space_id,
		s.space_name,
		b.user_id
	FROM BookingRequest br
		INNER JOIN junction_table.Booking b ON br.booking_request_id = b.booking_request_id
		INNER JOIN Space s ON b.space_id = s.space_id
		INNER JOIN junction_table.Review r ON br.booking_request_id = r.booking_request_id
		INNER JOIN lookup_table.Decision d ON r.decision_id = d.decision_id
	WHERE d.decision_code = 'APPROVED'
		AND br.requested_start_time >= @date
	ORDER BY br.requested_start_time ASC;
END
GO

----------------------------------------------------------------------------------------------
-- Business question	- How to get the booking history from a user?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to get all booking requests a user has ever
--						made.
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_GetBookingHistoryFromUser
	@user_id VARCHAR(8) = NULL
AS
BEGIN
	SELECT 
		u.user_id,
		u.surname + ' ' + u.given_name AS full_name,
		br.booking_request_id,
		s.space_name,
		br.requested_start_time,
		br.requested_end_time,
		d.decision_name AS decision
	FROM [User] u
		INNER JOIN junction_table.Booking b ON u.user_id = b.user_id
		INNER JOIN BookingRequest br ON b.booking_request_id = br.booking_request_id
		INNER JOIN Space s ON b.space_id = s.space_id
		INNER JOIN junction_table.Review r ON br.booking_request_id = r.booking_request_id
		INNER JOIN lookup_table.Decision d ON r.decision_id = d.decision_id
	WHERE u.user_id = @user_id
	ORDER BY br.requested_start_time DESC;
END
GO

-- ============================================================================
-- Query 3: Spaces Currently Under Maintenance
-- Business question: List all spaces currently undergoing active maintenance, with the problem description, start time, technician name, and space type.
-- Tables/joins used: Space, lookup_table.SpaceType, junction_table.Maintaining, Maintenance, lookup_table.MaintenanceStatus, [User]
-- ============================================================================
SELECT 
    s.space_id,
    s.space_name,
    st.space_type_name,
    m.maintenance_description,
    ming.maintenance_start_time,
    u.surname + ' ' + u.given_name AS technician_name
FROM Space s
INNER JOIN lookup_table.SpaceType st ON s.space_type_id = st.space_type_id
INNER JOIN junction_table.Maintaining ming ON s.space_id = ming.space_id
INNER JOIN Maintenance m ON ming.maintenance_id = m.maintenance_id
INNER JOIN lookup_table.MaintenanceStatus ms ON m.maintenance_status_id = ms.maintenance_status_id
INNER JOIN [User] u ON ming.technician_id = u.user_id
WHERE ms.maintenance_status_code = 'ONGOING'
  AND ming.maintenance_end_time IS NULL;
GO

-- ============================================================================
-- Query 4: Approved Bookings marked as No-Show
-- Business question: View all bookings that were approved but where the user failed to show up, including expected participants and reservation notes.
-- Tables/joins used: Reservation, lookup_table.ReservationStatus, BookingRequest, junction_table.Booking, Space, [User]
-- ============================================================================
SELECT 
    r.reservation_id,
    br.booking_request_id,
    u.surname + ' ' + u.given_name AS booker_name,
    s.space_id,
    s.space_name,
    br.requested_start_time,
    br.expected_participants,
    r.usage_note
FROM Reservation r
INNER JOIN lookup_table.ReservationStatus rs ON r.reservation_status_id = rs.reservation_status_id
INNER JOIN BookingRequest br ON r.booking_request_id = br.booking_request_id
INNER JOIN junction_table.Booking b ON br.booking_request_id = b.booking_request_id
INNER JOIN Space s ON b.space_id = s.space_id
INNER JOIN [User] u ON b.user_id = u.user_id
WHERE rs.reservation_status_code = 'NO_SHOW'
ORDER BY br.requested_start_time DESC;
GO

-- ============================================================================
-- Query 5: Space Utilization Summary (Aggregation)
-- Business question: Calculate the total bookings, total completed sessions, and total occupied duration (in minutes) each space has been utilized, showing only spaces with at least one completed session.
-- Tables/joins used: Space, junction_table.Booking, Reservation, junction_table.ReservationCheckin
-- ============================================================================
SELECT 
    s.space_id,
    s.space_name,
    COUNT(DISTINCT b.booking_request_id) AS total_bookings_requested,
    COUNT(DISTINCT rc.reservation_id) AS total_completed_sessions,
    SUM(DATEDIFF(MINUTE, rc.actual_start_time, rc.actual_end_time)) AS total_utilized_minutes
FROM Space s
LEFT JOIN junction_table.Booking b ON s.space_id = b.space_id
LEFT JOIN Reservation r ON b.booking_request_id = r.booking_request_id
LEFT JOIN junction_table.ReservationCheckin rc ON r.reservation_id = rc.reservation_id
WHERE rc.actual_end_time IS NOT NULL
GROUP BY s.space_id, s.space_name
HAVING COUNT(DISTINCT rc.reservation_id) > 0
ORDER BY total_utilized_minutes DESC;
GO

-- ============================================================================
-- Query 6: Search Available Spaces (Logic Enforced at Query Level)
-- Business question: Find available spaces of a specific type that are not under maintenance and do not have any overlapping approved reservations during a desired time window.
-- Tables/joins used: Space, lookup_table.SpaceStatus, junction_table.Booking, BookingRequest, junction_table.Review, lookup_table.Decision, junction_table.Maintaining, Maintenance, lookup_table.MaintenanceStatus
-- ============================================================================
DECLARE @DesiredStart DATETIME = '2026-06-20T08:00:00';
DECLARE @DesiredEnd DATETIME = '2026-06-20T10:00:00';
DECLARE @TargetSpaceType TINYINT = 3; -- LECTURE_HALL

SELECT 
    s.space_id,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    s.capacity
FROM Space s
INNER JOIN lookup_table.SpaceStatus ss ON s.space_status_id = ss.space_status_id
WHERE s.space_type_id = @TargetSpaceType
  AND ss.space_status_code = 'AVAILABLE' -- Space must be currently available
  AND s.space_id NOT IN (
      -- Exclude spaces that have overlapping approved bookings
      SELECT b.space_id
      FROM junction_table.Booking b
      INNER JOIN BookingRequest br ON b.booking_request_id = br.booking_request_id
      INNER JOIN junction_table.Review rev ON br.booking_request_id = rev.booking_request_id
      INNER JOIN lookup_table.Decision d ON rev.decision_id = d.decision_id
      WHERE d.decision_code = 'APPROVED'
        AND br.requested_start_time < @DesiredEnd
        AND br.requested_end_time > @DesiredStart
  )
  AND s.space_id NOT IN (
      -- Exclude spaces currently under active maintenance
      SELECT space_id
      FROM junction_table.Maintaining ming
      INNER JOIN Maintenance m ON ming.maintenance_id = m.maintenance_id
      INNER JOIN lookup_table.MaintenanceStatus ms ON m.maintenance_status_id = ms.maintenance_status_id
      WHERE ms.maintenance_status_code = 'ONGOING'
        AND ming.maintenance_end_time IS NULL
  );
GO
