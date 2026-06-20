# Business purpose
Manage the School of Computer Science physical spaces procedures, including booking requests and approvals, facility logging and maintenance, and space conditions management.

# Actors
- **Database Administrators (DBAs)**: Staff of the School in charge of authorizing access to the database, updating the database to its latest versions, and handle events like data breaches and system failures.
- **Database Designers**: Developers responsible for delineating the database structures and constraints for an appropriate representation of the relevant data, as well as an efficient data storage method.
- **Casual End Users**: Maintenance staff and space managers. These people occasionally access the database for a different purpose each time.
- **Naive End Users**: Space requesters, approvers, faculties staff, etc. access the database frequently through canned transactions provided to them via an interface&mdash;mobile apps, websites.
- **Sophisticated End Users**: Engineers and developers who are well familiar with database systems for complex integration development and benchmarking.

# Schema design
This section outlines the relevant entities with their attributes, how the entities relate to each other, their cardinalities, and constraints (business rules).
- The School will be organized into physical spaces to be booked <code>Space</code>. Its attributes are as follows:
	- <code>space_id</code>: a unique space ID. For clarity in space identification, each space will be assigned an ID that can span from 3 to 5 letters. For instance, auditorium 1 maybe labeled as <code>HT1</code>, and classroom 12b in building I will be labeled as <code>I12b</code>.
	- <code>space_name</code>: the name of the space. For instance, auditorium 1 may have the value <code>Auditorium 1</code>. Generally, different spaces should have unique names, but we decide to err on the side of caution and assume two different spaces may have the same name.
	- <code>space_type</code>: the type of the space, the space category in which multiple rooms may fit in. For instance, classroom I35 and classroom I34 may belong to the same <code>classroom</code> type. The values are deliberately chosen to be all lowercase for display convenience (e.g. to an interface).
	- <code>space_location</code>: the location of the building, identified by its room number, floor, and building in which it resides. It is thus appropriate to model the location as a composite attribute comprising of subattributes <code>building</code>, <code>floor</code>, and <code>room_number</code>. For instance, the classroom I34 located in <code>I34</code> may be broken down into atomic locations; i.e., building <code>I</code>, floor <code>3</code>, room <code>4</code>.
	- <code>capacity</code>: the maximum number of occupants the space can house. For example, auditorium 1 may contain a maximum of 80 people, thus its value is <code>80</code>.
	- <code>status</code>: the current condition of the space that may determine its availability. For instance, classroom C34 may be available for booking (<code>available</code>), whereas auditorium 1 may be temporarily unavailable due to broken air conditioners (<code>ander maintenance</code>). The values are in lowercase for the same reason as asserted in <code>space_type</code>.
	- <code>policy</code>: ...
- The School is comprised of students, staff, and maintenance personnels, which is identified on the system via their account. We may assume each user only holds precisely one account and thus can be modeled via a <code>User</code> entity type. Its attributes are as follows:
	- <code>user_id</code>: a unique user ID. To prevent malicious actors enumerating the database, we design this attribute under the assumption that the user ID is generated as an 8-digit numeric ID that was generated on user creation.
	- <code>full_name</code>: the full name of the user consisting of first name, middle name, and last name. It is sensible to represent this attribute as a composition of <code>surname</code>, and <code>given_name</code>. For example, the user whose <code>full_name</code> is <code>Nguyễn Quốc Nam</code> may be decomposed into <code>Nguyễn</code> for <code>surname</code> and <code>Quốc Nam</code> for <code>given_name</code>.
	- <code>email</code>: the email of the user. Two users may not be registered with the same email address, thus it is unique. For instance, the user <code>Trần Tôn Minh Kỳ</code> may have the email <code>minhkymikuuwu@gmail.com</code>.
	- <code>phone_number</code>: the contact phone number of the user. As is the case with email addresses, it is unique within an area identifier. For instance, the user <code>Trần Tôn Minh Kỳ</code> may have the number <code>0396769420</code>.
	- <code>role</code>: the position of the user within the School, including but not limited to <code>student</code>, <code>lecturer</code>, and <code>facility staff</code>.
	- <code>department</code>: the department in which a user belongs to. For instance, the user Quách Thiên Lạc may belong to <code>Information Technology</code> department.
	- <code>status</code>: the account status of the user.
- Each <code>Space</code> can possess an array of facilities, represented by the entity type <code>Facility</code>. These include teaching equipment such as boards, TVs, desks, chairs, .etc. Each facility will have two attributes:
	- <code>facility_id</code>: the ID of the facility. The ID is standardized to be at least 4 letters long, where the first three are alphabetical and describe the facility type, and the last part is numeric and describe the natural ordering&mdash;i.e., the sequential ID of the facility for its type. It is thus reasonable to construct <code>facility_id</code> as a composite attribute being comprised of <code>facility_type_code</code> and <code>facility_sequence_number</code>. For instance, a chair may have its type code denoted as <code>chr</code> and a sequence number of <code>55</code>, thus forming an ID of <code>chr55</code>.
	- <code>facility_name</code>: the name of the facility, such as <code>Air Conditioner</code> or <code>Board</code>.
- A user makes a request to book a space, thus forming a  <code>BookingRequest</code> entity. We choose to not include the requester and the requested space as attributes of a request and prefer to assign them to the properties more innate to the request itself. Otherwise, a <code>BookingRequest</code> contains the following attributes:
	- <code>booking_request_id</code>: a lowercase 8 letters long ID identifying a request. For the same reason as <code>user_id</code>, the ID is not enumerable.
	- <code>requested_time_slot</code>: the requested period of time to occupy the room. It stands to reason to split this into two more atomic attributes <code>requested_start_time</code> and <code>requested_end_time</code> denoting the particular timestamped endpoints. As an example, a user may book the room <code>I34</code> with a time slot of <code>2026-6-20, 13:00:00 -- 2026-6-20, 17:30:00</code>, the former and latter timestamps convey the start time and end time, respectively.
	- <code>purpose</code>: the purpose for which the room is used. For instance, the room <code>I34</code> may have been booked for <code>workshop</code> purpose.
	- <code>expected_participants</code>: the expected number of participants to occupy the room. Using the above example, the room <code>I34</code> may expect <code>30</code> people to attend the workshop.

# Inquiries
This section is used to require additional inquiries from the instructors.
- What are the exact values the policies may take on for a space?
- Do users with non-academic roles belong to a specific department? If no, is it then safe to assume that a user need not belong to one department?
- What are the exact states a user account may be in?