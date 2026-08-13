/*
  G06 Phase 2 staging-to-production load.
  Prerequisite: outputs 05, 06, and 10 have completed in database School,
  followed by create-staging.sql and the seven bcp imports.

  The load is transactional and rerunnable for exactly the identifiers present
  in staging. The
  approved output-10 schema stores the booking-level BookingRequest.advisory_acknowledged flag.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.MaintenanceSession', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Review', N'U') IS NULL
   OR OBJECT_ID(N'lookup_table.RequestState', N'U') IS NULL
   OR OBJECT_ID(N'staging_phase2.BookingRequests', N'U') IS NULL
    THROW 51400, 'Final Phase 2 schema or staging tables are missing.', 1;

IF OBJECT_ID(N'dbo.trg_decision_maker_acc_role', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_no_overlapping_approved_requests', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_no_approved_review_during_maintaining', N'TR') IS NULL
    THROW 51401, 'Required Review triggers are missing; run outputs 05 and 10 first.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.triggers
    WHERE parent_id = OBJECT_ID(N'dbo.Review')
      AND is_disabled = 1
)
    THROW 51402, 'A Review trigger is disabled. The Phase 2 load requires every trigger to remain enabled.', 1;

BEGIN TRANSACTION;
BEGIN TRY
    /* Required synthetic lookup domains. Existing codes are preserved. */
    INSERT INTO lookup_table.Department (department_code, department_name)
    SELECT v.code, v.name
    FROM (VALUES
        ('D01', N'Synthetic Department 01'), ('D02', N'Synthetic Department 02'),
        ('D03', N'Synthetic Department 03'), ('D04', N'Synthetic Department 04'),
        ('D05', N'Synthetic Department 05'), ('D06', N'Synthetic Department 06'),
        ('D07', N'Synthetic Department 07'), ('D08', N'Synthetic Department 08')
    ) AS v(code, name)
    WHERE NOT EXISTS (SELECT 1 FROM lookup_table.Department d WHERE d.department_code = v.code);

    INSERT INTO lookup_table.Purpose (purpose_code, purpose_name)
    SELECT v.code, v.name
    FROM (VALUES
        ('TEACHING', N'Teaching'), ('MEETING', N'Meeting'), ('STUDY', N'Study'),
        ('EVENT', N'Event'), ('RESEARCH', N'Research')
    ) AS v(code, name)
    WHERE NOT EXISTS (SELECT 1 FROM lookup_table.Purpose p WHERE p.purpose_code = v.code);

    INSERT INTO lookup_table.MaintenanceStatus (maintenance_status_code, maintenance_status_name)
    SELECT 'OPEN', N'Open'
    WHERE NOT EXISTS (SELECT 1 FROM lookup_table.MaintenanceStatus WHERE maintenance_status_code = 'OPEN');

    /* Remove only a previous load of the currently staged synthetic keys. */
    DELETE r FROM dbo.Reservation r
    INNER JOIN staging_phase2.BookingRequests s
        ON s.booking_request_id = r.booking_request_id;
    DELETE r FROM dbo.Review r
    INNER JOIN staging_phase2.BookingRequests s
        ON s.booking_request_id = r.booking_request_id;
    DELETE br FROM dbo.BookingRequest br
    INNER JOIN staging_phase2.BookingRequests s ON s.booking_request_id = br.booking_request_id;
    DELETE ms FROM dbo.MaintenanceSession ms
    INNER JOIN staging_phase2.Maintenance s ON s.maintenance_id = ms.maintenance_id;
    DELETE m FROM dbo.Maintenance m
    INNER JOIN staging_phase2.Maintenance s ON s.maintenance_id = m.maintenance_id;
    DELETE sp FROM dbo.Space sp
    INNER JOIN staging_phase2.Spaces s ON s.space_id = sp.space_id;
    DELETE u FROM dbo.[User] u
    INNER JOIN staging_phase2.Users s ON s.user_id = u.user_id;

    INSERT INTO dbo.SpacePolicy
        (space_policy_id, booking_window_days, min_duration_minutes,
         max_duration_minutes, check_in_grace_minutes, requires_approval,
         max_overrun_minutes)
    SELECT DISTINCT CONVERT(CHAR(5), s.space_policy_id), 60, 30, 240, 15,
           CASE WHEN s.space_policy_id IN ('DYWGI', 'NCYTN') THEN 0 ELSE 1 END,
           15
    FROM staging_phase2.Spaces s
    WHERE NOT EXISTS
        (SELECT 1 FROM dbo.SpacePolicy p
         WHERE p.space_policy_id = CONVERT(CHAR(5), s.space_policy_id));

    INSERT INTO dbo.[User]
        (user_id, surname, given_name, email, phone_number,
         user_role_id, department_id, user_status_id)
    SELECT CONVERT(CHAR(8), s.user_id), s.surname, s.given_name, s.email,
           s.phone_number, ur.user_role_id, d.department_id, us.user_status_id
    FROM staging_phase2.Users s
    INNER JOIN lookup_table.UserRole ur ON ur.user_role_code = s.user_role_code
    INNER JOIN lookup_table.UserStatus us ON us.user_status_code = s.user_status_code
    LEFT JOIN lookup_table.Department d ON d.department_code = NULLIF(s.department_code, '');

    INSERT INTO dbo.Space
        (space_id, space_name, space_type_id, building, floor, room_number,
         capacity, space_status_id, space_policy_id)
    SELECT s.space_id, s.space_name, st.space_type_id, s.building,
           CONVERT(TINYINT, s.floor), CONVERT(TINYINT, s.room_number),
           CONVERT(SMALLINT, s.capacity), ss.space_status_id,
           CONVERT(CHAR(5), s.space_policy_id)
    FROM staging_phase2.Spaces s
    INNER JOIN lookup_table.SpaceType st ON st.space_type_code = s.space_type_code
    INNER JOIN lookup_table.SpaceStatus ss ON ss.space_status_code = s.space_status_code;

    INSERT INTO dbo.Maintenance
        (maintenance_id, reporter_id, maintenance_description,
         maintenance_status_id, result_note, space_id)
    SELECT CONVERT(CHAR(6), s.maintenance_id), CONVERT(CHAR(8), s.reporter_id),
           s.maintenance_description, ms.maintenance_status_id, NULL, s.space_id
    FROM staging_phase2.Maintenance s
    INNER JOIN lookup_table.MaintenanceStatus ms
        ON ms.maintenance_status_code = s.maintenance_status_code;

    INSERT INTO dbo.MaintenanceSession
        (maintenance_id, technician_id, maintenance_start_time,
         maintenance_end_time, maintenance_impact_level_id)
    SELECT CONVERT(CHAR(6), s.maintenance_id), CONVERT(CHAR(8), s.reporter_id),
           CONVERT(DATETIME, s.maintenance_start_time, 126),
           CONVERT(DATETIME, s.maintenance_end_time, 126), mil.maintenance_impact_level_id
    FROM staging_phase2.Maintenance s
    INNER JOIN lookup_table.MaintenanceImpactLevel mil
        ON mil.maintenance_impact_level_code = s.impact_level_code;

    INSERT INTO dbo.BookingRequest
        (booking_request_id, request_creation_time, requested_start_time,
         requested_end_time, purpose_id, expected_participants,
         advisory_acknowledged, user_id, space_id, request_state_id)
    SELECT CONVERT(CHAR(8), r.booking_request_id),
           CONVERT(DATETIME, r.request_creation_time, 126),
           CONVERT(DATETIME, r.requested_start_time, 126),
           CONVERT(DATETIME, r.requested_end_time, 126), p.purpose_id,
           CONVERT(SMALLINT, r.expected_participants), CONVERT(BIT, r.advisory_acknowledged),
           CONVERT(CHAR(8), b.user_id), b.space_id, rs.request_state_id
    FROM staging_phase2.BookingRequests r
    INNER JOIN staging_phase2.Bookings b ON b.booking_request_id = r.booking_request_id
    INNER JOIN lookup_table.Purpose p ON p.purpose_code = r.purpose_code
    INNER JOIN lookup_table.RequestState rs ON rs.request_state_code = r.request_state_code;

    /* Non-approved rows cannot create an approved overlap. Load them once. */
    INSERT INTO dbo.Review
        (review_id, booking_request_id, reviewer_id, decision_time,
         decision_note, rejection_reason, request_decision_id)
    SELECT CONVERT(CHAR(9), s.review_id), CONVERT(CHAR(8), s.booking_request_id),
           CONVERT(CHAR(8), s.reviewer_id), CONVERT(DATETIME, s.decision_time, 126),
           NULLIF(s.decision_note, ''), NULLIF(s.rejection_reason, ''), rd.request_decision_id
    FROM staging_phase2.Reviews s
    INNER JOIN lookup_table.RequestDecision rd
        ON rd.request_decision_code = s.request_decision_code
    WHERE s.request_decision_code <> 'APPROVED';

    /*
      Load all approved reviews in one set. All Review triggers remain enabled;
      their bulk path validates the complete current schedule once instead of
      rebuilding it for every space batch.
    */
    INSERT INTO dbo.Review
        (review_id, booking_request_id, reviewer_id, decision_time,
         decision_note, rejection_reason, request_decision_id)
    SELECT CONVERT(CHAR(9), s.review_id), CONVERT(CHAR(8), s.booking_request_id),
           CONVERT(CHAR(8), s.reviewer_id), CONVERT(DATETIME, s.decision_time, 126),
           NULLIF(s.decision_note, ''), NULLIF(s.rejection_reason, ''),
           rd.request_decision_id
    FROM staging_phase2.Reviews s
    INNER JOIN lookup_table.RequestDecision rd
        ON rd.request_decision_code = s.request_decision_code
    WHERE s.request_decision_code = 'APPROVED';

    RAISERROR(N'Loaded all approved Review rows with every trigger enabled.',
              10, 1) WITH NOWAIT;

    INSERT INTO dbo.Reservation
        (reservation_id, booking_request_id, reservation_status_id, usage_note)
    SELECT CONVERT(CHAR(8), s.reservation_id), CONVERT(CHAR(8), s.booking_request_id),
           rs.reservation_status_id, NULLIF(s.usage_note, '')
    FROM staging_phase2.Reservations s
    INNER JOIN lookup_table.ReservationStatus rs
        ON rs.reservation_status_code =
           CASE s.reservation_status_code WHEN 'CANCELLED' THEN 'CAN'
                                          ELSE s.reservation_status_code END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT N'production load complete' AS result,
       (SELECT COUNT_BIG(*) FROM staging_phase2.BookingRequests) AS staged_bookings,
       (SELECT COUNT_BIG(*) FROM dbo.BookingRequest br
        INNER JOIN staging_phase2.BookingRequests s
            ON s.booking_request_id = br.booking_request_id) AS loaded_bookings;
