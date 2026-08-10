SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'staging_phase2') IS NULL
    EXEC(N'CREATE SCHEMA staging_phase2');
GO

DROP TABLE IF EXISTS staging_phase2.AdvisoryAcknowledgements;
DROP TABLE IF EXISTS staging_phase2.Reservations;
DROP TABLE IF EXISTS staging_phase2.Reviews;
DROP TABLE IF EXISTS staging_phase2.Bookings;
DROP TABLE IF EXISTS staging_phase2.BookingRequests;
DROP TABLE IF EXISTS staging_phase2.Maintenance;
DROP TABLE IF EXISTS staging_phase2.Spaces;
DROP TABLE IF EXISTS staging_phase2.Users;
GO

CREATE TABLE staging_phase2.Users (
    user_id NVARCHAR(100), surname NVARCHAR(100), given_name NVARCHAR(100),
    email NVARCHAR(255), phone_number NVARCHAR(100), user_role_code NVARCHAR(100),
    department_code NVARCHAR(100), user_status_code NVARCHAR(100)
);
CREATE TABLE staging_phase2.Spaces (
    space_id NVARCHAR(100), space_name NVARCHAR(255), space_type_code NVARCHAR(100),
    building NVARCHAR(100), floor NVARCHAR(100), room_number NVARCHAR(100),
    capacity NVARCHAR(100), space_status_code NVARCHAR(100), space_policy_code NVARCHAR(100)
);
CREATE TABLE staging_phase2.Maintenance (
    maintenance_id NVARCHAR(100), reporter_id NVARCHAR(100), space_id NVARCHAR(100),
    maintenance_description NVARCHAR(500), maintenance_status_code NVARCHAR(100),
    impact_level_code NVARCHAR(100), maintenance_start_time NVARCHAR(100),
    maintenance_end_time NVARCHAR(100)
);
CREATE TABLE staging_phase2.BookingRequests (
    booking_request_id NVARCHAR(100), request_creation_time NVARCHAR(100),
    requested_start_time NVARCHAR(100), requested_end_time NVARCHAR(100),
    purpose_code NVARCHAR(100), expected_participants NVARCHAR(100),
    request_state_code NVARCHAR(100), advisory_acknowledged NVARCHAR(100),
    instant_approval NVARCHAR(100)
);
CREATE TABLE staging_phase2.Bookings (
    booking_request_id NVARCHAR(100), user_id NVARCHAR(100), space_id NVARCHAR(100)
);
CREATE TABLE staging_phase2.Reviews (
    review_id NVARCHAR(100), booking_request_id NVARCHAR(100), reviewer_id NVARCHAR(100),
    request_decision_code NVARCHAR(100), decision_time NVARCHAR(100),
    decision_note NVARCHAR(500), rejection_reason NVARCHAR(500)
);
CREATE TABLE staging_phase2.Reservations (
    reservation_id NVARCHAR(100), booking_request_id NVARCHAR(100),
    reservation_status_code NVARCHAR(100), usage_note NVARCHAR(500)
);
CREATE TABLE staging_phase2.AdvisoryAcknowledgements (
    booking_request_id NVARCHAR(100), maintenance_id NVARCHAR(100), acknowledged_at NVARCHAR(100)
);
GO
