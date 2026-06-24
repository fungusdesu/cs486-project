SET NOEXEC ON;
GO

CREATE DATABASE School;
GO
USE School;
GO

CREATE TABLE [User] (
    user_id VARCHAR(8) PRIMARY KEY,
    given_name NVARCHAR(20) NOT NULL,
    surname NVARCHAR(100) NOT NULL,
    full_name AS CONCAT(surname, ' ', given_name),
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(10) NOT NULL UNIQUE,

    user_role_id TINYINT NOT NULL,
    department_id TINYINT NOT NULL,
    account_status_id TINYINT NOT NULL,

    CONSTRAINT fk_user_role
        FOREIGN KEY (user_role_id) REFERENCES UserRole(role_id),
    CONSTRAINT fk_department
        FOREIGN KEY (department_id) REFERENCES DepartmentName(department_id),
    CONSTRAINT fk_user_account_status_id
        FOREIGN KEY (account_status_id) REFERENCES UserAccountStatus(status_id),
    CONSTRAINT chk_user_id_format
        CHECK (user_id NOT LIKE '%[^0-9]%' AND LEN(user_id) = 8),
    CONSTRAINT chk_user_email_format
        CHECK (email LIKE '_%@_%._%'),
    CONSTRAINT chk_user_phone_number_not_empty
        CHECK (LEN(phone_number) BETWEEN 10 AND 11 AND phone_number LIKE ('0%'))
);

CREATE TABLE Space (
    space_id VARCHAR(10) PRIMARY KEY,
    space_name NVARCHAR(30) NOT NULL,

    space_type_id TINYINT NOT NULL,

    building CHAR NOT NULL,
    floor TINYINT NOT NULL,
    room_number TINYINT NOT NULL,
    space_location AS CONCAT(building, CAST(floor AS NVARCHAR(3)), CAST(room_number AS NVARCHAR(3))),

    capacity SMALLINT NOT NULL,

    space_status_id TINYINT NOT NULL,
    usage_policy NVARCHAR(500) NOT NULL,

    CONSTRAINT fk_space_type
        FOREIGN KEY (space_type_id) REFERENCES SpaceType(type_id),
    CONSTRAINT fk_space_status
        FOREIGN KEY (space_status_id) REFERENCES SpaceStatus(status_id),
    CONSTRAINT chk_space_id_format
        CHECK (LEN(space_id) BETWEEN 3 AND 7 AND space_id NOT LIKE '%[^A-Za-z0-9]%'),
    CONSTRAINT chk_space_building_not_empty
        CHECK (LEN(building) > 0),
    CONSTRAINT chk_space_floor_not_empty
        CHECK (LEN(floor) > 0),
    CONSTRAINT chk_space_room_not_empty
        CHECK (LEN(room) > 0),
    CONSTRAINT chk_space_capacity_positive
        CHECK (capacity > 0)
);

CREATE TABLE Facility (
    facility_type_id TINYINT NOT NULL,
    facility_sequence_number INT NOT NULL,
    facility_id AS
        CONCAT(CAST(facility_type_id AS VARCHAR(3)), CAST(facility_sequence_number AS VARCHAR(17))) PRIMARY KEY,
    facility_name NVARCHAR(50) NOT NULL,
    space_id VARCHAR(5) NULL,

    CONSTRAINT uq_facility_type_sequence
        UNIQUE (facility_type_id, facility_sequence_number),
    CONSTRAINT fk_facility_space
        FOREIGN KEY (space_id) REFERENCES Space(space_id),
    CONSTRAINT chk_facility_type_code_format
        CHECK (facility_type_id > 0),
    CONSTRAINT chk_facility_sequence_number_positive
        CHECK (facility_sequence_number > 0)
);


CREATE TABLE BookingRequest (
   booking_request_id NVARCHAR(8) PRIMARY KEY,
   booker_id nvarchar(8) FOREIGN KEY REFERENCES [User](user_id),
   space_id nvarchar(20) FOREIGN KEY REFERENCES Space(space_id),

   requested_start_time DATETIME NOT NULL,
   requested_end_time DATETIME NOT NULL,
   requested_time_slot as DATEDIFF(MINUTE, requested_start_time, requested_end_time),

   purpose_id TINYINT NOT NULL,

   expected_participants INT NOT NULL,

    CONSTRAINT fk_booking_request_user
        FOREIGN KEY (booker_id) REFERENCES [User](user_id),
    CONSTRAINT fk_booking_request_space
        FOREIGN KEY (space_id) REFERENCES Space(space_id),
    CONSTRAINT fk_purpose
        FOREIGN KEY (purpose_id) REFERENCES Purpose(purpose_id),
    CONSTRAINT chk_booking_request_id_format
        CHECK (
            LEN(booking_request_id) = 8
            AND booking_request_id COLLATE Latin1_General_BIN NOT LIKE '%[^a-z0-9]%'
        ),
    CONSTRAINT chk_booking_request_time_order
        CHECK (requested_end_time > requested_start_time),
    CONSTRAINT chk_booking_request_expected_participants_positive
        CHECK (expected_participants > 0)  
)

CREATE TABLE Reservation (
    reservation_id VARCHAR(6) PRIMARY KEY,
    booking_request_id VARCHAR(8) FOREIGN KEY REFERENCES BookingRequest(booking_request_id),

    resevation_status_id TINYINT NOT NULL,
    FOREIGN KEY (reservation_status_id) REFERENCES ReservationStatus(status_id),

    usage_note NVARCHAR (100) NOT NULL,

    CONSTRAINT fk_reservation_booking_request
        FOREIGN KEY (booking_request_id) REFERENCES BookingRequest(booking_request_id),
    CONSTRAINT fk_reservation_status
        FOREIGN KEY (reservation_status_id) REFERENCES ReservationStatus(status_id),
    CONSTRAINT chk_reservation_id_format
        CHECK (
            LEN(reservation_id) = 8
            AND reservation_id COLLATE Latin1_General_BIN NOT LIKE '%[^A-Z0-9]%'
        )
);

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
    maintenance_id VARCHAR(6) PRIMARY KEY,

    reporter_id VARCHAR(8) NOT NULL,
    maintenance_problem_description NVARCHAR(50) NOT NULL,

    maintenance_status TINYINT NOT NULL,

    result_note NVARCHAR(500) NULL,

    CONSTRAINT fk_maintenance_reporter
        FOREIGN KEY (reporter_id) REFERENCES [User](user_id),
    CONSTRAINT fk_maintenance_status
        FOREIGN KEY (maintenance_status) REFERENCES MaintenanceStatus(status_id),
    CONSTRAINT chk_maintenance_id_format
        CHECK (
            LEN(maintenance_id) = 6
            AND maintenance_id COLLATE Latin1_General_BIN NOT LIKE '%[^a-z0-9]%'
        ),
    CONSTRAINT chk_result_note_requires_complete_status
        CHECK (result_note IS NULL OR  maintenance_status = 'completed')
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

-- Additional lookup tables
CREATE TABLE UserRole (
    role_id TINYINT PRIMARY KEY IDENTITY(1,1),
    role_name NVARCHAR(30) NOT NULL UNIQUE,
    CONSTRAINT chk_user_role_lowercase
        CHECK (role_name COLLATE Latin1_General_BIN = LOWER(role_name) COLLATE Latin1_General_BIN)
);

CREATE TABLE UserAccountStatus (
    status_id TINYINT PRIMARY KEY IDENTITY(1,1),
    status_name NVARCHAR(30) NOT NULL UNIQUE,
    CONSTRAINT chk_user_account_status_lowercase
        CHECK (status_name COLLATE Latin1_General_BIN = LOWER(status_name) COLLATE Latin1_General_BIN)
);

CREATE TABLE DepartmentName (
    department_id TINYINT PRIMARY KEY IDENTITY(1,1),
    department_name NVARCHAR(50) NOT NULL UNIQUE, 
    CONSTRAINT chk_deparment_name_lowercase
        CHECK (department_name COLLATE Latin1_General_BIN = LOWER(department_name) COLLATE Latin1_General_BIN)

)

CREATE TABLE SpaceStatus (
    status_id TINYINT PRIMARY KEY IDENTITY(1,1),
    status_name NVARCHAR(20) NOT NULL UNIQUE,
    CONSTRAINT chk_space_status_lowercase
        CHECK (status_name COLLATE Latin1_General_BIN = LOWER(status_name) COLLATE Latin1_General_BIN)
);

CREATE TABLE SpaceType (
    type_id TINYINT PRIMARY KEY IDENTITY(1,1),
    type_name NVARCHAR(20) NOT NULL UNIQUE,
    CONSTRAINT chk_space_type_lowercase
        CHECK (type_name COLLATE Latin1_General_BIN = LOWER(type_name) COLLATE Latin1_General_BIN)
);

CREATE TABLE ReservationStatus (
    status_id TINYINT PRIMARY KEY IDENTITY(1,1),
    status_name NVARCHAR(20) NOT NULL UNIQUE,
    CONSTRAINT chk_reservation_status_lowercase
        CHECK (status_name COLLATE Latin1_General_BIN = LOWER(status_name) COLLATE Latin1_General_BIN)
);

CREATE TABLE Purpose (
    purpose_id TINYINT PRIMARY KEY IDENTITY(1,1),
    purpose_code NVARCHAR(25) NOT NULL UNIQUE,
    purpose_name NVARCHAR(50) NOT NULL UNIQUE,
    CONSTRAINT chk_purpose_name_lowercase
        CHECK (purpose_name COLLATE Latin1_General_BIN = LOWER(purpose_name) COLLATE Latin1_General_BIN)
    CONSTRAINT chk_purpose_code_uppercase
        CHECK (purpose_code COLLATE Latin1_General_BIN = UPPER(purpose_code) COLLATE Latin1_General_BIN)
)

CREATE TABLE DecisionStatus (
    status_id TINYINT PRIMARY KEY IDENTITY(1,1),
    status_name NVARCHAR(20) NOT NULL UNIQUE,
    CONSTRAINT chk_decision_status_lowercase
        CHECK (status_name COLLATE Latin1_General_BIN = LOWER(status_name) COLLATE Latin1_General_BIN)
);

CREATE TABLE MaintenanceStatus (
    status_id TINYINT PRIMARY KEY IDENTITY(1,1),
    status_name NVARCHAR(20) NOT NULL UNIQUE,
    CONSTRAINT chk_maintenance_status_lowercase
        CHECK (status_name COLLATE Latin1_General_BIN = LOWER(status_name) COLLATE Latin1_General_BIN)
);

INSERT INTO UserRole (role_name) VALUES 
("student"), 
("lecturer"), 
("teaching assistant"), 
("facility staff"), 
("department administrator"), 
("facility manager");

INSERT INTO UserAccountStatus(status_name) VALUES 
("pending approval"),
("active"),
("suspended"),
("disabled");

INSERT INTO DepartmentName(department_name) VALUES
('Faculty of Mathematics and Computer Science'),
('Faculty of Information Technology'),
('Faculty of Physics and Engineering Physics'),
('Faculty of Electronics and Telecommunications'),
('Faculty of Chemistry'),
('Faculty of Biology and Biotechnology'),
('Faculty of Geology'),
('Faculty of Environment'),
('Faculty of Materials Science and Technology'),
('Faculty of Interdisciplinary Sciences');

INSERT INTO SpaceStatus (status_name) VALUES 
("available"), 
("in use"), 
("under maintenance"), 
("closed"), 
("retired");

INSERT INTO SpaceType (type_name) VALUES
("classroom"),
("meeting room"),
("laboratory"),
("lecture hall"),
("other");

INSERT INTO ReservationStatus (status_name) VALUES 
("pending"),
("approved"), 
("rejected"), 
("cancelled"), 
("other");

INSERT INTO Purpose (purpose_code, purpose_name)
VALUES
    ('LECTURE', 'Lecture'),
    ('EXAM', 'Examination'),
    ('SEMINAR', 'Seminar'),
    ('WORKSHOP', 'Workshop'),
    ('MEETING', 'Meeting'),
    ('STUDENT_ACTIVITY', 'Student activity'),
    ('ADMIN_EVENT', 'Administrative event');
    
INSERT INTO DecisionStatus (status_name) VALUES
("accepted"),
("rejected"),
("cancelled");

INSERT INTO MaintenanceStatus (status_name) VALUES 
("pending"), 
("in progress"), 
("completed"), 
("cancelled"), 
("other");

GO

SET NOEXEC OFF;
GO
