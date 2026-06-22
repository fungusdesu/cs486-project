SET NOEXEC ON;
GO

CREATE DATABASE School;
GO
USE School;
GO

CREATE TABLE [User] (
    user_id varchar(8) PRIMARY KEY,
    given_name varchar(70) NOT NULL,
    surname varchar (7) NOT NULL,
    full_name as CONCAT(surname, ' ', given_name),
    email varchar(100) NOT NULL UNIQUE,
    phone_number varchar(100) NOT NULL UNIQUE,

    role_id TINYINT NOT NULL,
    FOREIGN KEY (role_id) REFERENCES UserRole(role_id),

    department NVARCHAR(20) NOT NULL,

    account_status TINYINT NOT NULL,
    FOREIGN KEY (account_status) REFERENCES UserAccountStatus(status_id)
);

CREATE TABLE Space (
    space_id NVARCHAR(20) PRIMARY KEY,
    space_name NVARCHAR(50) NOT NULL,

    space_type_id TINYINT NOT NULL,
    FOREIGN KEY (space_type_id) REFERENCES SpaceType(type_id),

    building NVARCHAR(1) NOT NULL,
    floor TINYINT NOT NULL,
    room_number TINYINT NOT NULL,
    space_location as CONCAT(building, CAST(floor as NVARCHAR(3)), CAST(room_number as NVARCHAR(3))),

    capacity INT NOT NULL,

    current_status_id TINYINT NOT NULL,
    FOREIGN KEY (current_status_id) REFERENCES RoomStatus(status_id),

    usage_policy NVARCHAR(500) NOT NULL,
);

CREATE TABLE Facility (
    facility_id NVARCHAR(20) PRIMARY KEY,
    facility_name NVARCHAR(50) NOT NULL,
    FOREIGN KEY (space_id) REFERENCES Space(space_id)
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