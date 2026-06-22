SET NOEXEC ON;
GO

CREATE DATABASE School;
GO


CREATE TABLE [User] (
    user_id varchar(8) PRIMARY KEY,
    first_name varchar(50) NOT NULL,
    last_name varchar (7) NOT NULL,
    full_name as CONCAT(first_name, ' ', last_name),
    email varchar(100) NOT NULL UNIQUE,
    phone_number varchar(100) NOT NULL UNIQUE,

    role_id TINYINT NOT NULL,
    FOREIGN KEY (role_id) REFERENCES UserRole(role_id),

    department nvarchar(20) NOT NULL,

    account_status nvarchar(20) NOT NULL,
    CONSTRAINT chk_account_status CHECK (
        account_status in ("Active", "Disabled", "Pending Approval", "Deleted")
    ) 
);

CREATE TABLE Space (
    space_id nvarchar(20) PRIMARY KEY,
    space_name nvarchar(50) NOT NULL,

    space_type nvarchar(20) NOT NULL,
    CONSTRAINT chk_space_type CHECK (
        space_type in ("Classroom", "Meeting Room", "Laboratory", "Lecture Hall", "Other")
    ),

    building nvarchar(1) NOT NULL,
    floor TINYINT NOT NULL,
    room_number TINYINT NOT NULL,
    space_location as CONCAT(building, CAST(floor as NVARCHAR(3)), CAST(room_number as NVARCHAR(3))),

    capacity INT NOT NULL,

    current_status TINYINT NOT NULL,
    FOREIGN KEY (current_status) REFERENCES RoomStatus(status_id),

    usage_policy nvarchar(500) NOT NULL,


);

CREATE TABLE Facility (
    facility_id nvarchar(20) PRIMARY KEY,
    facility_name nvarchar(50) NOT NULL,
);

CREATE TABLE Space_Facility (
    space_id nvarchar(20) NOT NULL,
    facility_id nvarchar(20) NOT NULL,
    space_name nvarchar(50) NOT NULL,
    facility_name nvarchar(50) NOT NULL,
    PRIMARY KEY (space_id, facility_id),

    FOREIGN KEY (space_id) REFERENCES Space(space_id),
    FOREIGN KEY (facility_id) REFERENCES Facility(facility_id)
)

CREATE TABLE BookingRequest (
    booking_id nvarchar(50) PRIMARY KEY,
    space_id nvarchar(20) FOREIGN KEY REFERENCES Space(space_id),
    booker_id nvarchar(20) FOREIGN KEY REFERENCES [User](user_id),

    space_initial_condition nvarchar(20) FOREIGN KEY REFERENCES Space(current_status),
    space_final_condition nvarchar(20) FOREIGN KEY REFERENCES Space(current_status),

    booking_date date NOT NULL,
    booking_start_time time NOT NULL,
    booking_end_time time NOT NULL,
    booking_actual_start_time time,
    booking_actual_end_time time,
    booking_duration as DATEDIFF(minute, booking_start_time, booking_end_time),
    CONSTRAINT chk_booking_time CHECK (
        booking_start_time < booking_end_time
    ),
)

CREATE TABLE BookingApproval (
    booking_request_id nvarchar(50) PRIMARY KEY,
    booking_id nvarchar(50) FOREIGN KEY REFERENCES Booking(booking_id),
    staff_id nvarchar(20) FOREIGN KEY REFERENCES [User](user_id),

    request_status TINYINT NOT NULL,
    FOREIGN KEY (request_status) REFERENCES RequestStatus(status_id),

    decision_time time NOT NULL,
    decision_note nvarchar(500) NOT NULL,
    rejection_reason nvarchar(500)
)

CREATE TABLE Maintains (
    maintenance_id nvarchar(20) PRIMARY KEY,
    space_id nvarchar(20) FOREIGN KEY REFERENCES Space(space_id),
    reporter_id nvarchar(20) FOREIGN KEY REFERENCES [User](user_id),
    assigned_staff_id nvarchar(20) FOREIGN KEY REFERENCES [User](user_id),

    problem_description nvarchar(500) NOT NULL,
    maintenance_date date NOT NULL,
    maintenance_start_time time NOT NULL,
    maintenance_completion_time time NOT NULL,

    maintenance_status TINYINT NOT NULL,
    FOREIGN KEY (maintenance_status) REFERENCES MaintenanceStatus(status_id),

    result_note nvarchar(500) NOT NULL
)

-- Additional lookup tables
CREATE TABLE UserRole (
    role_id INT PRIMARY KEY IDENTITY(1,1),
    role_name nvarchar(30) NOT NULL UNIQUE
)

CREATE TABLE RoomStatus (
    status_id INT PRIMARY KEY IDENTITY(1,1),
    status_name nvarchar(20) NOT NULL UNIQUE
)

CREATE TABLE RequestStatus (
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

INSERT INTO RoomStatus (status_name) VALUES 
("Available"), 
("In Use"), 
("Under Maintenance"), 
("Closed"), 
("Retired");

INSERT INTO RequestStatus (status_name) VALUES 
("Pending"),
("Approved"), 
("Rejected"), 
("Cancelled"), 
("Other");

INSERT INTO MaintenanceStatus (status_name) VALUES 
("Pending"), 
("In Progress"), 
("Completed"), 
("Cancelled"), 
("Other");

SET NOEXEC OFF;
GO