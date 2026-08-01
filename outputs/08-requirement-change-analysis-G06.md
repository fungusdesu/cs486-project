# Business requirements update & second validation
This section is reserved to discuss the changes to the business requirements in Phase 1, as well as a second validation of the current database design to ensure all tables satisfy at least third normal form (3NF). Naturally, the conceptual and logical ER diagrams are also adjusted accordingly to suit the modifications.

# Business requirements update
The update that is of most importance is the addition of a maintenance impact level. Previously, we assumed that all maintenance sessions render the space unusable and will thus put the space in a <code>SpaceStatus</code> of "under maintenance". From the new business requirements, we have devised modifications to the entities as follows:
- The addition of a new reference entity type <code>MaintenanceImpactLevel</code> to represent a maintenance's level of impact upon the usability of the space. Currently, there are two relevant entities this entity type will have: <code>ADVISORY</code> (indicating a maintenance that should not leave the space unbookable) and <code>OUT_OF_SERVICE</code> (indicating otherwise).
- An appended attribute <code>maintenance_imapct_level_id</code> to the entity type <code>Maintenance</code>. The attribute is referenceable via <code>MaintenanceImpactLevel</code>.
- A space may have several active maintenance records at the same time. In other words, different maintenance sessions on the same space may have overlapping <code>maintenance_time_slot</code>. In practice, this imposes no change on our design.
- Users may still book a space under advisory impact level, but the request must be made with an acknowledgement that the user is aware of the space's ongoing maintenance sessions. A new column <code>advisory_acknowledged</code> is added to <code>BookingRequest</code>.

# Second validation
We perform a second validation in order to set the stage for our 3NF validation. Because of this, we have identified some problems that did not manifest as clearly in our first validation:
- The relationship <code>books</code> and <code>maintains</code> are unnecessary. Because each booking request and maintenance uniquely identify user-space and technician-space pairs, respectively, separating them into their own table introduces redundancy. We thus decompose the former into two relationships <code>makes_request</code> and <code>requests_space</code>, and the latter into <code>carries_out</code> and <code>services</code>.
    - The binary <code>1:N</code> relationship <code>makes_request</code> has two participating entities <code>User</code> (with cardinality <code>(0, N)</code>) and <code>BookingRequest</code> (with cardinality <code>(1, 1)</code>).
    - The binary <code>N:1</code> relationship <code>requests_space</code> has two participating entities <code>BookingRequest</code> (with cardinality <code>(1, 1)</code>) and <code>Space</code> (with cardinality <code>(0, N)</code>).
    - The binary <code>1:N</code> relationship <code>carries_out</code> has two participating entities <code>User</code> (with cardinality <code>(0, N)</code>) and <code>Maintenance</code> (with cardinality <code>(1, 1)</code>).
    - The binary <code>N:1</code> relationship <code>services</code> has two participating entities <code>Maintenance</code> (with cardinality <code>(1, 1)</code>) and <code>Space</code> (with cardinality <code>(0, N)</code>).
- The entity type <code>Decision</code> does not exactly reflect the segregation between the decision of a review (approved, rejected) and the decision of a user action (pending, cancelled). As such, it is sensible to decompose this entity type into two separate entity type:
    - The reference entity type <code>RequestState</code> consisting of the states of pending, reviewed, and cancelled.
    - The reference entity type <code>RequestDecision</code> consisting of the decisions of approved and rejected.
- We work under the refined assumption that a booking request may be reviewed more than once. To this end, the entity type <code>Review</code> must allow alterations on a booking request's approval status while preserving the history of the booking request's lifecycle. In order to comply, the following changes on <code>Review</code> are made:
	- An attribute <code>review_id</code> serving as a surrogate key for each review on booking requests. In addition, the ID must be exactly 9 letters long in the format <code>xxxx-xxxx</code>, where <code>x</code> is any lowercase alphanumeric character, and the hyphen is treated literally.
	- The associations to <code>BookingRequest</code> and <code>User</code> are broken down into relationships <code>inspects</code> and <code>determines</code>, respectively.
    	- The binary <code>N:1</code> relationship <code>inspects</code> has two participating entity types: <code>Review</code> and <code>BookingRequest</code>. The former has a cardinality of <code>(1, 1)</code>, and the latter has a cardinality of <code>(0, N)</code>.
    	- The binary <code>1:N</code> relationship <code>determines</code> has two participating entity types: <code>User</code> and <code>Review</code>. The former has a cardinality of <code>(0, N)</code>, and the latter has a cardinality of <code>(1, 1)</code>.
	- <code>Review</code> is now eligible to be promoted from an associative entity type to an operational entity type.
- Due to the consistency of some identifier attributes, it is more appropriate for them to be changed from <code>VARCHAR</code> type to <code>CHAR</code>. These attributes are <code>user_id</code>, <code>booking_request_id</code>, <code>review_id</code>, <code>reservation_id</code>, <code>maintenance_id</code>, <code>space_policy_id</code>.
- We aim to reinforce the fact that <code>ReservationCheckIn</code> is a partition from <code>Reservation</code>, where the latter is often retrieved much more frequently. To this end, the following changes are to be made:
    - <code>ReservationCheckIn</code> is renamed to <code>ReservationSession</code>.
    - The associations to two instances of <code>User</code> is broken down into relationships <code>attends</code> and <code>checks_in</code> for two attendants and check-in users, respectively.
        - The binary <code>1:N</code> relationship <code>attends</code> has two participating entity types: <code>User</code> and <code>ReservationSession</code>. The former has a cardinality of <code>(0, N)</code>, and the latter has a cardinality of <code>(1, 1)</code>.
        - This is the exact same case for the binary <code>1:N</code> relationship <code>checks_in</code>.
    - The association to <code>Reservation</code> is also decomposed into the relationship <code>from_reservation</code>. This relationship is injective and connects its two particiapating entities <code>ReservationSession</code> and <code>Reservation</code>. The former has a cardinality of <code>(1, 1)</code>, whereas the latter has a cardinality of <code>(0, 1)</code>.
    - <code>ReservationSession</code> is now eligible to be promoted from an associative entity type to an operational one.
- A new reservation status called "canceled" is added to signify a reservation that may get canceled from the management side.

# Third normal form validation
We are now ready to verify that our database schema in fact follows 3NF for every table. Recall that after the modifications enlisted above, our SQL database has a total of 22 tables. Because 13 tables of which are reference entity types, it is trivially in 3NF. This section is dedicated to show that the remaining 9 operational entity types are also in 3NF. To this end, we follow the following procedure:
- Compute the set of every candidate key
- Compute the canonical cover of functional dependencies (FDs)
- Compare the FDs against the conditions of 2NF and 3NF