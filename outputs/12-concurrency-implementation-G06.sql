CREATE OR ALTER PROCEDURE USP_AddUser
	@user_id CHAR(8),
	@surname NVARCHAR(30),
	@given_name NVARCHAR(20),
	@email NVARCHAR(255),
	@phone_number VARCHAR(10),
	@user_role_code VARCHAR(20),
	@department_code VARCHAR(20) = NULL
AS
BEGIN
	BEGIN TRANSACTION;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.UserRole
		WHERE user_role_code = @user_role_code
	)
	THROW 52001, 'Invalid user role', 1;

	IF (@department_code IS NULL AND @user_role_code = 'STUDENT')
	THROW 52026, 'Department was not provided for non-facility staff', 1;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.Department
		WHERE department_code = @department_code
	)
	THROW 52002, 'Invalid department', 1;

	DECLARE @user_role_id AS TINYINT = (
		SELECT user_role_id
		FROM lookup_table.UserRole
		WHERE user_role_code = @user_role_code
	);
	DECLARE @department_id AS TINYINT = (
		SELECT department_id
		FROM lookup_table.Department
		WHERE department_code = @department_code
	);
	DECLARE @user_status_id AS TINYINT = (
		SELECT user_status_id
		FROM lookup_table.UserStatus
		WHERE user_status_code = 'ACTIVE'
	);

	INSERT INTO [User] (user_id, surname, given_name, email, phone_number, user_role_id, department_id, user_status_id)
	VALUES (@user_id, @surname, @given_name, @email, @phone_number, @user_role_id, @department_id, @user_status_id);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_AddSpace
	@space_id VARCHAR(10),
	@space_name NVARCHAR(30),
	@space_type_code VARCHAR(20),
	@building CHAR(1),
	@floor TINYINT,
	@room_number TINYINT,
	@capacity SMALLINT,
	@space_policy_id CHAR(5)
AS
BEGIN
	BEGIN TRANSACTION;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.SpaceType
		WHERE space_type_code = @space_type_code
	)
	THROW 52003, 'Invalid space type', 1;

	DECLARE @space_type_id AS TINYINT = (
		SELECT space_type_id
		FROM lookup_table.SpaceType
		WHERE space_type_code = @space_type_code
	);
	DECLARE @space_status_id AS TINYINT = (
		SELECT space_status_id
		FROM lookup_table.SpaceStatus
		WHERE space_status_code = 'AVAILABLE'
	);

	INSERT INTO Space (space_id, space_name, space_type_id, building, floor, room_number, capacity, space_status_id, space_policy_id)
	VALUES (@space_id, @space_name, @space_type_id, @building, @floor, @room_number, @capacity, @space_status_id, @space_policy_id);
	COMMIT;
END
GO

USE School
GO

CREATE OR ALTER PROCEDURE USP_CreateBookingRequest
	@booking_request_id CHAR(8),
	@user_id CHAR(8),
	@space_id VARCHAR(10),
	@requested_start_time DATETIME,
	@requested_end_time DATETIME,
	@purpose_code VARCHAR(20),
	@expected_participants SMALLINT,
	@advisory_acknowledged BIT
AS
BEGIN
	BEGIN TRANSACTION;
	DECLARE @request_creation_date AS DATETIME = GETDATE();

	IF (@requested_end_time < @requested_start_time)
	THROW 52016, 'Requested end time must be later than requested start time', 1;

	IF (DATEDIFF(minute, @requested_start_time, @requested_end_time) < (
		SELECT sp.min_duration_minutes
		FROM SpacePolicy sp
			INNER JOIN Space s ON s.space_policy_id = sp.space_policy_id
		WHERE s.space_id = @space_id
	))
	THROW 52012, 'Requested duration falls below minimum allowed duration', 1;

	IF (DATEDIFF(minute, @requested_start_time, @requested_end_time) > (
		SELECT sp.max_duration_minutes
		FROM SpacePolicy sp
			INNER JOIN Space s ON s.space_policy_id = sp.space_policy_id
		WHERE s.space_id = @space_id
	))
	THROW 52013, 'Requested duration exceeds maximum allowed duration', 1;

	IF (DATEDIFF(day, @request_creation_date, @requested_start_time) > (
		SELECT sp.booking_window_days
		FROM SpacePolicy sp
			INNER JOIN Space s ON s.space_policy_id = sp.space_policy_id
		WHERE s.space_id = @space_id
	))
	THROW 52014, 'Request is made more than the allowed time ahead', 1;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.Purpose p
		WHERE p.purpose_code = @purpose_code
	)
	THROW 52004, 'Invalid purpose', 1;

	IF NOT EXISTS (
		SELECT 1
		FROM Space s
			INNER JOIN lookup_table.SpaceStatus ss ON ss.space_status_id = s.space_status_id
		WHERE ss.space_status_code IN ('AVAILABLE', 'IN_USE')
	)
	THROW 52022, 'Requested space is not bookable', 1;

	IF EXISTS (
		SELECT 1
		FROM Reservation r
			INNER JOIN lookup_table.ReservationStatus rs ON rs.reservation_status_id = r.reservation_status_id
			INNER JOIN BookingRequest br ON br.booking_request_id = r.booking_request_id
		WHERE (
			rs.reservation_status_code NOT IN ('COMPLETED', 'NO_SHOW', 'CANCELED') AND
			br.requested_start_time <= @requested_end_time
			-- this should suffice for overlapping time
		)
	)
	THROW 52023, 'Requested space is already occupied during the requested time slot', 1;

	DECLARE @purpose_id AS TINYINT = (
		SELECT purpose_id
		FROM lookup_table.Purpose
		WHERE purpose_code = @purpose_code
	);
	DECLARE @request_state_id AS TINYINT = (
		SELECT request_state_id
		FROM lookup_table.RequestState
		WHERE request_state_code = 'PENDING'
	);

	INSERT INTO BookingRequest (booking_request_id, user_id, space_id, request_creation_time, requested_start_time, requested_end_time, purpose_id, expected_participants, request_state_id, advisory_acknowledged)
		VALUES (@booking_request_id, @user_id, @space_id, @request_creation_date, @requested_start_time, @requested_end_time, @purpose_id, @expected_participants, @request_state_id, @advisory_acknowledged);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_CancelBookingRequest
	@booking_request_id CHAR(8)
AS
BEGIN
	BEGIN TRANSACTION;
	DECLARE @request_state_id AS TINYINT = (
		SELECT request_state_id
		FROM lookup_table.RequestState
		WHERE request_state_code = 'CANCELED'
	);

	UPDATE BookingRequest
	SET request_state_id = @request_state_id
	WHERE booking_request_id = @booking_request_id;
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_AddReservation
	@reservation_id CHAR(8),
	@booking_request_id CHAR(8)
AS
BEGIN
	BEGIN TRANSACTION
	IF NOT EXISTS (
		SELECT 1
		FROM BookingRequest
		WHERE booking_request_id = @booking_request_id
	)
	THROW 52005, 'Booking request does not exist', 1

	DECLARE @reservation_status_id AS TINYINT = (
		SELECT reservation_status_id
		FROM lookup_table.ReservationStatus
		WHERE reservation_status_code = 'PENDING'
	);

	INSERT INTO Reservation (reservation_id, booking_request_id, reservation_status_id)
	VALUES (@reservation_id, @booking_request_id, @reservation_status_id);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_ApproveBookingRequest
	@review_id CHAR(9),
	@reviewer_id CHAR(8),
	@booking_request_id CHAR(8),
	@decision_note NVARCHAR(250) = NULL
AS
BEGIN
	BEGIN TRANSACTION
	IF NOT EXISTS (
		SELECT 1
		FROM BookingRequest br
		WHERE br.booking_request_id = @booking_request_id
	)
	THROW 52005, 'Booking request does not exist', 2;

	IF EXISTS (
		SELECT 1
		FROM Review r
			INNER JOIN lookup_table.RequestDecision rd ON rd.request_decision_id = r.request_decision_id
		WHERE (
			r.booking_request_id = @booking_request_id AND
			rd.request_decision_code = 'APPROVED'
		)
	)
	THROW 52027, 'Booking request is already approved and cannot be reviewed further', 1

	DECLARE @request_decision_id AS TINYINT = (
		SELECT request_decision_id
		FROM lookup_table.RequestDecision
		WHERE request_decision_code = 'APPROVED'
	);
	DECLARE @request_state_id AS TINYINT = (
		SELECT request_state_id
		FROM lookup_table.RequestState
		WHERE request_state_code = 'REVIEWED'
	);

	INSERT INTO Review (review_id, booking_request_id, reviewer_id, request_decision_id, decision_time, decision_note)
	VALUES (@review_id, @booking_request_id, @reviewer_id, @request_decision_id, GETDATE(), @decision_note);

	UPDATE BookingRequest
	SET request_state_id = @request_state_id
	WHERE booking_request_id = @booking_request_id;
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_RejectBookingRequest
	@review_id CHAR(9),
	@reviewer_id CHAR(8),
	@booking_request_id CHAR(8),
	@decision_note NVARCHAR(250) = NULL,
	@rejection_reason NVARCHAR(250) = NULL
AS
BEGIN
	BEGIN TRANSACTION
	IF NOT EXISTS (
		SELECT 1
		FROM BookingRequest br
		WHERE br.booking_request_id = @booking_request_id
	)
	THROW 52005, 'Booking request does not exist', 3;

	IF EXISTS (
		SELECT 1
		FROM Review r
			INNER JOIN lookup_table.RequestDecision rd ON rd.request_decision_id = r.request_decision_id
		WHERE (
			r.booking_request_id = @booking_request_id AND
			rd.request_decision_code = 'APPROVED'
		)
	)
	THROW 52027, 'Booking request is already approved and cannot be reviewed further', 2

	DECLARE @request_decision_id AS TINYINT = (
		SELECT request_decision_id
		FROM lookup_table.RequestDecision
		WHERE request_decision_code = 'REJECTED'
	);
	DECLARE @request_state_id AS TINYINT = (
		SELECT request_state_id
		FROM lookup_table.RequestState
		WHERE request_state_code = 'REVIEWED'
	);

	INSERT INTO Review (review_id, booking_request_id, reviewer_id, request_decision_id, decision_time, decision_note, rejection_reason)
	VALUES (@review_id, @booking_request_id, @reviewer_id, @request_decision_id, GETDATE(), @decision_note, @rejection_reason);

	UPDATE BookingRequest
	SET request_state_id = @request_state_id
	WHERE booking_request_id = @booking_request_id;
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_StartReservationSession
	@reservation_id CHAR(8),
	@attendant_id CHAR(8),
	@checked_in_user_id CHAR(8),
	@space_initial_condition_code VARCHAR(20)
AS
BEGIN
	BEGIN TRANSACTION;
	DECLARE @actual_start_time AS DATETIME = GETDATE();

	IF NOT EXISTS (
		SELECT 1
		FROM Reservation r
		WHERE r.reservation_id = @reservation_id
	)
	THROW 52028, 'Reservation does not exist', 1;

	IF EXISTS (
		SELECT 1
		FROM Reservation r
			INNER JOIN lookup_table.ReservationStatus rs ON rs.reservation_status_id = r.reservation_status_id
		WHERE (
			r.reservation_id = @reservation_id AND
			rs.reservation_status_code != 'PENDING'
		)
	)
	THROW 52008, 'Reservation is not pending', 1;

	DECLARE @requested_start_time AS DATETIME = (
		SELECT br.requested_start_time
		FROM Reservation r
			INNER JOIN BookingRequest br ON br.booking_request_id = r.booking_request_id
		WHERE r.reservation_id = @reservation_id
	);
	
	IF (DATEDIFF(minute, @requested_start_time, @actual_start_time) > (
		SELECT sp.check_in_grace_minutes
		FROM Reservation r
			INNER JOIN BookingRequest br ON br.booking_request_id = r.booking_request_id
			INNER JOIN Space s ON s.space_id = br.space_id
			INNER JOIN SpacePolicy sp ON sp.space_policy_id = s.space_policy_id
		WHERE r.reservation_id = @reservation_id
	))
	THROW 52006, 'Actual start time exceeds grace period', 1;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.SpaceCondition
		WHERE space_condition_code = @space_initial_condition_code
	)
	THROW 52007, 'Invalid space condition', 1;

	DECLARE @space_initial_condition_id AS TINYINT = (
		SELECT space_condition_id
		FROM lookup_table.SpaceCondition
		WHERE space_condition_code = @space_initial_condition_code
	);
	DECLARE @reservation_status_id AS TINYINT = (
		SELECT reservation_status_id
		FROM lookup_table.ReservationStatus
		WHERE reservation_status_code = 'CHECKED_IN'
	);
	DECLARE @space_status_id AS TINYINT = (
		SELECT space_status_id
		FROM lookup_table.SpaceStatus
		WHERE space_status_code = 'IN_USE'
	);

	INSERT INTO ReservationSession (reservation_id, attendant_id, check_in_user_id, actual_start_time, space_initial_condition_id)
	VALUES (@reservation_id, @attendant_id, @checked_in_user_id, @actual_start_time, @space_initial_condition_id);

	UPDATE Reservation
	SET reservation_status_id = @reservation_status_id
	WHERE reservation_id = @reservation_id;

	UPDATE Space
	SET space_status_id = @space_status_id
	WHERE space_id = (
		SELECT br.space_id
		FROM Reservation r
			INNER JOIN BookingRequest br ON r.booking_request_id = r.booking_request_id
		WHERE reservation_id = @reservation_id
	);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_EndReservationSession
	@reservation_id CHAR(8),
	@space_final_condition_code VARCHAR(20),
	@usage_note NVARCHAR(250) = NULL
AS
BEGIN
	BEGIN TRANSACTION;
	DECLARE @actual_end_time AS DATETIME = GETDATE();

	IF NOT EXISTS (
		SELECT 1
		FROM Reservation r
		WHERE r.reservation_id = @reservation_id
	)
	THROW 52028, 'Reservation does not exist', 2;

	IF EXISTS (
		SELECT 1
		FROM Reservation r
			INNER JOIN lookup_table.ReservationStatus rs ON rs.reservation_status_id = r.reservation_status_id
		WHERE (
			r.reservation_id = @reservation_id AND
			rs.reservation_status_code != 'CHECKED_IN'
		)
	)
	THROW 52009, 'Reservation is not checked in', 1;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.SpaceCondition
		WHERE space_condition_code = @space_final_condition_code
	)
	THROW 52007, 'Invalid space condition', 2;

	DECLARE @space_final_condition_id AS TINYINT = (
		SELECT space_condition_id
		FROM lookup_table.SpaceCondition
		WHERE space_condition_code = @space_final_condition_code
	);
	DECLARE @reservation_status_id AS TINYINT = (
		SELECT reservation_status_id
		FROM lookup_table.ReservationStatus
		WHERE reservation_status_code = 'COMPLETED'
	);
	DECLARE @space_status_id AS TINYINT = (
		SELECT space_status_id
		FROM lookup_table.SpaceStatus
		WHERE space_status_code = 'AVAILABLE'
	);

	UPDATE ReservationSession
	SET actual_end_time = @actual_end_time, space_final_condition_id = @space_final_condition_id
	WHERE reservation_id = @reservation_id;

	UPDATE Reservation
	SET reservation_status_id = @reservation_status_id, usage_note = @usage_note
	WHERE reservation_id = @reservation_id;

	UPDATE Space
	SET space_status_id = @space_status_id
	WHERE space_id = (
		SELECT br.space_id
		FROM Reservation r
			INNER JOIN BookingRequest br ON r.booking_request_id = r.booking_request_id
		WHERE reservation_id = @reservation_id
	);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_NoShowReservation
	@reservation_id CHAR(8)
AS
BEGIN
	BEGIN TRANSACTION;
	DECLARE @reservation_status_id AS TINYINT = (
		SELECT reservation_status_id
		FROM lookup_table.ReservationStatus
		WHERE reservation_status_code = 'NO_SHOW'
	);

	UPDATE Reservation
	SET reservation_status_id = @reservation_status_id
	WHERE reservation_id = @reservation_id;
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_CreateMaintenance
	@maintenance_id CHAR(6),
	@space_id VARCHAR(10),
	@reporter_id CHAR(8),
	@maintenance_description NVARCHAR(250) = NULL
AS
BEGIN
	BEGIN TRANSACTION;
	IF NOT EXISTS (
		SELECT 1
		FROM Space s
		WHERE s.space_id = @space_id
	)
	THROW 52010, 'Space does not exist', 1;

	DECLARE @maintenance_status_id AS TINYINT = (
		SELECT maintenance_status_id
		FROM lookup_table.MaintenanceStatus
		WHERE maintenance_status_code = 'PENDING'
	);

	INSERT INTO Maintenance (maintenance_id, space_id, reporter_id, maintenance_description, maintenance_status_id)
	VALUES (@maintenance_id, @space_id, @reporter_id, @maintenance_description, @maintenance_status_id);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_StartMaintenanceSession
	@maintenance_id CHAR(6),
	@technician_id CHAR(8),
	@maintenance_impact_level_code VARCHAR(20)
AS
BEGIN
	BEGIN TRANSACTION
	DECLARE @maintenance_start_time AS DATETIME = GETDATE();

	IF EXISTS (
		SELECT 1
		FROM Maintenance m
			INNER JOIN lookup_table.MaintenanceStatus ms ON ms.maintenance_status_id = m.maintenance_status_id
		WHERE (
			m.maintenance_id = @maintenance_id AND
			ms.maintenance_status_code != 'PENDING'
		)
	)
	THROW 52010, 'Maintenance is not pending', 1;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.MaintenanceImpactLevel
		WHERE maintenance_impact_level_code = @maintenance_impact_level_code
	)
	THROW 52011, 'Invalid maintenance impact level', 1;

	DECLARE @maintenance_impact_level_id AS TINYINT = (
		SELECT maintenance_impact_level_id
		FROM lookup_table.MaintenanceImpactLevel
		WHERE maintenance_impact_level_code = @maintenance_impact_level_code
	);
	DECLARE @maintenance_status_id AS TINYINT = (
		SELECT maintenance_status_id
		FROM lookup_table.MaintenanceStatus
		WHERE maintenance_status_code = 'ONGOING'
	);
	DECLARE @space_status_id AS TINYINT = (
		SELECT space_status_id
		FROM lookup_table.SpaceStatus
		WHERE space_status_code = 'UNDER_CRIT_MAINT'
	);

	INSERT INTO MaintenanceSession (maintenance_id, technician_id, maintenance_start_time, maintenance_impact_level_id)
	VALUES (@maintenance_id, @technician_id, @maintenance_start_time, @maintenance_impact_level_id);

	UPDATE Maintenance
	SET maintenance_status_id = @maintenance_status_id
	WHERE maintenance_id = @maintenance_id;

	IF (@maintenance_impact_level_code = 'OUT_OF_SERVICE')
	UPDATE Space
	SET space_status_id = @space_status_id
	WHERE space_id = (
		SELECT m.space_id
		FROM Maintenance m
		WHERE m.maintenance_id = @maintenance_id
	);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_EndMaintenanceSession
	@maintenance_id CHAR(6),
	@result_note NVARCHAR(250) = NULL
AS
BEGIN
	BEGIN TRANSACTION
	DECLARE @maintenance_end_time AS DATETIME = GETDATE();

	IF EXISTS (
		SELECT 1
		FROM Maintenance m
			INNER JOIN lookup_table.MaintenanceStatus ms ON ms.maintenance_status_id = m.maintenance_status_id
		WHERE (
			m.maintenance_id = @maintenance_id AND
			ms.maintenance_status_code != 'ONGOING'
		)
	)
	THROW 52015, 'Maintenance is not ongoing', 1;

	DECLARE @maintenance_status_id AS TINYINT = (
		SELECT maintenance_status_id
		FROM lookup_table.MaintenanceStatus
		WHERE maintenance_status_code = 'COMPLETED'
	);
	DECLARE @space_status_id AS TINYINT = (
		SELECT space_status_id
		FROM lookup_table.SpaceStatus
		WHERE space_status_code = 'AVAILABLE'
	);

	UPDATE MaintenanceSession
	SET maintenance_end_time = @maintenance_end_time
	WHERE maintenance_id = @maintenance_id;

	UPDATE Maintenance
	SET maintenance_status_id = @maintenance_status_id
	WHERE maintenance_id = @maintenance_id;

	IF NOT EXISTS (
		SELECT 1
		FROM Maintenance m
			INNER JOIN MaintenanceSession mss ON mss.maintenance_id = m.maintenance_id
			INNER JOIN lookup_table.MaintenanceImpactLevel mil ON mil.maintenance_impact_level_id = mss.maintenance_impact_level_id
			INNER JOIN lookup_table.MaintenanceStatus ms ON ms.maintenance_status_id = m.maintenance_status_id
		WHERE (
			m.maintenance_id = @maintenance_id AND
			mil.maintenance_impact_level_code = 'OUT_OF_SERVICE' AND
			ms.maintenance_status_code = 'ONGOING'
		)
	)
	UPDATE Space
	SET space_status_id = @space_status_id
	WHERE space_id = (
		SELECT m.space_id
		FROM Maintenance m
		WHERE m.maintenance_id = @maintenance_id
	);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_EscalateMaintenance
	@maintenance_id CHAR(6)
AS
BEGIN
	BEGIN TRANSACTION;
	IF NOT EXISTS (
		SELECT 1
		FROM Maintenance m
			INNER JOIN lookup_table.MaintenanceStatus ms ON ms.maintenance_status_id = m.maintenance_status_id
		WHERE (
			m.maintenance_id = @maintenance_id AND
			maintenance_status_code = 'ONGOING'
		)
	)
	THROW 52015, 'Maintenance is not ongoing', 2

	IF NOT EXISTS (
		SELECT 1
		FROM MaintenanceSession ms
			INNER JOIN lookup_table.MaintenanceImpactLevel mil ON mil.maintenance_impact_level_id = ms.maintenance_impact_level_id
		WHERE (
			ms.maintenance_id = @maintenance_id AND
			maintenance_impact_level_code = 'OUT_OF_SERVICE'
		)
	)
	THROW 52019, 'Maintenance is already out-of-service', 1

	DECLARE @maintenance_impact_level_id AS TINYINT = (
		SELECT maintenance_impact_level_id
		FROM lookup_table.MaintenanceImpactLevel
		WHERE maintenance_impact_level_code = 'OUT_OF_SERVICE'
	);
	DECLARE @space_status_id AS TINYINT = (
		SELECT space_status_id
		FROM lookup_table.SpaceStatus
		WHERE space_status_code = 'UNDER_CRIT_MAINT'
	);

	UPDATE MaintenanceSession
	SET maintenance_impact_level_id = @maintenance_impact_level_id
	WHERE maintenance_id = @maintenance_id;

	UPDATE Space
	SET space_status_id = @space_status_id
	WHERE space_id = (
		SELECT s.space_status_id
		FROM Maintenance m
			INNER JOIN Space s ON s.space_id = m.space_id
		WHERE m.maintenance_id = @maintenance_id
	);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_DowngradeMaintenance
	@maintenance_id CHAR(6)
AS
BEGIN
	BEGIN TRANSACTION;
	IF NOT EXISTS (
		SELECT 1
		FROM Maintenance m
			INNER JOIN lookup_table.MaintenanceStatus ms ON ms.maintenance_status_id = m.maintenance_status_id
		WHERE (
			m.maintenance_id = @maintenance_id AND
			maintenance_status_code = 'ONGOING'
		)
	)
	THROW 52015, 'Maintenance is not ongoing', 3

	IF NOT EXISTS (
		SELECT 1
		FROM MaintenanceSession ms
			INNER JOIN lookup_table.MaintenanceImpactLevel mil ON mil.maintenance_impact_level_id = ms.maintenance_impact_level_id
		WHERE (
			ms.maintenance_id = @maintenance_id AND
			maintenance_impact_level_code = 'ADVISORY'
		)
	)
	THROW 52024, 'Maintenance is already advisory', 1

	DECLARE @maintenance_impact_level_id AS TINYINT = (
		SELECT maintenance_impact_level_id
		FROM lookup_table.MaintenanceImpactLevel
		WHERE maintenance_impact_level_code = 'AVAILABLE'
	);
	DECLARE @space_status_id AS TINYINT = (
		SELECT space_status_id
		FROM lookup_table.SpaceStatus
		WHERE space_status_code = 'UNDER_CRIT_MAINT'
	);

	UPDATE MaintenanceSession
	SET maintenance_impact_level_id = @maintenance_impact_level_id
	WHERE maintenance_id = @maintenance_id;

	IF NOT EXISTS (
		SELECT 1
		FROM Maintenance m
			INNER JOIN MaintenanceSession mss ON mss.maintenance_id = m.maintenance_id
			INNER JOIN  lookup_table.MaintenanceImpactLevel mil ON mil.maintenance_impact_level_id = mss.maintenance_impact_level_id
		WHERE (
			m.space_id = (SELECT space_id FROM Maintenance WHERE maintenance_id = @maintenance_id) AND
			mil.maintenance_impact_level_code = 'OUT_OF_SERVICE'
		)
	)
	UPDATE Space
	SET space_status_id = @space_status_id
	WHERE space_id = (
		SELECT s.space_status_id
		FROM Maintenance m
			INNER JOIN Space s ON s.space_id = m.space_id
		WHERE m.maintenance_id = @maintenance_id
	);
	COMMIT;
END
GO