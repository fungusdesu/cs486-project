CREATE DATABASE School;
GO
USE School;
GO

-----------------------------------------
-------- FUCKASS ENTITIES TABLES --------
-----------------------------------------
CREATE SCHEMA lookup_table
GO

CREATE TABLE lookup_table.SpaceType (
    space_type_id TINYINT IDENTITY(1, 1),
    space_type_code VARCHAR(20) NOT NULL,
    space_type_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_SpaceType_space_type_id
		PRIMARY KEY (space_type_id),
	CONSTRAINT UK_SpaceType_space_type_code
		UNIQUE (space_type_code),
    CONSTRAINT CHK_SpaceType_space_type_code_uppercase
        CHECK (space_type_code COLLATE Latin1_General_BIN = UPPER(space_type_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.UserRole (
    user_role_id TINYINT IDENTITY(1, 1),
    user_role_code VARCHAR(20) NOT NULL,
    user_role_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_UserRole_user_role_id
		PRIMARY KEY (user_role_id),
	CONSTRAINT UK_UserRole_user_role_code
		UNIQUE (user_role_code),
    CONSTRAINT CHK_UserRole_user_role_code_uppercase
        CHECK (user_role_code COLLATE Latin1_General_BIN = UPPER(user_role_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.SpaceStatus (
    space_status_id TINYINT IDENTITY(1, 1),
    space_status_code VARCHAR(20) NOT NULL,
    space_status_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_SpaceStatus_space_status_id
		PRIMARY KEY (space_status_id),
	CONSTRAINT UK_SpaceStatus_space_status_code
		UNIQUE (space_status_code),
    CONSTRAINT CHK_SpaceStatus_space_status_code_uppercase
        CHECK (space_status_code COLLATE Latin1_General_BIN = UPPER(space_status_code) COLLATE Latin1_General_BIN)
)

CREATE TABLE lookup_table.Department (
    department_id TINYINT IDENTITY(1, 1),
    department_code VARCHAR(20) NOT NULL,
    department_name NVARCHAR(50) NOT NULL,
	
	CONSTRAINT PK_Department_department_id
		PRIMARY KEY (department_id),
	CONSTRAINT UK_Department_department_code
		UNIQUE (department_code),
    CONSTRAINT CHK_Department_department_code_uppercase
        CHECK (department_code COLLATE Latin1_General_BIN = UPPER(department_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.FacilityType (
    facility_type_id TINYINT IDENTITY(1, 1),
    facility_type_code VARCHAR(20) NOT NULL,
    facility_type_name NVARCHAR(50) NOT NULL,
	
	CONSTRAINT PK_FacilityType_facility_type_id
		PRIMARY KEY (facility_type_id),
	CONSTRAINT UK_FacilityType_facility_type_code
		UNIQUE (facility_type_code),
    CONSTRAINT CHK_FacilityType_facility_type_code_uppercase
        CHECK (facility_type_code COLLATE Latin1_General_BIN = UPPER(facility_type_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.Purpose (
    purpose_id TINYINT IDENTITY(1,1),
    purpose_code VARCHAR(20) NOT NULL,
    purpose_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_Purpose_purpose_id
		PRIMARY KEY (purpose_id),
	CONSTRAINT UK_Purpose_purpose_code
		UNIQUE (purpose_code),
    CONSTRAINT CHK_Purpose_purpose_code_uppercase
        CHECK (purpose_code COLLATE Latin1_General_BIN = UPPER(purpose_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.Decision (
    decision_id TINYINT IDENTITY(1,1),
    decision_code VARCHAR(20) NOT NULL,
    decision_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_Decision_decision_id
		PRIMARY KEY (decision_id),
	CONSTRAINT UK_Decision_decision_code
		UNIQUE (decision_code),
    CONSTRAINT CHK_Decision_decision_code_uppercase
        CHECK (decision_code COLLATE Latin1_General_BIN = UPPER(decision_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.ReservationStatus (
    reservation_status_id TINYINT IDENTITY(1,1),
    reservation_status_code VARCHAR(20) NOT NULL,
    reservation_status_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_ReservationStatus_reservation_status_id
		PRIMARY KEY (reservation_status_id),
	CONSTRAINT UK_ReservationStatus_reservation_status_code
		UNIQUE (reservation_status_code),
    CONSTRAINT CHK_ReservationStatus_reservation_status_code_uppercase
        CHECK (reservation_status_code COLLATE Latin1_General_BIN = UPPER(reservation_status_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.MaintenanceStatus (
    maintenance_status_id TINYINT IDENTITY(1,1),
    maintenance_status_code VARCHAR(20) NOT NULL,
    maintenance_status_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_MaintenanceStatus_maintenance_status_id
		PRIMARY KEY (maintenance_status_id),
    CONSTRAINT UK_MaintenanceStatus_maintenance_status_code
		UNIQUE (maintenance_status_code),
    CONSTRAINT CHK_MaintenanceStatus_maintenance_status_code_uppercase
        CHECK (maintenance_status_code COLLATE Latin1_General_BIN = UPPER(maintenance_status_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.UserStatus (
    user_status_id TINYINT IDENTITY(1,1),
    user_status_code VARCHAR(20) NOT NULL,
    user_status_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_UserStatus_user_status_id
		PRIMARY KEY (user_status_id),
	CONSTRAINT UK_UserStatus_user_status_code
		UNIQUE (user_status_code),
    CONSTRAINT CHK_UserStatus_user_status_code_uppercase
        CHECK (user_status_code COLLATE Latin1_General_BIN = UPPER(user_status_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.SpaceCondition (
    space_condition_id TINYINT IDENTITY(1,1),
    space_condition_code VARCHAR(20) NOT NULL,
    space_condition_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_SpaceCondition_space_condition_id
		PRIMARY KEY (space_condition_id),
	CONSTRAINT UK_SpaceCondition_space_condition_code
		UNIQUE (space_condition_code),
    CONSTRAINT CHK_SpaceCondition_space_condition_code_uppercase
        CHECK (space_condition_code COLLATE Latin1_General_BIN = UPPER(space_condition_code) COLLATE Latin1_General_BIN)
)
GO

-------------------------------------------
---------- MAIN ENTITIES TABLES -----------
-------------------------------------------

CREATE TABLE [User] (
    user_id VARCHAR(8),
    surname NVARCHAR(30) NOT NULL,
    given_name NVARCHAR(20) NOT NULL,
    email NVARCHAR(255) NOT NULL,
    phone_number VARCHAR(10) NOT NULL,
    user_role_id TINYINT NOT NULL,
    department_id TINYINT,
    user_status_id TINYINT NOT NULL,

	CONSTRAINT PK_User_user_id
		PRIMARY KEY (user_id),
	
	CONSTRAINT UK_User_email
		UNIQUE (email),
	CONSTRAINT UK_User_phone_number
		UNIQUE (phone_number),

    CONSTRAINT FK_User_user_role_id
        FOREIGN KEY (user_role_id) REFERENCES lookup_table.UserRole(user_role_id),
    CONSTRAINT FK_User_department_id
        FOREIGN KEY (department_id) REFERENCES lookup_table.Department(department_id),
    CONSTRAINT FK_User_user_status_id
        FOREIGN KEY (user_status_id) REFERENCES lookup_table.UserStatus(user_status_id),

    CONSTRAINT CHK_User_user_id_format
        CHECK (user_id NOT LIKE '%[^0-9]%' AND LEN(user_id) = 8),
    CONSTRAINT CHK_User_user_email_format
        CHECK (email LIKE '_%@_%._%'),
    CONSTRAINT CHK_User_user_phone_number_not_empty
        CHECK (phone_number LIKE ('0%')),
	CONSTRAINT CHK_User_department_id_null_based_on_role
		CHECK (department_id IS NOT NULL AND user_id IN (1, 2, 3, 5))
)
GO

CREATE TABLE SpacePolicy (
	space_policy_id VARCHAR(5),
	booking_window_days SMALLINT,
	min_duration_minutes SMALLINT,
	max_duration_minutes SMALLINT,
	check_in_grace_minutes SMALLINT,

	CONSTRAINT PK_SpacePolicy_space_policy_id
		PRIMARY KEY (space_policy_id),

	CONSTRAINT CHK_SpacePolicy_space_policy_id_format
		CHECK (
			LEN(space_policy_id) = 5
			AND space_policy_id NOT LIKE '%^[A-Z]%'
		),
	CONSTRAINT CHK_SpacePolicy_max_higher_than_min
		CHECK (max_duration_minutes >= min_duration_minutes)
)
GO

CREATE TABLE Space (
    space_id VARCHAR(10),
    space_name NVARCHAR(30),
    space_type_id TINYINT,
    building CHAR NOT NULL,
    floor TINYINT NOT NULL,
    room_number TINYINT NOT NULL,
    capacity SMALLINT NOT NULL,
    space_status_id TINYINT NOT NULL,
    space_policy_id VARCHAR(5) NOT NULL,

	CONSTRAINT PK_Space_space_id
		PRIMARY KEY (space_id),

    CONSTRAINT FK_Space_space_type_id
        FOREIGN KEY (space_type_id) REFERENCES lookup_table.SpaceType(space_type_id),
    CONSTRAINT FK_Space_space_status_id
        FOREIGN KEY (space_status_id) REFERENCES lookup_table.SpaceStatus(space_status_id),
	CONSTRAINT FK_Space_space_policy_id
		FOREIGN KEY (space_policy_id) REFERENCES SpacePolicy(space_policy_id),

    CONSTRAINT CHK_Space_space_id_format
        CHECK (space_id NOT LIKE '%^[A-Za-z0-9]%'),
    CONSTRAINT CHK_Space_space_capacity_positive
        CHECK (capacity > 0)
)
GO

CREATE TABLE Facility (
    facility_type_id TINYINT NOT NULL,
    facility_sequence_number INT NOT NULL,
    facility_name NVARCHAR(30) NOT NULL,
    space_id VARCHAR(10),

	CONSTRAINT PK_Facility_ftid_fsn
		PRIMARY KEY (facility_type_id, facility_sequence_number),

	CONSTRAINT FK_Facility_facility_type_id
		FOREIGN KEY (facility_type_id) REFERENCES lookup_table.FacilityType(facility_type_id),
    CONSTRAINT FK_Facility_space_id
        FOREIGN KEY (space_id) REFERENCES Space(space_id),

    CONSTRAINT CHK_Facility_facility_sequence_number_positive
        CHECK (facility_sequence_number > 0)
)
GO

CREATE TABLE BookingRequest (
   booking_request_id VARCHAR(8),
   requested_start_time DATETIME NOT NULL,
   requested_end_time DATETIME NOT NULL,
   purpose_id TINYINT,
   expected_participants SMALLINT NOT NULL,

	CONSTRAINT PK_BookingRequest_booking_request_id
		PRIMARY KEY (booking_request_id),

    CONSTRAINT FK_BookingRequest_purpose_id
        FOREIGN KEY (purpose_id) REFERENCES lookup_table.Purpose(purpose_id),

    CONSTRAINT CHK_BookingRequest_booking_request_id_format
        CHECK (
            LEN(booking_request_id) = 8
            AND booking_request_id NOT LIKE '%^[a-z0-9]%'
        ),
    CONSTRAINT CHK_BookingRequest_booking_request_time_order
        CHECK (requested_end_time > requested_start_time),
    CONSTRAINT CHK_BookingRequest_expected_participants_positive
        CHECK (expected_participants > 0)  
)
GO

CREATE TABLE Reservation (
    reservation_id VARCHAR(8),
    booking_request_id VARCHAR(8),
    reservation_status_id TINYINT,
    usage_note NVARCHAR(50),

	CONSTRAINT PK_Reservation_reservation_id
		PRIMARY KEY (reservation_id),

    CONSTRAINT FK_Reservation_booking_request_id
        FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id),
    CONSTRAINT FK_Reservation_reservation_status_id
        FOREIGN KEY (reservation_status_id) REFERENCES lookup_table.ReservationStatus(reservation_status_id),

    CONSTRAINT CHK_Reservation_reservation_id_format
        CHECK (
            LEN(reservation_id) = 8
            AND reservation_id NOT LIKE '%[^A-Z0-9]%'
        )
)
GO

CREATE TABLE Maintenance (
    maintenance_id VARCHAR(6),
    reporter_id VARCHAR(8) NOT NULL,
    maintenance_description NVARCHAR(50),
    maintenance_status_id TINYINT NOT NULL,
    result_note NVARCHAR(250),

	CONSTRAINT PK_Maintenance_maintenance_id
		PRIMARY KEY (maintenance_id),

    CONSTRAINT FK_Maintenance_reporter_id
        FOREIGN KEY (reporter_id) REFERENCES [User](user_id),
    CONSTRAINT FK_Maintenance_maintenance_status_id
        FOREIGN KEY (maintenance_status_id) REFERENCES lookup_table.MaintenanceStatus(maintenance_status_id),

	CONSTRAINT CHK_Maintenance_maintenance_id_format
        CHECK (
            LEN(maintenance_id) = 6
            AND maintenance_id NOT LIKE '%^[a-z0-9]%'
        ),
    CONSTRAINT CHK_Maintenance_result_note_requires_complete_status
        CHECK (result_note IS NULL OR maintenance_status_id = 2) -- HARDCODED COMPLETED ID
)
GO

----------------------------------------
------- RELATIONSHIP AND JTABLES -------
----------------------------------------
CREATE SCHEMA junction_table

CREATE TABLE junction_table.Booking (
	booking_request_id VARCHAR(8) NOT NULL,
	user_id VARCHAR(8) NOT NULL,
	space_id VARCHAR(10) NOT NULL,

	CONSTRAINT PK_Booking_brid_uid_sid
		PRIMARY KEY (booking_request_id, user_id, space_id),

	CONSTRAINT FK_Booking_booking_request_id
		FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id),
	CONSTRAINT FK_Booking_user_id
		FOREIGN KEY (user_id) REFERENCES [User](user_id),
	CONSTRAINT FK_Booking_space_id
		FOREIGN KEY (space_id) REFERENCES Space(space_id)
)
GO

CREATE TABLE junction_table.Review (
	booking_request_id VARCHAR(8) NOT NULL,
	reviewer_id VARCHAR(8),
	decision_id TINYINT NOT NULL,
	decision_time DATETIME,
	decision_note NVARCHAR(250),
	rejection_reason NVARCHAR(250),

	CONSTRAINT PK_Review_brid_rid
		PRIMARY KEY (booking_request_id, reviewer_id),

	CONSTRAINT FK_Review_booking_request_id
		FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id),
	CONSTRAINT FK_Review_reviewer_id
		FOREIGN KEY (reviewer_id) REFERENCES [User](user_id),
	CONSTRAINT FK_Review_decision_id
		FOREIGN KEY (decision_id) REFERENCES lookup_table.Decision(decision_id),

	CONSTRAINT CHK_Review_decision_time_null_based_on_decision_id
		CHECK (
			((decision_id = 1 OR decision_id = 4) AND (decision_time IS NOT NULL)) OR
			((decision_id = 2 OR decision_id = 3) AND (decision_time IS NULL))
		),
	CONSTRAINT CHK_Review_decision_note_null_based_on_decision_time
		CHECK (decision_time IS NOT NULL OR decision_note IS NULL),
	CONSTRAINT CHK_Review_rejection_reason_null_based_on_decision_id
		CHECK (rejection_reason IS NULL OR decision_id = 3),
	CONSTRAINT CHK_Review_reviewer_id_null_based_on_decision_id
		CHECK (
			((decision_id = 2 OR decision_id = 3) AND (reviewer_id IS NOT NULL)) OR
			((decision_id = 1 OR decision_id = 4) AND (reviewer_id IS NULL))
		)
)
GO

CREATE TABLE junction_table.ReservationCheckin (
	reservation_id VARCHAR(8) NOT NULL,
	attendant_id VARCHAR(8) NOT NULL,
	check_in_user_id VARCHAR(8) NOT NULL,
	actual_start_time DATETIME NOT NULL,
	actual_end_time DATETIME,
	space_initial_condition_id TINYINT NOT NULL,
	space_final_condition_id TINYINT,

	CONSTRAINT PK_ReservationCheckin_rid_aid_ciuid
		PRIMARY KEY (reservation_id, attendant_id, check_in_user_id),
	
	CONSTRAINT FK_ReservationCheckin_reservation_id
		FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id),
	CONSTRAINT FK_ReservationCheckin_attendant_id
		FOREIGN KEY (attendant_id) REFERENCES [User](user_id),
	CONSTRAINT FK_ReservationCheckin_check_in_user_id
		FOREIGN KEY (check_in_user_id) REFERENCES [User](user_id),

	CONSTRAINT CHK_ReservationCheckin_time_order
		CHECK ((actual_end_time IS NOT NULL AND actual_end_time > actual_start_time) OR (actual_end_time IS NULL))
)
GO

CREATE TABLE junction_table.Maintaining (
    maintenance_id VARCHAR(6),
    technician_id VARCHAR(8) NOT NULL,
    space_id VARCHAR(10) NOT NULL,
    maintenance_start_time DATETIME NOT NULL,
    maintenance_end_time DATETIME,

	CONSTRAINT PK_Maintaining_maintenance_id
		PRIMARY KEY (maintenance_id),

    CONSTRAINT FK_Maintaining_maintenance_id
        FOREIGN KEY (maintenance_id) REFERENCES Maintenance(maintenance_id),
    CONSTRAINT FK_Maintaining_maintenance_technician
        FOREIGN KEY (technician_id) REFERENCES [User](user_id),
    CONSTRAINT FK_maintenance_space
        FOREIGN KEY (space_id) REFERENCES Space(space_id),
    
	CONSTRAINT CHK_maintenance_time_order
		CHECK ((maintenance_end_time IS NOT NULL AND maintenance_end_time > maintenance_start_time) OR (maintenance_end_time IS NULL))
)
GO

----------------------------------------
--------------- Triggas ----------------
----------------------------------------
CREATE TRIGGER trg_booking_request_capacity
ON BookingRequest
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
		INNER JOIN junction_table.Booking b ON b.booking_request_id = i.booking_request_id
        INNER JOIN Space s ON s.space_id = b.space_id
        WHERE i.expected_participants > s.capacity
    )
    BEGIN
        RAISERROR ('Expected participants cannot exceed the booked space capacity', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

CREATE TRIGGER trg_check_in_actual_times
ON junction_table.ReservationCheckin
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN Reservation r ON r.reservation_id = i.reservation_id
        INNER JOIN lookup_table.ReservationStatus rs ON rs.reservation_status_id = r.reservation_status_id
        WHERE i.actual_start_time IS NOT NULL
            AND rs.reservation_status_code = 'NO_SHOW'
    )
    BEGIN
        RAISERROR ('Actual start time cannot exist when the reservation status is no-show', 16, 1)
        ROLLBACK TRANSACTION
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN Reservation r ON r.reservation_id = i.reservation_id
        INNER JOIN lookup_table.ReservationStatus rs ON rs.reservation_status_id = r.reservation_status_id
        WHERE i.actual_end_time IS NOT NULL
            AND rs.reservation_status_code != 'COMPLETED'
    )
    BEGIN
        RAISERROR ('Actual end time cannot exist unless the reservation status is completed', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

CREATE TRIGGER trg_maintenance_result_note
ON Maintenance 
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN lookup_table.MaintenanceStatus ms ON ms.maintenance_status_id = i.maintenance_status_id
        WHERE i.result_note IS NOT NULL
            AND ms.maintenance_status_code != 'COMPLETED'
    )
    BEGIN
        RAISERROR ('Result note cannot exist unless the maintenance status is completed', 16, 1)
        ROLLBACK TRANSACTION
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN lookup_table.MaintenanceStatus ms ON ms.maintenance_status_id = i.maintenance_status_id
		INNER JOIN junction_table.Maintaining m ON m.maintenance_id = i.maintenance_id
        WHERE m.maintenance_end_time IS NOT NULL
            AND ms.maintenance_status_name != 'completed'
    )
    BEGIN
        RAISERROR ('Maintenance end time cannot exist unless the maintenance status is completed', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

CREATE TRIGGER trg_booker_acc_status
ON BookingRequest
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
		INNER JOIN junction_table.Booking b ON b.booking_request_id = i.booking_request_id
        INNER JOIN [User] u ON u.user_id = b.user_id
        INNER JOIN lookup_table.UserStatus us ON us.user_status_id = u.user_status_id
        WHERE us.user_status_code != 'ACTIVE'
    )
    BEGIN
        RAISERROR('Users who does not have an active account cannot book a room',  16, 1);
        ROLLBACK TRANSACTION
    END
END
GO

CREATE TRIGGER trg_decision_maker_acc_role
ON junction_table.Review
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN [User] u ON u.user_id = i.reviewer_id
        INNER JOIN lookup_table.UserRole ur ON ur.user_role_id = u.user_role_id
        WHERE ur.user_role_code NOT IN ('FACILITY_STAFF', 'FACILITY_MGR')
    )
    BEGIN
        RAISERROR('Only facility staff and manager can approve a booking request',  16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

CREATE TRIGGER trg_booking_requested_time_fit_policy
ON BookingRequest
AFTER INSERT, UPDATE
AS
BEGIN
	IF EXISTS (
		SELECT 1
		FROM inserted i
		INNER JOIN junction_table.Booking b ON b.booking_request_id = i.booking_request_id
		INNER JOIN Space s ON s.space_id = b.space_id
		INNER JOIN SpacePolicy sp ON sp.space_policy_id = s.space_policy_id
		WHERE DATEDIFF(MINUTE, i.requested_end_time, i.requested_start_time) >= sp.max_duration_minutes
	)
	BEGIN
		RAISERROR('Requested time exceeds policy max duration', 16, 1)
		ROLLBACK TRANSACTION
	END

	IF EXISTS (
		SELECT 1
		FROM inserted i
		INNER JOIN junction_table.Booking b ON b.booking_request_id = i.booking_request_id
		INNER JOIN Space s ON s.space_id = b.space_id
		INNER JOIN SpacePolicy sp ON sp.space_policy_id = s.space_policy_id
		WHERE DATEDIFF(MINUTE, i.requested_end_time, i.requested_start_time) <= sp.min_duration_minutes
	)
	BEGIN
		RAISERROR('Requested time falls below policy min duration', 16, 1)
		ROLLBACK TRANSACTION
	END
END
GO

-------------------------------------
------------ LOOKUP DATA ------------
-------------------------------------
INSERT INTO lookup_table.SpaceType (space_type_code, space_type_name) VALUES
    ('AUDITORIUM', 'Auditorium'),
    ('CLASSROOM', 'Classroom'),
    ('LECTURE_HALL', 'Lecture Hall'),
    ('MEETING_ROOM', 'Meeting Room'),
    ('STUDY', 'Study'),
    ('LIBRARY_ROOM', 'Library Room'),
    ('STAFFROOM', 'Staffroom'),
    ('LAB', 'Laboratory')

INSERT INTO lookup_table.UserRole (user_role_code, user_role_name) VALUES
    ('STUDENT', 'Student'),
    ('LECTURER', 'Lecturer'),
    ('TA', 'Teaching Assistant'),
    ('FACILITY_STAFF', 'Facility Staff'),
    ('DEPT_ADMIN', 'Department Administrator'),
    ('FACILITY_MGR', 'Facility Manager')

INSERT INTO lookup_table.SpaceStatus (space_status_code, space_status_name) VALUES
    ('AVAILABLE', 'Available'),
    ('IN_USE', 'In use'),
    ('UNDER_MAINT', 'Under maintenance'),
    ('TEMP_CLOSED', 'Temporarily closed'),
    ('RETIRED', 'Retired')

INSERT INTO lookup_table.Department (department_code, department_name) VALUES
    ('IT', 'Information Technology'),
    ('TCS', 'Theoretical Computer Science'),
    ('AI', 'Artificial Intelligence'),
    ('SE', 'Software Engineering'),
    ('CRYP', 'Cryptography'),
    ('IC', 'Integrated Circuits')

INSERT INTO lookup_table.FacilityType (facility_type_code, facility_type_name) VALUES
    ('CHR', 'Chair'),
    ('AIC', 'Air Conditioner'),
    ('PRO', 'Projector'),
    ('WHB', 'Whiteboard'),
    ('DSK', 'Desk')

INSERT INTO lookup_table.Purpose (purpose_code, purpose_name) VALUES 
	('LECTURE', 'Lecture'),
	('EXAM', 'Examination'),
	('SEMINAR', 'Seminar'),
	('WORKSHOP', 'Workshop'),
	('MEETING', 'Meeting'),
	('STUDENT_ACTIVITY', 'Student activity'),
	('ADMIN_EVENT', 'Administrative event')

INSERT INTO lookup_table.Decision (decision_code, decision_name) VALUES 
	('PENDING', 'Pending'),
	('APPROVED', 'Approved'),
	('REJECTED', 'Rejected'),
	('CANCELLED', 'Cancelled')

INSERT INTO lookup_table.ReservationStatus (reservation_status_code, reservation_status_name) VALUES 
	('PENDING', 'Pending'),
	('CHECKED_IN', 'Checked in'),
	('COMPLETED', 'Completed'),
	('NO_SHOW', 'No-show')

INSERT INTO lookup_table.MaintenanceStatus (maintenance_status_code, maintenance_status_name) VALUES 
	('ONGOING', 'Ongoing'),
	('COMPLETED', 'Completed')

INSERT INTO lookup_table.UserStatus (user_status_code, user_status_name) VALUES 
	('ACTIVE', 'Active'),
	('INACTIVE', 'Inactive'),
	('DISABLED', 'Disabled')

INSERT INTO lookup_table.SpaceCondition (space_condition_code, space_condition_name) VALUES 
	('GOD_FORSAKEN', 'God-forsaken'),
	('BAD', 'Bad'),
	('GOOD', 'Good'),
	('GREAT', 'Great'),
	('PERFECT', 'Perfect')
GO
