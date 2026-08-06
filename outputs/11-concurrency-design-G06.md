# Concurrency design
As of now, the database is working as intended and accurately models the miniworld. However, as the user base grows, arises also the vulnerabilities that were not as apparent for small-scaled operations. These primarily stem from the fact that the database is not yet designed to handle concurrent events appropriately. This section is dedicated for just that.

# Stored procedures
The first step is to first group common operations into stored procedures. To this end, we shall design the procedures by declaring its name, parameters, purpose, and rough implementation. Unless specified otherwise, all attributes are mandatory.

- The procedure to add a new user is called <code>AddUser</code>. Its parameters are <code>user_id</code>, <code>surname</code>, <code>given_name</code>, <code>email</code>, <code>phone_number</code>, <code>user_role_code</code>, and <code>department_code</code>. The parameter <code>department_code</code> is optional. Its implementation is given as follows:
    - Check if <code>user_role_code</code> points to a valid <code>UserRole</code> value, otherwise throw.
    - Check if <code>department_code</code> points to a valid <code>Department</code> value, otherwise throw.
    - Get the ID of the supplied <code>UserRole</code> and <code>Department</code>.
    - Get the ID of the <code>UserStatus</code> pointed to by <code>ACTIVE</code>.
    - Insert into <code>User</code> with the obtained parameters.
- The procedure to add a new space is called <code>AddSpace</code>. Its parameters are <code>space_id</code>, <code>space_name</code>, <code>space_type_code</code>, <code>building</code>, <code>floor</code>, <code>room_number</code>, <code>capacity</code>, and <code>space_policy_id</code>. Its implementation is given as follows:
    - Check if <code>space_type_code</code> points to a valid <code>SpaceType</code> value, otherwise throw.
    - Get the ID of the supplied <code>SpaceType</code>.
    - Get the ID of the <code>SpaceStatus</code> pointed to by <code>AVAILABLE</code>.
    - Insert into <code>Space</code> with the obtained parameters.
- The procedure to create a new booking request is called <code>CreateBookingRequest</code>. Its parameters are <code>booking_request_id</code>, <code>user_id</code>, <code>space_id</code>, <code>request_creation_time</code>, <code>requested_start_time</code>, <code>requested_end_time</code>, <code>purpose_code</code>, <code>expected_participants</code>, <code>advisory_acknowledged</code>. The paramter <code>request_creation_time</code> is optional and has a default value of the current timestamp. Its implementation is given as follows:
    - Check if <code>purpose_code</code> points to a valid <code>Purpose</code> value, otherwise throw.
    - Get the ID of the supplied <code>Purpose</code>.
    - Get the ID of the <code>RequestState</code> pointed to by <code>PENDING</code>.
    - Insert into <code>BookingRequest</code> with the obtained parameters.
- The procedure to cancel a booking request is called <code>CancelBookingRequest</code>. Its parameter is <code>booking_request_id</code>. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Get the ID of the <code>RequestState</code> pointed to by <code>CANCELED</code>.
    - Update the corresponding <code>BookingRequest</code>'s <code>request_state_id</code> to the obtained canceled ID.
- The procedure to add an approval review to a booking request is called <code>ApproveBookingRequest</code>. Its parameters are <code>review_id</code>, <code>reviewer_id</code>, <code>booking_request_id</code>, <code>decision_time</code>, and <code>decision_note</code>. The parameters <code>decision_time</code> and <code>decision_note</code> are optional, the former has a default value of the current timestamp. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Get the ID of the <code>RequestDecision</code> pointed to by <code>APPROVED</code>.
    - Get the ID of the <code>RequestState</code> pointed to by <code>REVIEWED</code>.
    - Update the corresponding <code>BookingRequest</code>'s <code>request_state_id</code> to the obtained reviewed ID.
    - Insert into <code>Review</code> with the obtained parameters, with <code>rejection_reason</code> as NULL.
- The procedure to add a reservation is called <code>AddReservation</code>. Its parameters are <code>reservation_id</code> and <code>booking_request_id</code>. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Get the ID of the <code>ReservationStatus</code> pointed to by <code>PENDING</code>.
    - Insert into <code>Reservation</code> with the obtained parameters, with <code>usage_note</code> as NULL.
- The procedure to add a rejection review to a booking request is called <code>RejectBookingRequest</code>. Its parameters are <code>review_id</code>, <code>reviewer_id</code>, <code>booking_request_id</code>, <code>decision_time</code>, <code>decision_note</code>, and <code>rejection_reason</code>. The parameters <code>decision_time</code>, <code>decision_note</code>, and <code>rejection_reason</code> are optional, the former has a default value of the current timestamp. Its implementation is given as follows:
    - Check if <code>booking_request_id</code> points to a valid <code>BookingRequest</code>, otherwise throw.
    - Get the ID of the <code>RequestDecision</code> pointed to by <code>REJECTED</code>.
    - Get the ID of the <code>RequestState</code> pointed to by <code>REVIEWED</code>.
    - Update the corresponding <code>BookingRequest</code>'s <code>request_state_id</code> to the obtained reviewed ID.
    - Insert into <code>Review</code> with the obtained parameters.