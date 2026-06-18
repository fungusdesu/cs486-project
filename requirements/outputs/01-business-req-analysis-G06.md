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
- The School is comprised of students, staff, and maintenance personnels, which is identified on the system via their account. We may assume each user only holds precisely one account and thus can be modeled via a <code>User</code> entity. Its attributes are as follows:
	- <code>user_id</code>: a unique user ID. To prevent malicious actors enumerating the database, we design this attribute under the assumption that the user ID is generated as an 8-digit numeric ID that was generated on user creation.

# Inquiries
This section is used to require additional inquiries from the instructors. User inquiries are needed regarding:
- Exact value of the attribute <code>policy</code>.