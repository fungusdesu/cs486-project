# Business purpose
Manage the School of Computer Science physical spaces procedures, including booking requests and approvals, facility logging and maintenance, and space conditions management.

# Actors
- **Database Administrators (DBAs)**: Staff of the School in charge of authorizing access to the database, updating the database to its latest versions, and handle events like data breaches and system failures.
- **Database Designers**: Developers responsible for delineating the database structures and constraints for an appropriate representation of the relevant data, as well as an efficient data storage method.
- **Casual End Users**: Maintenance staff and space managers. These people occasionally access the database for a different purpose each time.
- **Naive End Users**: Space requesters, approvers, faculties staff, etc. access the database frequently through canned transactions provided to them via an interface&mdash;mobile apps, websites.
- **Sophisticated End Users**: Engineers and developers who are well familiar with database systems for complex integration development and benchmarking.

# Schema design &ndash; Entities & attributes
This section outlines the relevant entities with their attributes. We delineate three types of entity types we will utilize: regular entities, reference entities, and associative entities. The following outlines reference entities&mdash;entities that more closely resemble enums.

The schema of reference entities here are deliberately designed to be as predictable as possible. All reference entities have precisely three attributes pertaining to the ID (auto-incremental ID), code (more readable identifier of the entity), and name (human readable identifier) of the transient entities. The attribute names are easily obtained by converting the entity type's ProperName into snake_case and append <code>_id</code>, <code>_code</code>, or <code>_name</code>.
- Spaces are categorized into types <code>SpaceType</code> depending on their functionalities (e.g., auditorium, classroom).
- A space has a status <code>SpaceStatus</code> that determines their bookability (e.g., available, in use, under maintenance)
- Users are designated roles <code>UserRole</code> that can give them additional privileges (e.g., student, lecturer, facility staff).
- The School is organized into departments <code>Department</code> (e.g., information technology, mathematics).
- Facilities are provided in spaces and have their own types <code>FacilityType</code> depending on which kind of appliances they are (e.g., chair, air conditioner).
- Purposes <code>Purpose</code> to occupy a space can be divided into categories (e.g. lecture, exam, workshop)
- A reservation (approved booking request) to a space also has a status <code>ReservationStatus</code> (e.g., pending, checked in, no-show)
- Finally, a maintenance also has status <code>MaintenanceStatus</code> to determine its bookability (e.g., ongoing, completed).

We now move on to regular entities&mdash;entities that represent operational entities with its own lifecycle.
- The School will be organized into physical spaces to be booked <code>Space</code>. Its attributes are as follows:
	- <code>space_id</code>: a unique space ID. For clarity in space identification, each space will be assigned an ID that can span from 3 to 5 letters. For instance, auditorium 1 maybe labeled as <code>HT1</code>, and classroom 12b in building I will be labeled as <code>I12b</code>.
	- <code>space_name</code>: the name of the space. For instance, auditorium 1 may have the value <code>Auditorium 1</code>. Generally, different spaces should have unique names, but we decide to err on the side of caution and assume two different spaces may have the same name.
	- <code>space_type_id</code>: the space type ID referenceable via <code>SpaceType</code>.
	- <code>space_location</code>: the location of the building, identified by its room number, floor, and building in which it resides. It is thus appropriate to model the location as a composite attribute comprising of subattributes <code>building</code>, <code>floor</code>, and <code>room_number</code>. For instance, the classroom I34 located in <code>I34</code> may be broken down into atomic locations; i.e., building <code>I</code>, floor <code>3</code>, room <code>4</code>.
	- <code>capacity</code>: the maximum number of occupants the space can house. For example, auditorium 1 may contain a maximum of 80 people, thus its value is <code>80</code>.
	- <code>status_id</code>: the space status ID referenceable via <code>SpaceStatus</code>.
	- <code>policy</code>: **EXACT VALUE OF POLICY IS UNKNOWN**
- The School is comprised of students, staff, and maintenance personnels, which is identified on the system via their account. We may assume each user only holds precisely one account and thus can be modeled via a <code>User</code> entity type. Its attributes are as follows:
	- <code>user_id</code>: a unique user ID. To prevent malicious actors enumerating the database, we design this attribute under the assumption that the user ID is generated as an 8-digit numeric ID that was generated on user creation.
	- <code>full_name</code>: the full name of the user consisting of first name, middle name, and last name. It is sensible to represent this attribute as a composition of <code>surname</code>, and <code>given_name</code>. For example, the user whose <code>full_name</code> is <code>Nguyễn Quốc Nam</code> may be decomposed into <code>Nguyễn</code> for <code>surname</code> and <code>Quốc Nam</code> for <code>given_name</code>.
	- <code>email</code>: the email of the user. For instance, the user <code>Trần Tôn Minh Kỳ</code> may have the email <code>minhkymikuuwu@gmail.com</code>.
	- <code>phone_number</code>: the contact phone number of the user. For instance, the user <code>Trần Tôn Minh Kỳ</code> may have the number <code>0396769420</code>.
	- <code>user_role_id</code>: the role ID of the user referenceable via <code>UserRole</code>.
	- <code>department_id</code>: the department ID of the user referenceable via <code>Department</code>.
	- <code>status</code>: **EXACT STATUSES AN ACCOUNT MAY BE IN IS UNKNOWN**
- Each space can possess an array of facilities, represented by the entity type <code>Facility</code>. These include teaching equipment such as boards, TVs, desks, chairs, .etc. Each facility will have two attributes:
	- <code>facility_id</code>: the ID of the facility. The ID is standardized to be at least 4 letters long, where the first three are alphabetical and describe the facility type, and the last part is numeric and describe the natural ordering&mdash;i.e., the sequential ID of the facility for its type. It is thus reasonable to construct <code>facility_id</code> as a composite attribute being comprised of <code>facility_type_id</code> referenceable via <code>FacilityType</code>, and <code>facility_sequence_number</code>. For instance, a chair may have its type ID of <code>1</code> and a sequence number of <code>55</code>, thus forming a facility ID of <code>1_55</code>.
	- <code>facility_name</code>: the name of the facility, such as <code>Mitsubishi Air Conditioner</code> or <code>Blackboard</code>.
	- <code>space_id</code>: the space to which the facility belongs. An air conditioner <code>2_1</code> may belong to the space <code>HT1</code>, for example.
- A user makes a request to book a space, thus forming a  <code>BookingRequest</code> entity. We choose to not include the requester and the requested space as attributes of a request and prefer to assign them to the properties more innate to the request itself&mdash;the reason for which will be elaborated on the discussion of the database relationships. Otherwise, a <code>BookingRequest</code> contains the following attributes:
	- <code>booking_request_id</code>: a lowercase 8 letters long alphanumeric ID identifying a request. For the same reason as <code>user_id</code>, the ID is not enumerable.
	- <code>requested_time_slot</code>: the requested period of time to occupy the room. It stands to reason to split this into two more atomic attributes <code>requested_start_time</code> and <code>requested_end_time</code> denoting the particular timestamped endpoints. As an example, a user may book the room <code>I34</code> with a time slot of <code>2026-6-20, 13:00:00 -- 2026-6-20, 17:30:00</code>, the former and latter timestamps convey the start time and end time, respectively.
	- <code>purpose_id</code>: the purpose ID of the space referenceable via <code>Purpose</code>.
	- <code>expected_participants</code>: the expected number of participants to occupy the room. Using the above example, the room <code>I34</code> may expect <code>30</code> people to attend the workshop.
- Once a booking request has been approved, it transforms into a <code>Reservation</code>. Its attributes are as follows:
	- <code>reservation_id</code>: an uppercase 8 letters long alphanumeric ID identifying a reservation. Again, not enumarable.
	- <code>booking_request_id</code>: the booking request from which prompted a reservation. It is tempting to believe <code>reservation_id</code> is simply an uppercase modification <code>booking_request_id</code>, but this will not be the case. For example, the approved booking request <code>s7v0f133</code> may spawn the reservation <code>D34DB33F</code>.
	- <code>reservation_status_id</code>: the reservation status ID referenceable via <code>ReservationStatus</code>.
	- <code>usage_note</code>: a small piece of text to provide more information in the space usage.
- When a space requires a maintenance session to repair a malfunctioning facility, a <code>Maintenance</code> entity is created, comprising the following properties:
	- <code>maintenance_id</code>: a lowercase 6 letters long alphanumeric ID identifying a maintenance session. Obviously, this is not enumerable.
	- <code>reporter_id</code>: the user ID of the occupant who notified the staff about a facility failure.
	- <code>maintenance_description</code>: the specific problem prompting maintenance. A possible cause could be <code>Broken air conditioner</code> in <code>C23</code>.
	- <code>maintenance_status_id</code>: the maintenance status ID referenceable via <code>MaintenanceStatus</code>.
	- <code>result_note</code>: a small piece of text describing the result of the maintenance. Using the above example, after the maintenance finishes, a note of the result may be <code>Accumulation of dust in air filter, which has been dealt with</code>.

We finally discuss associative entities&mdash;entities that model many-to-many relationships (although we will not use them for that purpose, but rather to model relationship attributes that allow to take full advantages of what reference entities offer). There is only one such entity:
- Once a request has been made, it pends the judgement from a privileged user (usually a facility staff). In other words, a user will review a request to determine whether it will be approved or rejected. Since this closely resembles a relationship but for reasons we will soon elaborate, it is thus appropriate to model the judgement process as a associative entity type <code>Review</code>.
	- The participating entity type <code>User</code> may choose to or not to review a request and thus has a cardinality of <code>(0, N)</code>. Conversely, one review can only be reviewed by one user and thus has a cardinality of <code>(1, 1)</code>.
	- The participating entity type <code>BookingRequest</code> must be reviewed by a staff (if it is to be approved or rejected) or not reviewed yet (if it is pending or cancelled). However, it is still entitied and thus bound to a review instance. Ergo, it has a cardinality range of <code>(1, 1)</code>. Conversely, one review can only be resulted from one request and thus has a cardinality range of <code>(1, 1)</code>.
	- This associative entity has attributes to accurately reflect the reviewing process:
		- <code>booking_request_id</code>: the booking request ID to which the review binds.
		- <code>reviewer_id</code>: the user ID of the reviewer that may be assigned to a review.
		- <code>decision_id</code>: the ID of the review decision referenceable via <code>Decision</code>.
		- <code>decision_time</code>: the timestamp when an approval/rejection has been made. Using the earlier example, a possible time when the decision was made could have been in <code>2026-6-19, 17:43:02</code>.
		- <code>decision_note</code>: a short clarification on the decision by the reviewer.
		- <code>rejection_reason</code>: the reason for why a rejection was handed to a request.

# Schema design &ndash; Relationships & cardinalities
This section will discuss how the above entities interact with each other and their cardinality constraints. There are two notations of interest to us: cardinality ratio&mdash;<code>M:N</code>&mdash;and participation constraint&mdash;<code>(M, N)</code>. We begin with trivial relationships that simply bridge entities to their appropriate lookup tables.
- The binary relationship <code>has_space_type</code> connects its two participating entity types <code>Space</code> and <code>SpaceType</code> which have cardinalities <code>(0, 1)</code> and <code>(0, N)</code>, respectively.
- The binary relationship <code>has_user_role</code> connects its two participating entity types <code>User</code> and <code>UserRole</code> which have cardinalities <code>(1, 1)</code> and <code>(0, N)</code>, respectively.
- The binary relationship <code>has_space_status</code> connects its two participating entity types <code>Space</code> and <code>SpaceStatus</code> which have cardinalities <code>(1, 1)</code> and <code>(0, N)</code>, respectively.
- The binary relationship <code>has_department</code> connects its two participating entity types <code>User</code> and <code>Department</code> which have cardinalities <code>(0, 1)</code> and <code>(0, N)</code>, respectively.
- The binary relationship <code>has_facility_type</code> connects its two participating entity types <code>Facility</code> and <code>FacilityType</code> which have cardinalities <code>(0, 1)</code> and <code>(0, N)</code>, respectively.
- The binary relationship <code>has_purpose</code> connects its two participating entity types <code>BookingRequest</code> and <code>Purpose</code> which have cardinalities <code>(0, 1)</code> and <code>(0, N)</code>, respectively.
- The binary relationship <code>has_decision</code> connects its two participating entity types <code>Review</code> and <code>Decision</code> which have cardinalities <code>(1, 1)</code> and <code>(0, N)</code>, respectively.
- The binary relationship <code>has_reservation_status</code> connects its two participating entity types <code>Reservation</code> and <code>ReservationStatus</code> which have cardinalities <code>(1, 1)</code> and <code>(0, N)</code>, respectively.

- A space can be equipped with facilities, indicating a binary <code>1:N</code> relationship <code>is_equipped_with</code>.
	- The participating entity type <code>Space</code> has cardinality <code>(0, N)</code> (**IT IS NOT KNOWN WHETHER A SPACE CAN HAVE NO FACILITIES**).
	- The participating entity type <code>Facility</code> has cardinality <code>(0, N)</code> (**IT IS NOT KNOWN WHETHER A FACILITY MUST BELONG TO A SPACE**)
	- This relationship has no atributes.
- A user can book a request to their desired space, indicating a ternary relationship <code>books</code>. Note that one user can choose to book any number of requests to one place. Thus, the relationship <code>books</code> has cardinality ratio <code>1:N:1</code> (one request points to precisely one determines the user-space pair).
	- The participating entity type <code>User</code> can freely choose to make a booking request or not and so corresponds to a cardinality range <code>(0, N)</code>.
	- The participating entity type <code>BookingRequest</code> must totally participate in the relationship to identify precisely one user-space pair and thus has cardinality range <code>(1, 1)</code>.
	- The participating entity type <code>Space</code> can be booked by anyone or noone and thus has the cardinality <code>(0, N)</code>.
	- This relationship has no attributes.
- Once a booking request is approved, it is promoted to a reservation, and we wish for this reservation to keep track of the request from which it was upgraded. The injective binary relationship <code>from_request</code> precisely reflects this goal.
	- The participating entity type <code>Reservation</code> totally participated in the relationship and thus has a cardinality range of <code>(1, 1)</code>.
	- The participating entity type <code>BookingRequest</code> does not always result in a reservation, in the case it is rejected, cancelled, or still pending review. Thus, it has cardinality <code>(0, 1)</code>.
	- This relationship has no attribute.
- When the scheduled time for a reservation has arrived, an attendant will monitor a reservation which is checked in by another user. It can be deduced that an appropriate model to reflect this fact is a ternary relationship <code>checks_in</code> whose cardinality ratio is <code>1:N:1</code> (one reservation points to precisely one user-attendant pair).
	- The participating entity type <code>User</code> has two roles: user and attendant, both having a cardinality range of <code>(0, N)</code>&mdash;a user can not check in, and an attendant can not monitor any check-in.
	- The participating entity type <code>Reservation</code> has a cardinality range of <code>(0, 1)</code>, as a reservation can only participate in check-ins if its status is not pending or no-show.
	- This relationship also has attributes relating to the check-in process:
		- <code>actual_time_slot</code>: the time period that denotes when the room starts and stops being occupied. As with <code>requested_time_slot</code>, this can be a composite attribute atomizing into <code>actual_start_time</code> and <code>actual_end_time</code>.
		- <code>space_condition</code>: the condition of the space. Because the room's condition may be altered after occupancy, it is a good idea to also make this a composite attribute comprising of two atomic attributes <code>space_initial_condition</code> and <code>space_final_condition</code>.
- Occasionally, a privilege user will perform a maintenance on a space, which is represented by a ternary relationship <code>maintains</code> with a cardinality ratio <code>1:N:1</code> (one user-space pair is identified by one maintenance).
	- The participating entity type <code>User</code> is a technician who is not necessarily required to perform at least one maintenance. Thus, it has a cardinality of <code>(0, N)</code>.
	- The participating entity type <code>Maintenance</code> of course must be present in one and precisely one participation and thus uniquely identifies a maintenance event. Hence, a cardinality of <code>(1, 1)</code>.
	- The participating entity type <code>Space</code>, as is the case with <code>User</code>, can be easily deduced to have a cardinality of <code>(0, N)</code>.
	- This relationship contains attributes as follows:
		- <code>maintenance_time_slot</code>: the time period in which the maintenance took place. Similar to other time slot attributes, it is also divided into two atomic attributes <code>maintenance_start_time</code> and <code>maintenance_end_time</code>. Because a maintenance is logged asynchronously, the end time may be null until the maintenance finishes.
- The maintenance could not have taken place without a user who noticed a problem with the facilities and prompted a maintenance. To model this behavior, a simple binary <code>1:N</code> relationship <code>reports_space</code> is in order.
	- The participating entity type <code>User</code> has a cardinality range of <code>(0, N)</code>, as one user can choose to reports any number of instances of space malfunctioning.
	- The paricipating entity type <code>Maintenance</code> must be resulted from one reporter in order for it to exist. In other words, the relationship requires a total participation from <code>Maintenance</code> and thus the entity type has cardinality <code>(1, 1)</code>.
	- This relationship has no attributes.

# Schema design - Constraints
Constraints are a set of rules that require our data to conform to. This section lists all such constraints. Note that our constraints should not be unnecessarily harsh, but we should still perform checks to ensure our data is clean and follows the outlined business reequirements. In general, there are three types of constraints: implicit constraints, explicit constraints, and semantic constraints. In this section, we delineate the latter two. Unlisted attributes and entities do not have external constraints. Naturally, there is some overlap between constraints and data definition.

Explicit constraints are constraints retaining to attributes and are often implemented in the data definition language to ensure data and referential integrity.

- The entity type <code>Space</code> contains the following explicit constraints:
	- <code>space_id</code> is unique and cannot be empty.
	- <code>building</code> cannot be empty.
	- <code>floor</code> cannot be empty.
	- <code>room_number</code> cannot be empty.
	- <code>capacity</code> cannot be empty.
	- <code>status</code> cannot be empty.
- The entity type <code>User</code> contains the following explicit constraints:
	- <code>user_id</code> is unique and cannot be empty.
	- <code>email</code> is unique.
	- <code>phone_number</code> is unique.
	- <code>role</code> cannot be empty.
	- <code>status</code> cannot be empty.
- The entity type <code>Facility</code> contains the following explicit constraints:
	- The pair (<code>facility_type_code</code>, <code>facility_sequence_number</code>) is unique.
	- <code>facility_type_code</code> cannot be empty.
	- <code>facility_sequence_number</code> cannot be empty.
	- <code>space_id</code> if exists must refer to an existing <code>Space</code> entity via its attribute <code>space_id</code>.
- The entity type <code>BookingRequest</code> contains the following explicit constraints:
	- <code>requested_start_time</code> cannot be empty.
	- <code>requested_end_time</code> cannot be empty and must be later than <code>requested_start_time</code>.
	- <code>expected_participants</code> cannot be empty.
- The entity type <code>Reservation</code> contains the following explicit constraints:
	- <code>booking_request_id</code> cannot be empty and must refer to an existing <code>BookingRequest</code> entity via its attribute <code>booking_request_id</code>.
	- <code>reservation_status</code> cannot be empty.
- The entity type <code>Maintenance</code> contains the following explicit constraints:
	- <code>reporter_id</code> if exists must refer to an existing <code>User</code> entity via tis attribute <code>user_id</code>.
	- <code>maintenance_status</code> cannot be empty.
	- <code>result_note</code> cannot exist if <code>maintenance_status</code> is not <code>completed</code>.
- The relationship <code>reviews</code> contains the following explicit constraints:
	- <code>decision</code> cannot be empty.
	- <code>decision_note</code> cannot exist if <code>decision_time</code> does not exist.
	- <code>rejection_reason</code> cannot exist if <code>decision</code> is not <code>rejected</code>.
- The relationship <code>checks_in</code> contains the following explicit constraints:
	- <code>actual_end_time</code> cannot exist if <code>actual_start_time</code> does not exist.
	- <code>actual_end_time</code> must be later than <code>actual_start_time</code>, if exists.
- The relationship <code>maintains</code> contains the following explicit constraints:
	- <code>maintenance_end_time</code> cannot exist if <code>maintenance_start_time</code> does not exist.
	- <code>maintenance_end_time</code> must be later than <code>maintenance_start_time</code>, if exists.

Semantic constraints are rules are delineated by the definitions of the entities themselves, business rules, or the developer design choices. As such, they are often difficult to express within the schema, requiring enforcement from the software application itself.
- The entity type <code>User</code> has the following semantic constraints:
	- <code>user_id</code> must be a precisely 8 letters long numeric string.
	- <code>email</code> must be a valid email, verifiable via RFC822 standard.
	- <code>phone_number</code> must be a valid phone number, verifiable via regex or external libraries to confirm the phone number.
- The entity type <code>BookingRequest</code> has the following semantic constraint:
	- <code>booking_request_id</code> must be a precisely 8 letters long lowercase alphanumeric string.
	- <code>expected_participants</code> must be less than or equal to the booked space's capacity.
- The entity type <code>Reservation</code> has the following semantic constraints:
	- <code>reservation_id</code> must be a precisely 8 letters long uppercase alphanumeric string.
- The entity type <code>Maintenance</code> has the following semantic constraints:
	- <code>maintenance_id</code> must be a precisely 6 letters long lowercase alphanumeric string.
- The relationship <code>checks_in</code> has the following semantic constraints:
	- <code>actual_start_time</code> cannot exist if the reservation's status is no-show.
	- <code>actual_end_time</code> cannot exist if the reservation's status is not completed.
	- **MORE INFORMATION REGARDING FINAL CONDITION IS REQUIRED**
- The relationship <code>maintains</code> has the following semantic constraints:
	- <code>maintenance_end_time</code> cannot exist if the maintenance status is not completed.

# Inquiries
This section is used to require additional inquiries from the instructors.
- What are the exact values the policies may take on for a space?
- Do users with non-academic roles belong to a specific department? If no, is it then safe to assume that a user need not belong to one department?
- What are the exact states a user account may be in?
- Is it necessary for one space to contain at least one facility?
- Is it necessary for one facility to belong to at least one space?
- Because booking request statuses such as checked in, completed, and no-show are already under the assumption that the request was approved, and it better reflects as a booked session status, are we allowed to instead move those statuses as part of the checking-in rather than of the request itself?
- What are the exact states a maintenance may be in?
- Are we allowed to devise the ID standards for entities to conform to (e.g., a booking request ID is an 8 letters long lowercase alphanumeric string)?
- Is it necessary for every booking request to have a purpose?