SET NOEXEC ON;
GO

CREATE DATABASE School;
GO
USE School;
GO

CREATE TABLE [User] (
    user_id VARCHAR(8) PRIMARY KEY,
    given_name NVARCHAR(70) NOT NULL,
    surname NVARCHAR(70) NOT NULL,
    full_name AS CONCAT(surname, ' ', given_name),
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(10) NOT NULL UNIQUE,

    role_id TINYINT NOT NULL,
    department NVARCHAR(20) NOT NULL,
    account_status TINYINT NOT NULL,

    CONSTRAINT fk_user_role
        FOREIGN KEY (role_id) REFERENCES UserRole(role_id),
    CONSTRAINT fk_user_account_status
        FOREIGN KEY (account_status) REFERENCES UserAccountStatus(status_id),
    CONSTRAINT chk_user_id_format
        CHECK (user_id NOT LIKE '%[^0-9]%' AND LEN(user_id) = 8),
    CONSTRAINT chk_user_email_format
        CHECK (email LIKE '_%@_%._%'),
    CONSTRAINT chk_user_phone_number_not_empty
        CHECK (LEN(phone_number) BETWEEN 10 AND 11 AND phone_number LIKE ('0%'))
);

CREATE TABLE Space (
    space_id VARCHAR(5) PRIMARY KEY,
    space_name NVARCHAR(50) NOT NULL,

    space_type_id TINYINT NOT NULL,

    building NVARCHAR(1) NOT NULL,
    floor TINYINT NOT NULL,
    room_number TINYINT NOT NULL,
    space_location AS CONCAT(building, CAST(floor AS NVARCHAR(3)), CAST(room_number AS NVARCHAR(3))),

    capacity INT NOT NULL,

    current_status_id TINYINT NOT NULL,
    usage_policy NVARCHAR(500) NOT NULL,

    CONSTRAINT fk_space_type
        FOREIGN KEY (space_type_id) REFERENCES SpaceType(type_id),
    CONSTRAINT fk_space_status
        FOREIGN KEY (current_status_id) REFERENCES SpaceStatus(status_id),
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
    facility_type_code VARCHAR(3) NOT NULL,
    facility_sequence_number INT NOT NULL,
    facility_id AS
        CONCAT(facility_type_code, CAST(facility_sequence_number AS VARCHAR(17))) PRIMARY KEY,
    facility_name NVARCHAR(50) NOT NULL,
    space_id VARCHAR(5) NULL,

    CONSTRAINT uq_facility_type_sequence
        UNIQUE (facility_type_code, facility_sequence_number),
    CONSTRAINT fk_facility_space
        FOREIGN KEY (space_id) REFERENCES Space(space_id),
    CONSTRAINT chk_facility_type_code_format
        CHECK (LEN(facility_type_code) = 3 AND facility_type_code NOT LIKE '%[^A-Za-z]%'),
    CONSTRAINT chk_facility_sequence_number_positive
        CHECK (facility_sequence_number > 0)
);


CREATE TABLE BookingRequest (
   booking_request_id NVARCHAR(8) PRIMARY KEY,
   booker_id nvarchar(8) FOREIGN KEY REFERENCES [User](user_id),
   space_id nvarchar(20) FOREIGN KEY REFERENCES Space(space_id),

   requested_start_time DATETIME NOT NULL,
   requested_end_time DATETIME NOT NULL,
   requested_time_slot as DATEDIFF(mi, requested_start_time, requested_end_time),

   purpose NVARCHAR(500) NOT NULL,

   expected_participants INT NOT NULL
)

CREATE TABLE Reservation (
    reservation_id NVARCHAR(8) PRIMARY KEY,
    booking_request_id NVARCHAR(8) FOREIGN KEY REFERENCES BookingRequest(booking_request_id),

    resevation_status_id TINYINT NOT NULL,
    FOREIGN KEY (reservation_status_id) REFERENCES ReservationStatus(status_id),

    usage_note NVARCHAR (100) NOT NULL
);

CREATE TABLE BookingDecision (
    booking_request_id NVARCHAR(8) PRIMARY KEY,
    decision_maker_id NVARCHAR(8) FOREIGN KEY REFERENCES [User](user_id),

    decision_status_id TINYINT NOT NULL,
    FOREIGN KEY (request_status_id) REFERENCES DecisionStatus(status_id),

    decision_time time NOT NULL,
    decision_note NVARCHAR(500) NOT NULL,
    rejection_reason NVARCHAR(500)
)

CREATE TABLE ReservationCheckIn (
    reservation_id NVARCHAR(8) FOREIGN KEY REFERENCES Reservation(reservation_id),

    attendant_id NVARCHAR(8) FOREIGN KEY REFERENCES [User](user_id),
    checked_in_user_id NVARCHAR(8) FOREIGN KEY REFERENCES [User](user_id),

    PRIMARY KEY (reservation_id, checked_in_user_id),

    check_in_status NVARCHAR(20) NOT NULL,
    CONSTRAINT chk_cin_status CHECK (
        check_in_status in ("checked in", "not checked in")
    ),

    actual_start_time DATETIME NOT NULL,
    actual_end_time DATETIME NOT NULL,
    actual_time_slot as DATEDIFF(mi, actual_start_time, actual_end_time),

    space_initial_condition_id NVARCHAR(20),
    FOREIGN KEY (space_initial_condition_id) REFERENCES SpaceStatus(space_id),
    space_final_condition_id NVARCHAR(20),
    FOREIGN KEY (space_final_condition_id) REFERENCES SpaceStatus(space_id),

    usage_note NVARCHAR(500)
)

CREATE TABLE Maintainance (
    maintenance_id NVARCHAR(20) PRIMARY KEY,

    reporter_id NVARCHAR(8) FOREIGN KEY REFERENCES [User](user_id),

    problem_description NVARCHAR(500) NOT NULL,

    maintenance_status TINYINT NOT NULL,
    FOREIGN KEY (maintenance_status) REFERENCES MaintenanceStatus(status_id),

    result_note NVARCHAR(500) NOT NULL
)

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

SET NOEXEC OFF;
GO