SET NOEXEC ON;
GO

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

	CONSTRAINT PK_space_type_id
		PRIMARY KEY (space_type_id),
	CONSTRAINT UK_space_type_code
		UNIQUE (space_type_code),
    CONSTRAINT CHK_space_type_code_uppercase
        CHECK (space_type_code COLLATE Latin1_General_BIN = UPPER(space_type_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.UserRole (
    user_role_id TINYINT IDENTITY(1, 1),
    user_role_code VARCHAR(20) NOT NULL,
    user_role_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_user_role_id
		PRIMARY KEY (user_role_id),
	CONSTRAINT UK_user_role_code
		UNIQUE (user_role_code),
    CONSTRAINT CHK_user_role_code_uppercase
        CHECK (user_role_code COLLATE Latin1_General_BIN = UPPER(user_role_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.SpaceStatus (
    space_status_id TINYINT IDENTITY(1, 1),
    space_status_code VARCHAR(20) NOT NULL,
    space_status_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_space_status_id
		PRIMARY KEY (space_status_id),
	CONSTRAINT UK_space_status_code
		UNIQUE (space_status_code),
    CONSTRAINT CHK_space_status_code_uppercase
        CHECK (space_status_code COLLATE Latin1_General_BIN = UPPER(space_status_code) COLLATE Latin1_General_BIN)
)

CREATE TABLE lookup_table.Department (
    department_id TINYINT IDENTITY(1, 1),
    department_code VARCHAR(20) NOT NULL,
    department_name NVARCHAR(50) NOT NULL,
	
	CONSTRAINT PK_department_id
		PRIMARY KEY (department_id),
	CONSTRAINT UK_department_code
		UNIQUE (department_code),
    CONSTRAINT CHK_department_code_uppercase
        CHECK (department_code COLLATE Latin1_General_BIN = UPPER(department_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.FacilityType (
    facility_type_id TINYINT IDENTITY(1, 1),
    facility_type_code VARCHAR(20) NOT NULL,
    facility_type_name NVARCHAR(50) NOT NULL,
	
	CONSTRAINT PK_facility_type_id
		PRIMARY KEY (facility_type_id),
	CONSTRAINT UK_facility_type_code
		UNIQUE (facility_type_code),
    CONSTRAINT CHK_facility_type_code_uppercase
        CHECK (facility_type_code COLLATE Latin1_General_BIN = UPPER(facility_type_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.Purpose (
    purpose_id TINYINT IDENTITY(1,1),
    purpose_code VARCHAR(20) NOT NULL,
    purpose_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_purpose_id
		PRIMARY KEY (purpose_id),
	CONSTRAINT UK_purpose_code
		UNIQUE (purpose_code),
    CONSTRAINT CHK_purpose_code_uppercase
        CHECK (purpose_code COLLATE Latin1_General_BIN = UPPER(purpose_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.Decision (
    decision_id TINYINT IDENTITY(1,1),
    decision_code VARCHAR(20) NOT NULL,
    decision_name NVARCHAR(50) NOT NULL,
	CONSTRAINT PK_decision_id
		PRIMARY KEY (decision_id),
	CONSTRAINT UK_decision_code
		UNIQUE (decision_code),
    CONSTRAINT CHK_decision_code_uppercase
        CHECK (decision_code COLLATE Latin1_General_BIN = UPPER(decision_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.ReservationStatus (
    reservation_status_id TINYINT IDENTITY(1,1),
    reservation_status_code VARCHAR(20) NOT NULL,
    reservation_status_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_reservation_status_id
		PRIMARY KEY (reservation_status_id),
	CONSTRAINT UK_reservation_status_code
		UNIQUE (reservation_status_code),
    CONSTRAINT CHK_reservation_status_code_uppercase
        CHECK (reservation_status_code COLLATE Latin1_General_BIN = UPPER(reservation_status_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.MaintenanceStatus (
    maintenance_status_id TINYINT IDENTITY(1,1),
    maintenance_status_code VARCHAR(20) NOT NULL,
    maintenance_status_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_maintenance_status_id
		PRIMARY KEY (maintenance_status_id),
    CONSTRAINT UK_maintenance_status_code
		UNIQUE (maintenance_status_code),
    CONSTRAINT CHK_maintenance_status_code_uppercase
        CHECK (maintenance_status_code COLLATE Latin1_General_BIN = UPPER(maintenance_status_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.UserStatus (
    user_status_id TINYINT IDENTITY(1,1),
    user_status_code VARCHAR(20) NOT NULL,
    user_status_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_user_status_id
		PRIMARY KEY (user_status_id),
	CONSTRAINT UK_user_status_code
		UNIQUE (user_status_code),
    CONSTRAINT CHK_user_status_code_uppercase
        CHECK (user_status_code COLLATE Latin1_General_BIN = UPPER(user_status_code) COLLATE Latin1_General_BIN)
)
GO

CREATE TABLE lookup_table.SpaceCondition (
    space_condition_id TINYINT IDENTITY(1,1),
    space_condition_code VARCHAR(20) NOT NULL,
    space_condition_name NVARCHAR(50) NOT NULL,

	CONSTRAINT PK_space_condition_id
		PRIMARY KEY (space_condition_id),
	CONSTRAINT UK_space_condition_code
		UNIQUE (space_condition_code),
    CONSTRAINT CHK_space_condition_code_uppercase
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

	CONSTRAINT PK_user_id
		PRIMARY KEY (user_id),
	
	CONSTRAINT UK_email
		UNIQUE (email),
	CONSTRAINT UK_phone_number
		UNIQUE (phone_number),

    CONSTRAINT FK_user_role_id
        FOREIGN KEY (user_role_id) REFERENCES UserRole(user_role_id),
    CONSTRAINT FK_department_id
        FOREIGN KEY (department_id) REFERENCES Department(department_id),
    CONSTRAINT FK_user_status_id
        FOREIGN KEY (user_status_id) REFERENCES UserStatus(user_status_id),

    CONSTRAINT CHK_user_id_format
        CHECK (user_id NOT LIKE '%[^0-9]%' AND LEN(user_id) = 8),
    CONSTRAINT CHK_user_email_format
        CHECK (email LIKE '_%@_%._%'),
    CONSTRAINT CHK_user_phone_number_not_empty
        CHECK (phone_number LIKE ('0%'))
)
GO

CREATE TABLE SpacePolicy (
	space_policy_id VARCHAR(5),
	booking_window_days SMALLINT,
	min_duration_minutes SMALLINT,
	max_duration_minutes SMALLINT,
	check_in_grace_minutes SMALLINT,

	CONSTRAINT PK_space_policy_id
		PRIMARY KEY (space_policy_id),

	CONSTRAINT CHK_space_policy_id_format
		CHECK (
			LEN(space_policy_id) = 5
			AND space_policy_id NOT LIKE '%^[A-Z]%'
		),
	CONSTRAINT CHK_max_higher_than_min
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

	CONSTRAINT PK_space_id
		PRIMARY KEY (space_id),

    CONSTRAINT FK_space_type_id
        FOREIGN KEY (space_type_id) REFERENCES lookup_table.SpaceType(space_type_id),
    CONSTRAINT FK_space_status_id
        FOREIGN KEY (space_status_id) REFERENCES lookup_table.SpaceStatus(space_status_id),
	CONSTRAINT FK_space_policy_id
		FOREIGN KEY (space_policy_id) REFERENCES SpacePolicy(space_policy_id),

    CONSTRAINT CHK_space_id_format
        CHECK (space_id NOT LIKE '%^[A-Za-z0-9]%'),
    CONSTRAINT CHK_space_capacity_positive
        CHECK (capacity > 0)
)
GO

CREATE TABLE Facility (
    facility_type_id TINYINT NOT NULL,
    facility_sequence_number INT NOT NULL,
    facility_name NVARCHAR(30) NOT NULL,
    space_id VARCHAR(10),

	CONSTRAINT PK_facility_type_id_facility_sequence_number
		PRIMARY KEY (facility_type_id, facility_sequence_number),

	CONSTRAINT FK_facility_type_id
		FOREIGN KEY (facility_type_id) REFERENCES lookup_table.FacilityType(facility_type_id),
    CONSTRAINT FK_space_id
        FOREIGN KEY (space_id) REFERENCES Space(space_id),

    CONSTRAINT CHK_facility_sequence_number_positive
        CHECK (facility_sequence_number > 0)
)
GO

CREATE TABLE BookingRequest (
   booking_request_id VARCHAR(8),
   requested_start_time DATETIME NOT NULL,
   requested_end_time DATETIME NOT NULL,
   purpose_id TINYINT,
   expected_participants SMALLINT NOT NULL,

	CONSTRAINT PK_booking_request_id
		PRIMARY KEY (booking_request_id),

    CONSTRAINT FK_purpose_id
        FOREIGN KEY (purpose_id) REFERENCES lookup_table.Purpose(purpose_id),

    CONSTRAINT CHK_booking_request_id_format
        CHECK (
            LEN(booking_request_id) = 8
            AND booking_request_id NOT LIKE '%^[a-z0-9]%'
        ),
    CONSTRAINT CHK_booking_request_time_order
        CHECK (requested_end_time > requested_start_time),
    CONSTRAINT CHK_booking_request_expected_participants_positive
        CHECK (expected_participants > 0)  
)

CREATE TABLE Reservation (
    reservation_id VARCHAR(8),
    booking_request_id VARCHAR(8),
    reservation_status_id TINYINT,
    usage_note NVARCHAR(50),

	CONSTRAINT PK_reservation_id
		PRIMARY KEY (reservation_id),

    CONSTRAINT FK_booking_request_id
        FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id),
    CONSTRAINT fk_reservation_status_id
        FOREIGN KEY (reservation_status_id) REFERENCES lookup_table.ReservationStatus(reservation_status_id),

    CONSTRAINT CHK_reservation_id_format
        CHECK (
            LEN(reservation_id) = 8
            AND reservation_id NOT LIKE '%[^A-Z0-9]%'
        )
)

CREATE TABLE BookingDecision (
    booking_request_id VARCHAR(8) PRIMARY KEY,
    decision_maker_id VARCHAR(8) NOT NULL,

    decision_status_id TINYINT NOT NULL,
    decision_time DATETIME NOT NULL,
    decision_note NVARCHAR(500) NULL,
    rejection_reason NVARCHAR(500) NULL,

    CONSTRAINT fk_booking_decision_request
        FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id),
    CONSTRAINT fk_booking_decision_user
        FOREIGN KEY (decision_maker_id) REFERENCES [User](user_id),
    CONSTRAINT fk_booking_decision_status
        FOREIGN KEY (decision_status_id) REFERENCES DecisionStatus(status_id),
    CONSTRAINT chk_requires_decision_time
        CHECK (decision_time IS NOT NULL)
)

CREATE TABLE ReservationCheckIn (
    reservation_id VARCHAR(8) PRIMARY KEY,
    attendant_id VARCHAR(8) NOT NULL,
    checked_in_user_id VARCHAR(8) NOT NULL,

    check_in_status NVARCHAR(20) NOT NULL,

    actual_start_time DATETIME NOT NULL,
    actual_end_time DATETIME NOT NULL,
    actual_time_slot AS DATEDIFF(MINUTE, actual_start_time, actual_end_time),

    space_initial_condition_id TINYINT NULL,
    space_final_condition_id TINYINT NULL,

    usage_note NVARCHAR(500) NULL,

    CONSTRAINT fk_check_in_reservation
        FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id),
    CONSTRAINT fk_check_in_attendant
        FOREIGN KEY (attendant_id) REFERENCES [User](user_id),
    CONSTRAINT fk_check_in_user
        FOREIGN KEY (checked_in_user_id) REFERENCES [User](user_id),
    CONSTRAINT fk_check_in_initial_condition
        FOREIGN KEY (space_initial_condition_id) REFERENCES SpaceStatus(status_id),
    CONSTRAINT fk_check_in_final_condition
        FOREIGN KEY (space_final_condition_id) REFERENCES SpaceStatus(status_id),
    CONSTRAINT chk_check_in_status
        CHECK (check_in_status IN ('checked in', 'not checked in', 'completed', 'no-show')),
    CONSTRAINT chk_time_order
        CHECK (actual_start_time < actual_end_time)
)

CREATE TABLE Maintenance (
    maintenance_id VARCHAR(6),
    reporter_id VARCHAR(8) NOT NULL,
    maintenance_description NVARCHAR(50),
    maintenance_status_id TINYINT NOT NULL,
    result_note NVARCHAR(250),

	CONSTRAINT PK_maintenance_id
		PRIMARY KEY (maintenance_id),

    CONSTRAINT FK_reporter_id
        FOREIGN KEY (reporter_id) REFERENCES [User](user_id),
    CONSTRAINT FK_maintenance_status_id
        FOREIGN KEY (maintenance_status_id) REFERENCES lookup_table.MaintenanceStatus(maintenance_status_id),

	CONSTRAINT CHK_maintenance_id_format
        CHECK (
            LEN(maintenance_id) = 6
            AND maintenance_id NOT LIKE '%^[a-z0-9]%'
        ),
    CONSTRAINT CHK_result_note_requires_complete_status
        CHECK (result_note IS NULL OR maintenance_status_id = 2) -- HARDCODED COMPLETED ID
)

CREATE TABLE Maintaining (
    maintenance_id VARCHAR(8) PRIMARY KEY,
    technician_id VARCHAR(8) NOT NULL,

    space_id VARCHAR(10) NOT NULL,

    maintenance_start_time DATETIME NOT NULL,
    maintenance_end_time DATETIME NOT NULL,
    maintenance_time_slot AS DATEDIFF(MINUTE, maintenance_start_time, maintenance_end_time),

    CONSTRAINT fk_maintenance_id
        FOREIGN KEY (maintenance_id) REFERENCES Maintenance(maintenance_id),
    CONSTRAINT fk_maintenance_technician
        FOREIGN KEY (technician_id) REFERENCES [User](user_id),
    CONSTRAINT fk_maintenance_space
        FOREIGN KEY (space_id) REFERENCES Space(space_id),
    CONSTRAINT chk_maintenance_time_order
        CHECK (maintenance_end_time > maintenance_start_time),
    CONSTRAINT chk_maintenance_id_format
        CHECK (
            LEN(maintenance_id) = 6
            AND maintenance_id COLLATE Latin1_General_BIN NOT LIKE '%[^a-z0-9]%'
        )

)

GO

-- Triggers
CREATE TRIGGER trg_booking_request_capacity
ON BookingRequest
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN Space s ON s.space_id = i.space_id
        WHERE i.expected_participants > s.capacity
    )
    BEGIN
        RAISERROR ('expected_participants cannot exceed the booked space capacity.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

CREATE TRIGGER trg_booking_decision_rejection_reason
ON BookingDecision
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN DecisionStatus ds ON ds.status_id = i.decision_status_id
        WHERE i.rejection_reason IS NOT NULL
            AND ds.status_name <> 'rejected'
    )
    BEGIN
        RAISERROR ('rejection_reason cannot exist unless the decision is rejected.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

CREATE TRIGGER trg_check_in_actual_times
ON ReservationCheckIn
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN Reservation r ON r.reservation_id = i.reservation_id
        INNER JOIN ReservationStatus rs ON rs.status_id = r.reservation_status_id
        WHERE i.actual_start_time IS NOT NULL
            AND rs.status_name = 'no-show'
    )
    BEGIN
        RAISERROR ('actual_start_time cannot exist when the reservation status is no-show.', 16, 1);
        ROLLBACK TRANSACTION;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN Reservation r ON r.reservation_id = i.reservation_id
        INNER JOIN ReservationStatus rs ON rs.status_id = r.reservation_status_id
        WHERE i.actual_end_time IS NOT NULL
            AND rs.status_name <> 'completed'
    )
    BEGIN
        RAISERROR ('actual_end_time cannot exist unless the reservation status is completed.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

CREATE TRIGGER trg_maintenance_result_note
ON Maintenance 
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN MaintenanceStatus ms ON ms.status_id = i.maintenance_status
        WHERE i.result_note IS NOT NULL
            AND ms.status_name <> 'completed'
    )
    BEGIN
        RAISERROR ('result_note cannot exist unless the maintenance status is completed.', 16, 1);
        ROLLBACK TRANSACTION;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN MaintenanceStatus ms ON ms.status_id = i.maintenance_status
        WHERE i.maintenance_end_time IS NOT NULL
            AND ms.status_name <> 'completed'
    )
    BEGIN
        RAISERROR ('maintenance_end_time cannot exist unless the maintenance status is completed.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

CREATE TRIGGER trg_booker_acc_status
ON BookingRequest
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i 
        JOIN [User] u ON u.user_id = i.booker_id
        JOIN UserAccountStatus uas ON uas.status_id = u.account_status_id
        WHERE uas.status_name <> 'active'
    )
    BEGIN
        RAISERROR('users who does not have an active account cannot book a room.',  16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

CREATE TRIGGER trg_decision_maker_acc_role
ON BookingDecision
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted I
        JOIN [User] u ON u.user_id = i.decision_maker_id
        JOIN UserRole ur ON ur.role_id = u.user_role_id 
        WHERE ur.role_name NOT IN ('facility staff', 'facility manager')
    )
    BEGIN
        RAISERROR('only facility staff and manager can approve a booking request.',  16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

INSERT INTO UserRole (role_code, role_name) VALUES 
("STUDENT", "student"), 
("LECTURER", "lecturer"), 
("TEACHING_ASSISTANT", "teaching assistant"), 
("FACILITY_STAFF", "facility staff"), 
("DEPARTMENT_ADMINISTRATOR", "department administrator"), 
("FACILITY_MANAGER", "facility manager");

INSERT INTO UserAccountStatus(status_code, status_name) VALUES 
("PENDING_APPROVAL", "pending approval"),
("ACTIVE", "active"),
("SUSPENDED", "suspended"),
("DISABLED", "disabled");

INSERT INTO DepartmentName(department_code, department_name) VALUES
('MCS', 'Faculty of Mathematics and Computer Science'),
('IT', 'Faculty of Information Technology'),
('PEP', 'Faculty of Physics and Engineering Physics'),
('EET', 'Faculty of Electronics and Telecommunications'),
('CHEM', 'Faculty of Chemistry'),
('BIO', 'Faculty of Biology and Biotechnology'),
('GEO', 'Faculty of Geology'),
('ENV', 'Faculty of Environment'),
('MST', 'Faculty of Materials Science and Technology'),
('IDS', 'Faculty of Interdisciplinary Sciences');

INSERT INTO SpaceStatus (status_code, status_name) VALUES 
("AVAILABLE", "available"), 
("IN_USE", "in use"), 
("UNDER_MAINTENANCE", "under maintenance"), 
("CLOSED", "closed"), 
("RETIRED", "retired");

INSERT INTO SpaceType (type_code, type_name) VALUES
("CLASSROOM", "classroom"),
("MEETING_ROOM", "meeting room"),
("LABORATORY", "laboratory"),
("LECTURE_HALL", "lecture hall"),
("OTHER", "other");

INSERT INTO ReservationStatus (status_code, status_name) VALUES 
("PENDING", "pending"),
("APPROVED", "approved"), 
("REJECTED", "rejected"), 
("CANCELLED", "cancelled"), 
("OTHER", "other");

INSERT INTO Purpose (purpose_code, purpose_name)
VALUES
    ('LECTURE', 'Lecture'),
    ('EXAM', 'Examination'),
    ('SEMINAR', 'Seminar'),
    ('WORKSHOP', 'Workshop'),
    ('MEETING', 'Meeting'),
    ('STUDENT_ACTIVITY', 'Student activity'),
    ('ADMIN_EVENT', 'Administrative event');
    
INSERT INTO DecisionStatus (status_code, status_name) VALUES
("ACCEPTED", "accepted"),
("REJECTED", "rejected"),
("CANCELLED", "cancelled");

INSERT INTO MaintenanceStatus (status_code, status_name) VALUES 
("PENDING", "pending"), 
("IN_PROGRESS", "in progress"), 
("COMPLETED", "completed"), 
("CANCELLED", "cancelled"), 
("OTHER", "other");

GO

SET NOEXEC OFF;
GO
