USE School
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

----------------------------------------------------------------------------------------------
-- Business question: 	- How to get a list of spaces undergoing active maintenance?
-- Target users			- Casual end users, naive end users
-- Explanation 			- This query is useful to give more details about the current spaces
-- 						under maintenance.
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_GetSpaceUnderMaintenance
AS
BEGIN
	SELECT
		s.space_id,
		s.space_name,
		u.surname + ' ' + u.given_name AS technician_name,
		ming.maintenance_start_time,
		m.maintenance_description
	FROM Space s
		INNER JOIN lookup_table.SpaceStatus ss ON ss.space_status_id = s.space_status_id
		INNER JOIN junction_table.Maintaining ming ON ming.space_id = s.space_id
		INNER JOIN [User] u ON u.[user_id] = ming.technician_id
		INNER JOIN Maintenance m ON m.maintenance_id = ming.maintenance_id
	WHERE ss.space_status_code = 'UNDER_MAINT'
END
GO


----------------------------------------------------------------------------------------------
-- Business question	- How to get a list of reservations where the user did not show up?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to view all bookings that were approved but
--						where the user failed to show up, with reservation notes attached.
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_GetNoShowReservations
AS
BEGIN
	SELECT 
		r.reservation_id,
		u.surname + ' ' + u.given_name AS booker_name,
		s.space_name,
		br.requested_start_time,
		br.requested_end_time,
		r.usage_note
	FROM Reservation r
		INNER JOIN lookup_table.ReservationStatus rs ON r.reservation_status_id = rs.reservation_status_id
		INNER JOIN BookingRequest br ON r.booking_request_id = br.booking_request_id
		INNER JOIN junction_table.Booking b ON br.booking_request_id = b.booking_request_id
		INNER JOIN Space s ON b.space_id = s.space_id
		INNER JOIN [User] u ON b.user_id = u.user_id
	WHERE rs.reservation_status_code = 'NO_SHOW'
	ORDER BY br.requested_start_time DESC;
END
GO

----------------------------------------------------------------------------------------------
-- Business question	- How can one quickly obtains the statistics on each space's use?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to summarize the utilization (including booking,
-- 						reservations, and occupy time) of each space.
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_SummarizeSpaceUtilization
AS
BEGIN
	SELECT 
		s.space_id,
		s.space_name,
		COUNT(DISTINCT b.booking_request_id) AS total_bookings_requested,
		COUNT(CASE WHEN rs.reservation_status_code IN ('COMPLETED', 'NO_SHOW') THEN 1 END) AS total_completed_sessions,
		SUM(CASE WHEN rc.actual_end_time IS NOT NULL THEN DATEDIFF(MINUTE, rc.actual_start_time, rc.actual_end_time) ELSE 0 END) AS total_utilized_minutes
	FROM Space s
		LEFT JOIN junction_table.Booking b ON s.space_id = b.space_id
		LEFT JOIN Reservation r ON b.booking_request_id = r.booking_request_id
		LEFT JOIN junction_table.ReservationCheckin rc ON r.reservation_id = rc.reservation_id
		LEFT JOIN lookup_table.ReservationStatus rs ON r.reservation_status_id = rs.reservation_status_id
	GROUP BY s.space_id, s.space_name
	ORDER BY total_utilized_minutes DESC;
END
GO

----------------------------------------------------------------------------------------------
-- Business question	- How can one get all requests within a timeframe?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to fetch all requests of any status within a
--						given period of time.
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_GetRequestsWithinTimeframe
	@begin DATETIME = NULL,
	@end DATETIME = NULL
AS
BEGIN
	SELECT *
	FROM BookingRequest b
	WHERE (
		(@begin IS NULL OR b.requested_start_time >= @begin)
		AND (@end IS NULL OR b.requested_start_time <= @end)

	)
END
GO

----------------------------------------------------------------------------------------------
-- Business question	- How can one get a list of requests pending staff reviews?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to obtain a list of pending requests for
--						allocating facility staff for review.
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_GetPendingBookingRequests
AS
BEGIN
	SELECT br.*
	FROM BookingRequest br
		INNER JOIN junction_table.Review r ON r.booking_request_id = br.booking_request_id
		INNER JOIN lookup_table.Decision d ON d.decision_id = r.decision_id
	WHERE d.decision_code = 'PENDING'
END
GO

----------------------------------------------------------------------------------------------
-- Business question	- How can one know which spaces are most frequently rejected?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to obtain a list of spaces with their rejection
--						count.
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_GetSpaceRejectionCount
AS
BEGIN
	SELECT
		s.space_id,
		s.space_name,
		COUNT(CASE WHEN d.decision_code = 'REJECTED' THEN 1 END) AS rejection_count
	FROM Space s
		LEFT JOIN junction_table.Booking b ON s.space_id = b.space_id
		LEFT JOIN junction_table.Review r ON b.booking_request_id = r.booking_request_id
		LEFT JOIN lookup_table.Decision d ON r.decision_id = d.decision_id
	GROUP BY s.space_id, s.space_name
	ORDER BY rejection_count DESC
END
GO

----------------------------------------------------------------------------------------------
-- Business question	- Which users have upcoming approved bookings that require check-in?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to obtain a list of users with pending
--						reservation.
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_GetUsersWithPendingReservation
AS
BEGIN
	SELECT
		u.[user_id],
		u.surname + ' ' + u.given_name AS full_name,
		r.reservation_id,
		br.requested_start_time,
		br.requested_end_time
	FROM [User] u
		INNER JOIN junction_table.Booking b ON b.[user_id] = u.[user_id]
		INNER JOIN Reservation r ON r.booking_request_id = b.booking_request_id
		INNER JOIN BookingRequest br ON br.booking_request_id = r.booking_request_id
		INNER JOIN lookup_table.ReservationStatus rs ON rs.reservation_status_id = r.reservation_status_id
	WHERE rs.reservation_status_code = 'PENDING'
END
GO

----------------------------------------------------------------------------------------------
-- Business question	- Which maintenance records are assigned to some technician?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to obtain a list of maintenance associated
--						with a specific technician.
----------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_GetMaintenanceFromTechnician
	@user VARCHAR(8) = NULL
AS
BEGIN
	SELECT m.*
	FROM Maintenance m
		INNER JOIN junction_table.Maintaining ming ON ming.maintenance_id = m.maintenance_id
	WHERE ming.technician_id = @user
END
GO