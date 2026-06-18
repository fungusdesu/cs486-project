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
- The School will be organized into physical spaces to be booked <code>Space</code>. Their attributes are as follows:
	- <code>space_id</code>: a unique space ID. For clarity in space identification, each space will be assigned an ID that can span from 3 to 5 letters. For instance, auditorium 1 maybe labeled as <code>HT1</code>, and classroom 12b in building I will be labeled as <code>I12b</code>.
	- <code>space_name</code>: the name of the space. For instance, auditorium 1 may have the value <code>Auditorium 1</code>. Generally, different spaces should have unique names, but we decide to err on the side of caution and assume two different spaces may have the same name.