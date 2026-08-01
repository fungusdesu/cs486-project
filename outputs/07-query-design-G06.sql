USE School
GO
----------------------------------------------------------------------------------------------
-- Query maker			- Nguyễn Đình Thiên Lộc
-- Business question	- How to get approved requests after a date?
-- Target users      	- Casual end users, naive end users
-- Explanation 			- This query is useful to obtain a list of approved bookings to verify
--						integrity with respect to reservations, or to simply obtain a list of
--						approved bookings from a date onwards. 
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetApprovedRequestsAfterDate
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
-- Query maker			- Nguyễn Đình Thiên Lộc
-- Business question	- How to get the booking history from a user?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to get all booking requests a user has ever
--						made.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetBookingHistoryFromUser
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
-- Query maker			- Nguyễn Đình Thiên Lộc
-- Business question: 	- How to get a list of spaces undergoing active maintenance?
-- Target users			- Casual end users, naive end users
-- Explanation 			- This query is useful to give more details about the current spaces
-- 						under maintenance.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetSpaceUnderMaintenance
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
-- Query maker			- Nguyễn Đình Thiên Lộc
-- Business question	- How to get a list of reservations where the user did not show up?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to view all bookings that were approved but
--						where the user failed to show up, with reservation notes attached.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetNoShowReservations
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
-- Query maker			- Nguyễn Đình Thiên Lộc
-- Business question	- How can one quickly obtains the statistics on each space's use?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to summarize the utilization (including booking,
-- 						reservations, and occupy time) of each space.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_SummarizeSpaceUtilization
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
-- Query maker			- Trần Tôn Minh Kỳ
-- Business question	- How can one get all requests within a timeframe?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to fetch all requests of any status within a
--						given period of time.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetRequestsWithinTimeframe
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
-- Query maker			- Trần Tôn Minh Kỳ
-- Business question	- How can one get a list of requests pending staff reviews?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to obtain a list of pending requests for
--						allocating facility staff for review.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetPendingBookingRequests
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
-- Query maker			- Trần Tôn Minh Kỳ
-- Business question	- How can one know which spaces are most frequently rejected?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to obtain a list of spaces with their rejection
--						count.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetSpaceRejectionCount
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
-- Query maker			- Trần Tôn Minh Kỳ
-- Business question	- Which users have upcoming approved bookings that require check-in?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to obtain a list of users with pending
--						reservation.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetUsersWithPendingReservation
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
-- Query maker			- Trần Tôn Minh Kỳ
-- Business question	- Which maintenance records are assigned to some technician?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to obtain a list of maintenance associated
--						with a specific technician.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetMaintenanceFromTechnician
	@user VARCHAR(8) = NULL
AS
BEGIN
	SELECT m.*
	FROM Maintenance m
		INNER JOIN junction_table.Maintaining ming ON ming.maintenance_id = m.maintenance_id
	WHERE ming.technician_id = @user
END
GO

----------------------------------------------------------------------------------------------
-- Query maker			- Nguyễn Hồng Tấn Tài
-- Business question	- Which spaces are available for booking within a timeframe?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to find spaces that are currently bookable and
--						do not conflict with any approved booking request in the given period.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetAvailableSpacesForTimeframe
	@begin DATETIME = NULL,
	@end DATETIME = NULL
AS
BEGIN
	SELECT
		s.space_id,
		s.space_name,
		st.space_type_name,
		s.building,
		s.[floor],
		s.room_number,
		s.capacity,
		s.space_policy_id
	FROM Space s
		INNER JOIN lookup_table.SpaceStatus ss ON ss.space_status_id = s.space_status_id
		LEFT JOIN lookup_table.SpaceType st ON st.space_type_id = s.space_type_id
		INNER JOIN SpacePolicy sp ON sp.space_policy_id = s.space_policy_id
	WHERE
		ss.space_status_code = 'AVAILABLE'
		AND (
			@begin IS NULL OR @end IS NULL
			OR NOT EXISTS (
				SELECT 1
				FROM junction_table.Booking b
					INNER JOIN BookingRequest br ON br.booking_request_id = b.booking_request_id
					INNER JOIN junction_table.Review r ON r.booking_request_id = br.booking_request_id
					INNER JOIN lookup_table.Decision d ON d.decision_id = r.decision_id
				WHERE b.space_id = s.space_id
					AND d.decision_code = 'APPROVED'
					AND br.requested_start_time < @end
					AND br.requested_end_time > @begin
			)
		)
END
GO

----------------------------------------------------------------------------------------------
-- Query maker			- Nguyễn Hồng Tấn Tài
-- Business question	- What facilities are available in a specific space?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful when a requester wants to check the equipment
-- 				  		of a room before making a booking request.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetSpaceFacilities
	@space_id VARCHAR(10) = NULL
AS
BEGIN
	SELECT
		ft.facility_type_id,
		f.facility_sequence_number,
		ft.facility_type_name,
		f.facility_name
	FROM Space s
		INNER JOIN Facility f ON f.space_id = s.space_id
		INNER JOIN lookup_table.FacilityType ft ON ft.facility_type_id = f.facility_type_id
	WHERE (@space_id IS NULL OR s.space_id = @space_id)
END
GO

----------------------------------------------------------------------------------------------
-- Query maker			- Nguyễn Hồng Tấn Tài
-- Business question	- Which approved bookings are coming up for a given space?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful for staff to see the next approved sessions
-- 				  		scheduled for one room and prepare the space in advance.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetUpcomingApprovedBookingsBySpace
	@space_id VARCHAR(10) = NULL,
	@from_date DATETIME = NULL
AS
BEGIN
	SELECT
		br.booking_request_id,
		s.space_name,
		u.user_id,
		u.surname + ' ' + u.given_name AS requester_name,
		p.purpose_name,
		br.requested_start_time,
		br.requested_end_time,
		r.decision_time,
		r.decision_note
	FROM BookingRequest br
		INNER JOIN junction_table.Booking b ON b.booking_request_id = br.booking_request_id
		INNER JOIN [User] u ON u.user_id = b.user_id
		INNER JOIN Space s ON s.space_id = b.space_id
		LEFT JOIN lookup_table.Purpose p ON p.purpose_id = br.purpose_id
		INNER JOIN junction_table.Review r ON r.booking_request_id = br.booking_request_id
		INNER JOIN lookup_table.Decision d ON d.decision_id = r.decision_id
	WHERE d.decision_code = 'APPROVED'
		AND (@space_id IS NULL OR s.space_id = @space_id)
		AND (@from_date IS NULL OR br.requested_start_time >= @from_date)
	ORDER BY br.requested_start_time ASC;
END
GO

----------------------------------------------------------------------------------------------
-- Query maker			- Nguyễn Hồng Tấn Tài
-- Business question	- How many booking requests are made for each purpose?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to understand demand patterns and compare
-- 				  		lecture, seminar, workshop, meeting, and other booking purposes.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetBookingCountsByPurpose
	@begin DATETIME = NULL,
	@end DATETIME = NULL
AS
BEGIN
	SELECT
		p.purpose_id,
		p.purpose_code,
		p.purpose_name,
		COUNT(*) AS total_booking_requests,
		COUNT(CASE WHEN d.decision_code = 'APPROVED' THEN 1 END) AS approved_requests,
		COUNT(CASE WHEN d.decision_code = 'REJECTED' THEN 1 END) AS rejected_requests,
		COUNT(CASE WHEN d.decision_code = 'PENDING' THEN 1 END) AS pending_requests
	FROM BookingRequest br
		LEFT JOIN lookup_table.Purpose p ON p.purpose_id = br.purpose_id
		LEFT JOIN junction_table.Review r ON r.booking_request_id = br.booking_request_id
		LEFT JOIN lookup_table.Decision d ON d.decision_id = r.decision_id
	WHERE (@begin IS NULL OR br.requested_start_time >= @begin)
		AND (@end IS NULL OR br.requested_start_time <= @end)
	GROUP BY p.purpose_id, p.purpose_code, p.purpose_name
	ORDER BY total_booking_requests DESC, p.purpose_name ASC;
END
GO

----------------------------------------------------------------------------------------------
-- Query maker			- Nguyễn Hồng Tấn Tài
-- Business question	- Which spaces have capacity greater than or equal to the expected
--						number of participants?
-- Target users			- Casual end users, naive end users
-- Explanation			- This query is useful to monitor spaces with enough capacity to house
--						a number of participants.
----------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetSpacesWithEnoughCapacity
	@participants_count VARCHAR(20) = NULL
AS
BEGIN
	SELECT *
	FROM [Space] s
	WHERE s.capacity >= @participants_count
END
GO

--------------------------------------------------------------------------------------------
-- Query maker			- Quách Thiên Lạc
-- Business question    - Is the room I want to book contains N numbers of equipment (board,
--						projector, .etc.)?
-- Target user          - Casual end users, naive end users
-- Explanation          - This is a query to let users know if the number of equipment they
--						need is available in a room they want to book.
--------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_CheckSpaceFacilities
	@space_id VARCHAR(10),
	@facility_type_id TINYINT,
	@facility_number TINYINT
AS
BEGIN
	SELECT
		s.space_id,
		s.space_name,
		f.facility_name,
		COUNT(f.facility_sequence_number) AS facility_count,
		CASE
			WHEN COUNT(f.facility_sequence_number) >= @facility_number THEN 'EQUIPMENT AVAILABLE'
			ELSE 'EQUIPMENT NOT AVAILABLE'
		END AS Availability
	FROM Space s
		LEFT JOIN Facility f
			ON f.space_id = s.space_id
			AND f.facility_type_id = @facility_type_id
	WHERE s.space_id = @space_id
	GROUP BY s.space_id, s.space_name, f.facility_name
END
GO

--------------------------------------------------------------------------------------------
-- Query maker			- Quách Thiên Lạc
-- Business question    - How many reservations are ongoing at a given moment?
-- Target user          - Managers
-- Explanation          - This is a query to let users get the number of reservation
-- 						happening at the requested time.
--------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetReservationAtTimestamp
	@timestamp DATETIME = NULL
AS
BEGIN
	SELECT
		r.reservation_id,
		br.requested_start_time,
		br.requested_end_time
	FROM Reservation r
		INNER JOIN BookingRequest br ON 
		r.booking_request_id = br.booking_request_id
	WHERE @timestamp >= br.requested_start_time AND @timestamp <= br.requested_end_time
END
GO

--------------------------------------------------------------------------------------------
-- Query maker			- Quách Thiên Lạc
-- Business question    - What user frequently book which room?
-- Target user          - Managers
-- Explanation          - This is a query to let users better keep track of the type of
-- 						people who frequently need room A (e.g., >3 times).
--------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_GetFrequentBookers
	@space_id VARCHAR(10),
	@frequency TINYINT
AS
BEGIN
	SELECT
		u.user_id,
		u.surname + ' ' + u.given_name AS full_name,
		s.space_name,
		COUNT(CASE WHEN @space_id = s.space_id THEN 1 END) AS requests_count
	FROM [User] u
		INNER JOIN lookup_table.UserRole ur ON ur.user_role_id = u.user_role_id
		INNER JOIN junction_table.Booking b ON b.user_id = u.user_id 
		INNER JOIN BookingRequest br ON br.booking_request_id = b.booking_request_id
		INNER JOIN Space s ON s.space_id = b.space_id
	GROUP BY u.user_id, u.surname, u.given_name, s.space_name
	HAVING COUNT(CASE WHEN @space_id = s.space_id THEN 1 END) >= @frequency
	ORDER BY full_name
END
GO

--------------------------------------------------------------------------------------------
-- Query maker			- Quách Thiên Lạc
-- Business question    - What user messes up a room?
-- Target user          - Managers
-- Explanation          - This is a query to let users better keep track of users who leave
--						the room in a bad condition after using.
--------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_FindBadUsers
AS
BEGIN
	SELECT
		rc.reservation_id,
		ci_u.surname + ' ' + ci_u.given_name AS check_in_user_full_name,
		a_u.surname + ' ' + a_u.given_name AS attendant_full_name,
		sc1.space_condition_name AS initial_condition,
		sc2.space_condition_name AS final_condition
	FROM junction_table.ReservationCheckin rc
		INNER JOIN [User] ci_u ON ci_u.[user_id] = rc.check_in_user_id
		INNER JOIN [User] a_u ON a_u.[user_id] = rc.attendant_id
		INNER JOIN lookup_table.SpaceCondition sc1 ON sc1.space_condition_id = rc.space_initial_condition_id
		INNER JOIN lookup_table.SpaceCondition sc2 ON sc2.space_condition_id = rc.space_final_condition_id
	WHERE rc.space_final_condition_id < rc.space_initial_condition_id
END
GO

--------------------------------------------------------------------------------------------
-- Query maker			- Quách Thiên Lạc
-- Business question    - What user frequently no-show?
-- Target user          - Managers
-- Explanation          - This is a query to let users better keep track of users who have
-- 						a history of abandoning reservation (>3 times).
--------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE USP_FindFrequentNoShowUsers
	@threshold TINYINT = 3
AS
BEGIN
	SELECT
		u.user_id,
		u.surname + ' ' + u.given_name AS full_name,
		COUNT(DISTINCT r.reservation_id) AS no_show_count
	FROM [User] u
		INNER JOIN junction_table.Booking b ON b.user_id = u.user_id
		INNER JOIN Reservation r ON r.booking_request_id = b.booking_request_id
		INNER JOIN lookup_table.ReservationStatus rs ON rs.reservation_status_id = r.reservation_status_id
	WHERE rs.reservation_status_code = 'NO_SHOW'
	GROUP BY u.user_id, u.surname, u.given_name
	HAVING COUNT(DISTINCT r.reservation_id) >= @threshold
END
GO
