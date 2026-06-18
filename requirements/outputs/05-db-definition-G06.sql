SET NOEXEC ON;
GO

CREATE DATABASE School;
GO


CREATE TABLE [User] (
    user_id varchar(8) PRIMARY KEY,
    first_name varchar(50) NOT NULL,
    last_name varchar (7) NOT NULL,
    full_name as CONCAT(first_name, ' ', last_name),
    email varchar(100) NOT NULL,
    phone_number varchar(100) NOT NULL,

    role_ nvarchar(30) NOT NULL,
    CONSTRAINT chk_user_role CHECK (role_ in ("Student", "Lecturer", "Teaching Assistant", "Facility Staff", "Department Administrator", "Facility Manager")),

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
    )

    building nvarchar(20) NOT NULL,
    floor nvarchar(20) NOT NULL,
    room_number nvarchar(20) NOT NULL,
    space_location as CONCAT(building, '', floor, '', room_number),

    capacity int NOT NULL,

    current_status nvarchar(20) NOT NULL,
    CONSTRAINT chk_current_status CHECK (
        current_status in ("Available", "In Use", "Under Maintenance", "Closed", "Retired")
    )

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

    FORREIGN KEY (space_id) REFERENCES Space(space_id),
    FORREIGN KEY (facility_id) REFERENCES Facility(facility_id)
)

CREATE TABLE Booking (
    booking_id nvarchar(50) PRIMARY KEY,
    space_id nvarchar(20) FOREIGN KEY REFERENCES Space(space_id),
    booker_id nvarchar(20) FOREIGN KEY REFERENCES [User](user_id),

    booking_date date NOT NULL,
    booking_start_time time NOT NULL,
    booking_end_time time NOT NULL,
    booking_duration as DATEDIFF(minute, booking_start_time, booking_end_time),

    booking_status nvarchar(20) NOT NULL,
    CONSTRAINT chk_booking_status CHECK (
        booking_status in ("Pending", "Approved", "Cancelled", "Completed", "No-show", "Other")
    )
)
SET NOEXEC OFF;
GO