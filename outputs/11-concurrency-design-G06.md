# Concurrency design
As of now, the database is working as intended and accurately models the miniworld. However, as the user base grows, arises also the vulnerabilities that were not as apparent for small-scaled operations. These primarily stem from the fact that the database is not yet designed to handle concurrent events appropriately. This section is dedicated for just that.

# Stored procedures
The first step is to first group common operations into stored procedures. To this end, we shall design the procedures by declaring its name, parameters, purpose, and rough implementation. Unless specified otherwise, all attributes are mandatory.

- The procedure to add a new user is called <code>AddUser</code>. Its parameters are <code>user_id</code>, <code>surname</code>, <code>given_name</code>, <code>email</code>, <code>phone_number</code>, <code>user_role_code</code>, and <code>department_code</code>. The parameter <code>department_code</code> is optional. Its implementation is given as follows:
    - Check if <code>user_role_code</code> points to a valid <code>UserRole</code> value, otherwise throw.
    - Check if <code>department_code</code> points to a valid <code>Department</code> value, otherwise throw.
    - Insert into <code>User</code> with the obtained parameters, with the user status as <code>ACTIVE</code>.
- The procedure to add a new space is called <code>AddSpace</code>. Its parameters are <code>space_id</code>, <code>space_name</code>, <code>space_type_code</code>, <code>building</code>, <code>floor</code>, <code>room_number</code>, <code>capacity</code>, and <code>space_policy_id</code>. Its implementation is given as follows:
    - Check if <code>space_type_code</code> points to a valid <code>SpaceType</code> value, otherwise throw.
    - Insert into <code>Space</code> with the obtained parameters, with the space status as <code>AVAILABLE</code>.
- The procedure to create a new booking request is called <code>CreateBookingRequest</code>. Its parameters are <code>booking_request_id</code>, <code>user_id</code>, <code>space_id</code>, <code>requested_start_time</code>, <code>requested_end_time</code>, <code>purpose_code</code>, <code>expected_participants</code>, <code>advisory_acknowledged</code>. Its implementation is given as follows:
    - Store the current timestamp in a variable called <code>request_creation_date</code>.
	- Check if <code>requested_end_time</code> is later than <code>requested_start_time</code>, otherwise throw.
    - Get the <code>SpacePolicy</code> associated to <code>space_id</code>.
    - Check if the difference in minutes between <code>requested_end_time</code> and <code>requested_start_time</code> is equal to or above the policy's <code>min_duration_minutes</code>, otherwise throw.
    - Check if the diference in minutes between <code>requested_end_time</code> and <code>requested_start_time</code> is equal to or below the policy's <code>max_duration_minutes</code>, otherwise throw.
    - Check if the difference in days between <code>requested_start_time</code> and <code>request_creation_date</code> is equal to or below the policy's <code>booking_window_days</code>, otherwise throw.
    - Check if <code>purpose_code</code> points to a valid <code>Purpose</code> value, otherwise throw.
    - Check if the space has a bookable status (<code>AVAILABLE</code> or <code>IN_USE</code>), otherwise throw.
    - Check if the space does not have a reservation with conflicting time slot, otherwise throw.
    - Insert into <code>BookingRequest</code> with the obtained parameters, with the request state as <code>PENDING</code>.
- The procedure to cancel a booking request is called <code>CancelBookingRequest</code>. Its parameter is <code>booking_request_id</code>. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Update the corresponding <code>BookingRequest</code>'s request state to <code>CANCELED</code>.
- The procedure to add an approval review to a booking request is called <code>ApproveBookingRequest</code>. Its parameters are <code>review_id</code>, <code>reviewer_id</code>, <code>booking_request_id</code>, and <code>decision_note</code>. The parameters <code>decision_note</code> ia optional. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Insert into <code>Review</code> with the obtained parameters, with decision as <code>APPROVED</code>, <code>rejection_reason</code> as NULL and <code>decision_time</code> as the current timestamp.
- The procedure to add a reservation is called <code>AddReservation</code>. Its parameters are <code>reservation_id</code> and <code>booking_request_id</code>. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Insert into <code>Reservation</code> with the obtained parameters, with reservation status as <code>PENDING</code> and <code>usage_note</code> as NULL.
- The procedure to add a rejection review to a booking request is called <code>RejectBookingRequest</code>. Its parameters are <code>review_id</code>, <code>reviewer_id</code>, <code>booking_request_id</code>, <code>decision_note</code>, and <code>rejection_reason</code>. The parameters <code>decision_note</code> and <code>rejection_reason</code> are optional. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Insert into <code>Review</code> with the obtained parameters, with decision as <code>REJECTED</code> and <code>decision_time</code> as the current timestamp.
- The procedure to check in a reservation and thus commence it is called <code>StartReservationSession</code>. Its parameters are <code>reservation_id</code>, <code>attendant_id</code>, <code>checked_in_user_id</code>, and <code>space_initial_condition_code</code>. The parameter <code>actual_start_time</code> is optional and has the default value of the current timestamp. Its implementation is given as follows:
    - Check if <code>reservation_id</code> does not exist in <code>ReservationSession</code>, otherwise throw.
    - Get <code>checked_in_grace_minutes</code> from the reserved <code>Space</code>'s <code>SpacePolicy</code> and check if <code>actual_start_time</code> excceds <code>requested_start_time</code> by the imposed grace limit, otherwise throw.
    - Check if <code>space_initial_condition_code</code> points to a valid <code>SpaceCondition</code> value, otherwise throw.
    - Insert into <code>ReservationSession</code> with the obtained parameters, with <code>actual_start_time</code> as the current timestamp and <code>actual_end_time</code> and <code>space_final_condition_id</code> both as NULL.
    - Update the corresponding <code>Reservation</code>'s reservation status to <code>CHECKED_IN</code>.
    - Update the reserved <code>Space</code>'s space status to <code>IN_USE</code>.
- The procedure to finish a reservation is called <code>EndReservationSession</code>. Its parameters are <code>reservation_id</code>, <code>space_final_condition_code</code> and <code>usage_note</code>. The parameter <code>usage_note</code> is optional. Its implementation is given as follows:
    - Check if <code>reservation_id</code> exists in <code>ReservationSession</code>, otherwise throw.
    - Check if <code>space_final_condition_code</code> points to a valid <code>SpaceCondition</code> value, otherwise throw.
    - Update the corresponding <code>ReservationSession</code>'s <code>actual_end_time</code> to the current timestamp and <code>space_final_condition_id</code> to the obtained space condition ID.
    - Update the corresponding <code>Reservation</code>'s reservation status and <code>usage_note</code> to <code>COMPLETED</code> and the usage note parameter, respectively.
    - Update the reserved <code>Space</code>'s space status to <code>AVAILABLE</code>.
- The procedure to mark a reservation as no-show is called <code>NoShowReservation</code>. Its parameter is <code>reservation_id</code>. Its implementation is given as follows:
    - Update the corresponding <code>Reservation</code>'s reservation status to <code>NO_SHOW</code>.
- The procedure to create a maintenance is called <code>CreateMaintenance</code>. Its parameters are <code>maintenance_id</code>, <code>space_id</code>, <code>reporter_id</code>, and <code>maintenance_description</code>. The parameter <code>maintenance_description</code> is optional. Its implementation is given as follows:
    - Check if <code>space_id</code> points to a valid <code>Space</code>, otherwise throw.
    - Insert into <code>Maintenance</code> with the obtained parameters, with maintenance status as <code>PENDING</code> and <code>result_note</code> as NULL.
- The procedure to start a maintenance session is called <code>StartMaintenanceSession</code>. Its parameters are <code>maintenance_id</code>, <code>technician_id</code>, and <code>maintenance_impact_level_code</code>. Its implementation is given as follows:
    - Check if <code>maintenance_id</code> does not exist in <code>MaintenanceSession</code>, otherwise throw.
    - Check if <code>maintenance_impact_level_code</code> points to a valid <code>MaintenanceImpactLevel</code> value, otherwise throw.
    - Insert into <code>MaintenanceSession</code> with the supplied parameters, with <code>maintenance_start_time</code> as the current timestamp and <code>maintenance_end_time</code> as NULL.
    - Update the corresponding <code>Maintenance</code>'s maintenance status to <code>ONGOING</code>.
    - If the supplied maintenance impact level is out-of-service, update the serviced <code>Space</code>'s space status to <code>UNDER_CRIT_MAINT</code>.
- The procedure to end a maintenance session is called <code>EndMaintenanceSession</code>. Its parameters are <code>maintenance_id</code> and <code>result_note</code>. Its implementation is given as follows:
    - Check if <code>maintenance_id</code> exists in <code>MaintenanceSession</code>, otherwise throw.
    - Update the corresponding <code>MaintenanceSession</code>'s <code>maintenance_end_time</code> to the current timestamp.
    - Update the corresponding <code>Maintenance</code>'s maintenance status to <code>COMPLETED</code>.
    - If the supplied maintenance impact level is <code>OUT_OF_SERVICE</code> and there is no other maintenance on this space with impact level <code>OUT_OF_SERVICE</code>, update the serviced <code>Space</code>'s space status to <code>AVAILABLE</code>.
- The procedure to increase a maintenance impact level from advisory to out-of-service is called <code>EscalateMaintenance</code>. Its parameter is <code>maintenance_id</code>. Its implementation is given as follows:
    - Check if <code>maintenance_id</code> exists in <code>MaintenanceSession</code>, otherwise throw.
    - Check if the maintenance impact level is not <code>OUT_OF_SERVICE</code>, otherwise throw.
    - Update the corresponding <code>MaintenanceSession</code>'s maintenance impact level to <code>OUT_OF_SERVICE</code>.
    - Update the serviced <code>Space</code>'s space status to <code>UNDER_CRIT_MAINT</code>.
- The procedure to decrease a maintenance impact level from out-of-service to advisory is called <code>DowngradeMaintenance</code>. Its parameter is <code>maintenance_id</code>. Its implementation is given as follows:
    - Check if <code>maintenance_id</code> exists in <code>MaintenanceSession</code>, otherwise throw.
    - Check if the maintenance impact level is not <code>ADVISORY</code>, otherwise throw.
    - Update the corresponding <code>MaintenanceSession</code>'s maintenance impact level to <code>ADVISORY</code>.
    - If there is no other maintenance on this space with impact level <code>OUT_OF_SERVICE</code>, update the servied <code>Space</code>'s space status to <code>AVAILABLE</code>.
- The procedure to cancel a reservation when a maintenance commences on a reserved space is called <code>CancelReservation</code>. Its parameter is <code>reservation_id</code>. Its implementation is given as follows:
    - Check if the maintenance does not have an entry in <code>ReservationSession</code>, otherwise throw.
    - Update the corresponding <code>Reservation</code>'s reservation status to <code>CANCELED</code>.
- The procedure to auto-approve a booking request on a space that doesn't need human review (specified in the space's policy) is called <code>AutoApproveBookingRequest</code>. Its parameter is <code>booking_request_id</code>. Its implementation is given as follows:
    - Check if the requested space's <code>SpacePolicy</code> has <code>requires_approval</code> as false, otherwise throw.
    - Update the corresponding <code>BookingRequest</code>'s request state to <code>AUTO_APPROVED</code>.

# Functions
Similar to stored procedures, functions are also a set of instructions to perform a specific tasks. The difference is that functions often return a value (a scalar or a table), whereas stored procedure primarily modify. Because of the similarity, we treat this section the same way as the previous one.

- The function to retrieve all active advisories on a space is called <code>GetAllAdvisories</code>. Its parameter is <code>space_id</code>. Its implementation is given as follows:
    - Get all ongoing maintenance associated with the given <code>Space</code> that has maintenance impact level of <code>ADVISORY</code>.
- The function to retrieve all reservations associated to a space that is under critical maintenance is called <code>GetReservationsFromCriticalSpace</code>. Its parameter is <code>space_id</code>. Its implementation is given as follows:
    - Check if the given <code>Space</code>'s space status is <code>UNDER_CRIT_MAINT</code>, otherwise throw.
    - Get all <code>Reservation</code>s whose reservation status is <code>PENDING</code> or <code>CHECKED_IN</code> with associated <code>Space</code> having a <code>Maintenance</code> with an ongoing critical impact.
- The function to get total approved booking hours of each space during a time period is called <code>GetReservationTimePerSpace</code>. Its parameters are <code>start_time</code> and <code>end_time</code>, both of which are optional. Its implementation is given as follows:
    - Aggregate all reservation sessions hours grouping by spaces. If provided, only reservations whose actual start time exceeds <code>start_time</code> are chosen, and only those who actual end time falls below <code>end_time</code> are chosen.
- The function to retrieve the number of approved booking requests by weekday and hour during a time period is called <code>GetReservationCountPerHourPerWeekday</code>. Its parameters are <code>start_time</code> and <code>end_time</code>, both of which are optional. Its imeplementation is given as follows:
    - Aggregate the count of all reservation sessions grouping by weekday and hour. If provided, only reservations whose actual start time exceeds <code>start_time</code> are chosen, and only those who actual end time falls below <code>end_time</code> are chosen.