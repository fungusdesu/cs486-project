SET NOEXEC ON;
GO

CREATE DATABASE School;
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

    department nvarchar(20) NOT NULL,

    account_status TINYINT NOT NULL,
    FOREIGN KEY (account_status) REFERENCES UserAccountStatus(status_id)
);

CREATE TABLE Space (
    space_id nvarchar(20) PRIMARY KEY,
    space_name nvarchar(50) NOT NULL,

    space_type_id TINYINT NOT NULL,
    FOREIGN KEY (space_type_id) REFERENCES SpaceType(type_id),

    building nvarchar(1) NOT NULL,
    floor TINYINT NOT NULL,
    room_number TINYINT NOT NULL,
    space_location as CONCAT(building, CAST(floor as NVARCHAR(3)), CAST(room_number as NVARCHAR(3))),

    capacity INT NOT NULL,

    current_status_id TINYINT NOT NULL,
    FOREIGN KEY (current_status_id) REFERENCES RoomStatus(status_id),

    usage_policy nvarchar(500) NOT NULL,
);

CREATE TABLE Facility (
    facility_id nvarchar(20) PRIMARY KEY,
    facility_name nvarchar(50) NOT NULL,
    FOREIGN KEY (space_id) REFERENCES Space(space_id)
);


CREATE TABLE BookingRequest (
   booking_request_id nvarchar(8) NOT NULL,

   requested_start_time DATETIME NOT NULL,
   requested_end_time DATETIME NOT NULL,
   requested_time_slot as DATEDIFF(mi, requested_start_time, requested_end_time),

   purpose nvarchar(500) NOT NULL,

   expected_participants INT NOT NULL
)

CREATE TABLE Reservation (
    reservation_id nvarchar(8) PRIMARY KEY,
    booking_request_id nvarchar(8) FOREIGN KEY REFERENCES BookingRequest(booking_request_id),

    resevation_status_id TINYINT NOT NULL,
    FOREIGN KEY (reservation_status_id) REFERENCES ReservationStatus(status_id),

    usage_note nvarchar (100) NOT NULL
);

CREATE TABLE BookingDecision (
    booking_request_id nvarchar(8) PRIMARY KEY,
    decision_maker_id nvarchar(8) FOREIGN KEY REFERENCES [User](user_id),

    decision_status_id TINYINT NOT NULL,
    FOREIGN KEY (request_status_id) REFERENCES DecisionStatus(status_id),

    decision_time time NOT NULL,
    decision_note nvarchar(500) NOT NULL,
    rejection_reason nvarchar(500)
)

CREATE TABLE ReservationCheckIn (
    reservation_id nvarchar(8) FOREIGN KEY REFERENCES Reservation(reservation_id),

    attendant_id nvarchar(8) FOREIGN KEY REFERENCES [User](user_id),
    checked_in_user_id nvarchar(8) FOREIGN KEY REFERENCES [User](user_id),

    check_in_status nvarchar(20) NOT NULL,
    CONSTRAINT chk_cin_status CHECK (
        check_in_status in ("checked in", "not checked in")
    ),

    actual_start_time DATETIME NOT NULL,
    actual_end_time DATETIME NOT NULL,
    actual_time_slot as DATEDIFF(mi, actual_start_time, actual_end_time),

    space_initial_condition_id nvarchar(20),
    FOREIGN KEY (space_initial_condition_id) REFERENCES SpaceStatus(space_id),
    space_final_condition_id nvarchar(20),
    FOREIGN KEY (space_final_condition_id) REFERENCES SpaceStatus(space_id),

    usage_note nvarchar(500)
)

CREATE TABLE Maintainance (
    maintenance_id nvarchar(20) PRIMARY KEY,

    reporter_id nvarchar(8) FOREIGN KEY REFERENCES [User](user_id),

    problem_description nvarchar(500) NOT NULL,

    maintenance_status TINYINT NOT NULL,
    FOREIGN KEY (maintenance_status) REFERENCES MaintenanceStatus(status_id),

    result_note nvarchar(500) NOT NULL
)

-- Additional lookup tables
CREATE TABLE UserRole (
    role_id INT PRIMARY KEY IDENTITY(1,1),
    role_name nvarchar(30) NOT NULL UNIQUE
)

CREATE TABLE UserAccountStatus(
    status_id INT PRIMARY KEY IDENTITY(1,1),
    status_name nvarchar(30) NOT NULL UNIQUE
)

CREATE TABLE SpaceStatus (
    status_id INT PRIMARY KEY IDENTITY(1,1),
    status_name nvarchar(20) NOT NULL UNIQUE
)

CREATE TABLE SpaceType (
    type_id INT PRIMARY KEY IDENTITY(1,1),
    type_name nvarchar(20) NOT NULL UNIQUE
)

CREATE TABLE ReservationStatus (
    status_id INT PRIMARY KEY IDENTITY(1,1),
    status_name nvarchar(20) NOT NULL UNIQUE
)

CREATE TABLE DecisionStatus (
    status_id INT PRIMARY KEY IDENTITY(1,1),
    status_name nvarchar(20) NOT NULL UNIQUE
)

CREATE TABLE MaintenanceStatus (
    status_id INT PRIMARY KEY IDENTITY(1,1),
    status_name nvarchar(20) NOT NULL UNIQUE
)

INSERT INTO UserRole (role_name) VALUES 
("Student"), 
("Lecturer"), 
("Teaching Assistant"), 
("Facility Staff"), 
("Department Administrator"), 
("Facility Manager");

INSERT INTO UserAccountStatus(status_name) VALUES 
("Pending Approval"),
("Active"),
("Suspended"),
("Disabled");

INSERT INTO SpaceStatus (status_name) VALUES 
("Available"), 
("In Use"), 
("Under Maintenance"), 
("Closed"), 
("Retired");

INSERT INTO SpaceType (type_name) VALUES
("Classroom"),
("Meeting Room"),
("Laboratory"),
("Lecture Hall"),
("Other");

INSERT INTO ReservationStatus (status_name) VALUES 
("Pending"),
("Approved"), 
("Rejected"), 
("Cancelled"), 
("Other");

INSERT INTO DecisionStatus (status_name) VALUES
("Accepted"),
("Rejected"),
("Cancelled");

INSERT INTO MaintenanceStatus (status_name) VALUES 
("Pending"), 
("In Progress"), 
("Completed"), 
("Cancelled"), 
("Other");

SET NOEXEC OFF;
GO