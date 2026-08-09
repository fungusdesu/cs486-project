# Concurrency design
As of now, the database is working as intended and accurately models the miniworld. However, as the user base grows, arises also the vulnerabilities that were not as apparent for small-scaled operations. These primarily stem from the fact that the database is not yet designed to handle concurrent events appropriately. This section is dedicated for just that.

# Stored procedures
The first step is to first group common operations into stored procedures. To this end, we shall design the procedures by declaring its name, parameters, purpose, and rough implementation. Unless specified otherwise, all attributes are mandatory.

- The procedure to add a new user is called <code>AddUser</code>. Its parameters are <code>user_id</code>, <code>surname</code>, <code>given_name</code>, <code>email</code>, <code>phone_number</code>, <code>user_role_code</code>, and <code>department_code</code>. The parameter <code>department_code</code> is optional. Its implementation is given as follows:
    - Check if <code>user_role_code</code> points to a valid <code>UserRole</code> value, otherwise throw.
    - Check if the department is provided if the given user role is <code>STUDENT</code>, <code>LECTURER</code>, <code>TA</code>, or <code>DEPT_ADMIN</code>, otherwise throw.
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
- The procedure to add an approval review to a booking request is called <code>ApproveBookingRequest</code>. Its parameters are <code>review_id</code>, <code>reviewer_id</code>, <code>booking_request_id</code>, and <code>decision_note</code>. The parameters <code>decision_note</code> is optional. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Check if <code>booking_request_id</code> already has an approved review, otherwise throw.
    - Insert into <code>Review</code> with the obtained parameters, with decision as <code>APPROVED</code>, <code>rejection_reason</code> as NULL and <code>decision_time</code> as the current timestamp.
    - Update <code>BookingRequest</code>'s request state to <code>REVIEWED</code>.
- The procedure to add a reservation is called <code>AddReservation</code>. Its parameters are <code>reservation_id</code> and <code>booking_request_id</code>. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Insert into <code>Reservation</code> with the obtained parameters, with reservation status as <code>PENDING</code> and <code>usage_note</code> as NULL.
- The procedure to add a rejection review to a booking request is called <code>RejectBookingRequest</code>. Its parameters are <code>review_id</code>, <code>reviewer_id</code>, <code>booking_request_id</code>, <code>decision_note</code>, and <code>rejection_reason</code>. The parameters <code>decision_note</code> and <code>rejection_reason</code> are optional. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Check if <code>booking_request_id</code> already has an approved review, otherwise throw.
    - Insert into <code>Review</code> with the obtained parameters, with decision as <code>REJECTED</code> and <code>decision_time</code> as the current timestamp.
    - Update <code>BookingRequest</code>'s request state to <code>REVIEWED</code>.
- The procedure to check in a reservation and thus commence it is called <code>StartReservationSession</code>. Its parameters are <code>reservation_id</code>, <code>attendant_id</code>, <code>checked_in_user_id</code>, and <code>space_initial_condition_code</code>. Its implementation is given as follows:
    - Store the current timestamp in <code>actual_start_time</code>.
    - Check if <code>reservation_id</code> exists in <code>Reservation</code>, otherwise throw.
    - Check if the reservation status is <code>PENDING</code>, otherwise throw.
    - Get <code>checked_in_grace_minutes</code> from the reserved <code>Space</code>'s <code>SpacePolicy</code> and check if <code>actual_start_time</code> excceds <code>requested_start_time</code> by the imposed grace limit, otherwise throw.
    - Check if <code>space_initial_condition_code</code> points to a valid <code>SpaceCondition</code> value, otherwise throw.
    - Insert into <code>ReservationSession</code> with the obtained parameters, with <code>actual_start_time</code> as the current timestamp and <code>actual_end_time</code> and <code>space_final_condition_id</code> both as NULL.
    - Update the corresponding <code>Reservation</code>'s reservation status to <code>CHECKED_IN</code>.
    - Update the reserved <code>Space</code>'s space status to <code>IN_USE</code>.
- The procedure to finish a reservation is called <code>EndReservationSession</code>. Its parameters are <code>reservation_id</code>, <code>space_final_condition_code</code> and <code>usage_note</code>. The parameter <code>usage_note</code> is optional. Its implementation is given as follows:
    - Store the current timestamp in <code>actual_end_time</code>.
    - Check if <code>reservation_id</code> exists in <code>Reservation</code>, otherwise throw.
    - Check if the reservation status is <code>CHECKED_IN</code>, otherwise throw.
    - Check if <code>space_final_condition_code</code> points to a valid <code>SpaceCondition</code> value, otherwise throw.
    - Update the corresponding <code>ReservationSession</code>'s <code>actual_end_time</code> to <code>actual_end_time</code> variable and <code>space_final_condition_id</code> to the obtained space condition ID.
    - Update the corresponding <code>Reservation</code>'s reservation status and <code>usage_note</code> to <code>COMPLETED</code> and the usage note parameter, respectively.
    - Update the reserved <code>Space</code>'s space status to <code>AVAILABLE</code>.
- The procedure to mark a reservation as no-show is called <code>NoShowReservation</code>. Its parameter is <code>reservation_id</code>. Its implementation is given as follows:
    - Update the corresponding <code>Reservation</code>'s reservation status to <code>NO_SHOW</code>.
- The procedure to create a maintenance is called <code>CreateMaintenance</code>. Its parameters are <code>maintenance_id</code>, <code>space_id</code>, <code>reporter_id</code>, and <code>maintenance_description</code>. The parameter <code>maintenance_description</code> is optional. Its implementation is given as follows:
    - Check if <code>space_id</code> points to a valid <code>Space</code>, otherwise throw.
    - Insert into <code>Maintenance</code> with the obtained parameters, with maintenance status as <code>PENDING</code> and <code>result_note</code> as NULL.
- The procedure to start a maintenance session is called <code>StartMaintenanceSession</code>. Its parameters are <code>maintenance_id</code>, <code>technician_id</code>, and <code>maintenance_impact_level_code</code>. Its implementation is given as follows:
    - Store the current timestamp in <code>maintenance_start_time</code>.
    - Check if the maintenance status is <code>PENDING</code>, otherwise throw.
    - Check if <code>maintenance_impact_level_code</code> points to a valid <code>MaintenanceImpactLevel</code> value, otherwise throw.
    - Insert into <code>MaintenanceSession</code> with the supplied parameters, with <code>maintenance_end_time</code> as NULL.
    - Update the corresponding <code>Maintenance</code>'s maintenance status to <code>ONGOING</code>.
    - If the supplied maintenance impact level is out-of-service, update the serviced <code>Space</code>'s space status to <code>UNDER_CRIT_MAINT</code>.
- The procedure to end a maintenance session is called <code>EndMaintenanceSession</code>. Its parameters are <code>maintenance_id</code> and <code>result_note</code>. The parameter <code>result_note</code> is optional. Its implementation is given as follows:
    - Store the current timestamp in <code>maintenance_end_time</code>.
    - Check if the maintenance status is <code>ONGOING</code>, otherwise throw.
    - Update the corresponding <code>MaintenanceSession</code>'s <code>maintenance_end_time</code> to <code>maintenance_end_time</code> variable.
    - Update the corresponding <code>Maintenance</code>'s maintenance status to <code>COMPLETED</code>.
    - If there is no other ongoing maintenance on this space with impact level <code>OUT_OF_SERVICE</code>, update the serviced <code>Space</code>'s space status to <code>AVAILABLE</code>.
- The procedure to increase a maintenance impact level from advisory to out-of-service is called <code>EscalateMaintenance</code>. Its parameter is <code>maintenance_id</code>. Its implementation is given as follows:
    - Check if the maintenance status is <code>ONGOING</code>, otherwise throw.
    - Check if the maintenance impact level is not <code>OUT_OF_SERVICE</code>, otherwise throw.
    - Update the corresponding <code>MaintenanceSession</code>'s maintenance impact level to <code>OUT_OF_SERVICE</code>.
    - Update the serviced <code>Space</code>'s space status to <code>UNDER_CRIT_MAINT</code>.
- The procedure to decrease a maintenance impact level from out-of-service to advisory is called <code>DowngradeMaintenance</code>. Its parameter is <code>maintenance_id</code>. Its implementation is given as follows:
    - Check if the maintenance status is <code>ONGOING</code>, otherwise throw.
    - Check if the maintenance impact level is not <code>ADVISORY</code>, otherwise throw.
    - Update the corresponding <code>MaintenanceSession</code>'s maintenance impact level to <code>ADVISORY</code>.
    - If there is no other ongoing maintenance on this space with impact level <code>OUT_OF_SERVICE</code>, update the servied <code>Space</code>'s space status to <code>AVAILABLE</code>.
- The procedure to cancel a reservation when a maintenance commences on a reserved space is called <code>CancelReservation</code>. Its parameter is <code>reservation_id</code>. Its implementation is given as follows:
    - Check if the reservation status is <code>PENDING</code>, otherwise throw.
    - Update the corresponding <code>Reservation</code>'s reservation status to <code>CANCELED</code>.
- The procedure to auto-approve a booking request on a space that doesn't need human review (specified in the space's policy) is called <code>AutoApproveBookingRequest</code>. Its parameter is <code>booking_request_id</code>. Its implementation is given as follows:
    - Check if the requested space's <code>SpacePolicy</code> has <code>requires_approval</code> as false, otherwise throw.
    - Update the corresponding <code>BookingRequest</code>'s request state to <code>AUTO_APPROVED</code>.

# Functions
Similar to stored procedures, functions are also a set of instructions to perform a specific task. The difference is that functions often return a value (a scalar or a table), whereas stored procedure primarily modify. Because of the similarity, we treat this section the same way as the previous one.

- The function to retrieve all active advisories on a space is called <code>GetAllAdvisories</code>. Its parameter is <code>space_id</code>. Its implementation is given as follows:
    - Get all ongoing maintenance associated with the given <code>Space</code> that has maintenance impact level of <code>ADVISORY</code>.
- The function to retrieve all reservations associated to a space that is under critical maintenance is called <code>GetReservationsFromCriticalSpace</code>. Its parameter is <code>maintenance_id</code>. Its implementation is given as follows:
    - Get all <code>Reservation</code>s whose reservation status is <code>PENDING</code> or <code>CHECKED_IN</code> with the associated <code>Space</code>.
- The function to get total approved booking hours of each space during a time period is called <code>GetReservationTimePerSpace</code>. Its parameters are <code>start_time</code> and <code>end_time</code>, both of which are optional. Its implementation is given as follows:
    - Aggregate all reservation sessions hours grouping by spaces. If provided, only reservations whose actual start time exceeds <code>start_time</code> are chosen, and only those who actual end time falls below <code>end_time</code> are chosen.
- The function to retrieve the number of approved booking requests by weekday and hour during a time period is called <code>GetReservationCountPerHourPerWeekday</code>. Its parameters are <code>start_time</code> and <code>end_time</code>, both of which are optional. Its implementation is given as follows:
    - Aggregate the count of all reservation sessions grouping by weekday and hour. If provided, only reservations whose actual start time exceeds <code>start_time</code> are chosen, and only those who actual end time falls below <code>end_time</code> are chosen.
- The function to retrieve the list of spaces satisfying a capacity and a facility list is called <code>GetSatisfactorySpaces</code>. Its parameters are <code>capacity</code> and <code>facility_table</code>. Its implementation is given as follows:
    - Perform relational division on the association table between <code>Facility</code> and <code>Space</code>, and the given <code>facility_table</code>.
    - Filter the result by capacity.

# Concurrency handling
Now that we have grouped operations into procedures and functions, given their implementations, it is safe to assume that these procedures must be atomic; i.e., the procedure is inseparable and must be either fully executed or not executed at all. It is also relatively safe to assume the procedures are also consistent and durable were we to utilize SQL's transactions. The dilemma we are most interested is to determine how isolated should the transactions be.

After much deliberation, we decided to take a pessimistic approach towards concurrency. Recall that there are four isolation levels adhering to the pessimistic control principles:
- Read uncommitted: this is the lowest isolation level, where transactions are able to read the changes from each other, even if the changes are uncommited.
- Read committed: this isolation level locks uncommitted changes away from other transactions, thus preventing dirty reads.
- Repeatable: this isolation level locks read and write access away from other transactions, thus preventing non-repeatable reads.
- Serializable: the highest form of concurrency control, where read, write, and insert access are locked away from other transactions (provided that insertions are to be performed on the ranges of read keys), thus preventing phantom reads.

The reason determining isolation level is important is that we are also gauging how much performance to sacrifice in tradeoff of safety. To this end, we dedicate this section to identifying possible conflicts between procedures and functions, determining how threatening they are to real world operations, and thus evaluating the appropriate isolation level.

We start with the lowest isolation level&mdash;read uncommited.

## Exhibit A: Booking an out-of-service space
Consider two stored procedures <code>CreateBookingRequest</code> and <code>StartMaintenanceSession</code> on the same space with the following schedule (some implementation details are trimmed for clarity):

| <code>StartMaintenanceSession</code>               | <code>CreateBookingRequest</code>          |
|:--------------------------------------------------:|:------------------------------------------:|
| Start transaction                                  |                                            |
|                                                    | Start transaction                          |
| Set space status to <code>UNDER_CRIT_MAINT</code>  |                                            |
|                                                    | Read space status (<code>AVAILABLE</code>) |
|                                                    | Create booking request                     |
| Commit                                             |                                            |
|                                                    | Commit                                     |

Observe that <code>CreateBookingRequest</code> reads the space status and sees that it is available. However, <code>StartMaintenanceSession</code> was running in parallel, setting that same space status to <code>UNDER_CRIT_MAINT</code> (which will cause <code>CreateBookingRequest</code> to throw were the check run later). What results is a dirty read from <code>CreateBookingRequest</code> and a wrongful insertion to the list of pending requests without a notice to the booker that the space was immediately under maintenance right after. This critically affects our operations, have a fair chance of happening, and thus warrants a raise in isolation level to read commited.

## Exhibit B: Starting a canceled reservation
Consider two stored procedures <code>StartReservationSession</code> and <code>CancelReservation</code> on the same reservation with the following schedule:

| <code>StartReservationSession</code>                 | <code>CancelRservation</code>                      |
|:----------------------------------------------------:|:--------------------------------------------------:|
| Start transaction                                    |                                                    |
| Read <code>reservation_id</code>                     |                                                    |
|                                                      | Start transaction                                  |
|                                                      | Update reservation status to <code>CANCELED</code> |
|                                                      | Commit                                             |
| Update reservation status to <code>CHECKED_IN</code> |                                                    |
| Commit                                               |                                                    |

After committing the changes to the reservation status to <code>CANCELED</code>, the reservation status is changed to <code>CHECKED_IN</code> by <code>StartReservationSession</code>, thus nullifying <code>CancelReservation</code>'s result as a whole. This moderately affects our operations, but does not happen frequently enough to warrant a higher isolation level on its own.

## Exhibit C: Reviewing an already approved request
Consider two transactions A, B of the stored procedure <code>ApproveBookingRequest</code> executing at the same time, resulting in the following schedule:

| <code>ApproveBookingRequest</code>            | <code>ApproveBookingRequest</code>            |
|:---------------------------------------------:|:---------------------------------------------:|
| Start transaction A                           |                                               |
| Check if there is a review on booking request |                                               |
|                                               | Start transaction B                           |
|                                               | Check if there is a review on booking request |
|                                               | Update request state and add review           |
|                                               | Add reservation                               |
|                                               | Commit                                        |
| Update request state and add review           |                                               |
| Add reservation                               |                                               |
| Commit                                        |                                               |

This stems from two instances of reviewing the same booking request at the same time. Because there are data definition safeguards (<code>booking_request_id</code> is a unique key in <code>Reservation</code>), duplicated reservation is prevented. However, this instead causes duplicated approved review on the same request. Considering the common occurence of duplicated review, exhibit B and C altogether thus justify a raise in the isolation level to repeatable.

After much deliberation, we deemed that phantom reads do not affect critically to our system, and the performance cost incurred by further increasing isolation level is not justifiable. We thus conclude that the system shall obey repeatable isolation level.