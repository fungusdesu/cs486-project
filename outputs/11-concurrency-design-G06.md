# Concurrency design
As of now, the database is working as intended and accurately models the miniworld. However, as the user base grows, arises also the vulnerabilities that were not as apparent for small-scaled operations. These primarily stem from the fact that the database is not yet designed to handle concurrent events appropriately. This section is dedicated for just that.

# Stored procedures
The first step is to first group common operations into stored procedures. To this end, we shall design the procedures by declaring its name, parameters, purpose, and rough implementation. Unless specified otherwise, all attributes are mandatory.

- The procedure to add a new user into the <code>User</code> table is called <code>AddUser</code>. Its parameters are <code>user_id</code>, <code>surname</code>, <code>given_name</code>, <code>email</code>, <code>phone_number</code>, <code>user_role_code</code>, and <code>department_code</code>. The parameter <code>department_code</code> is optional. Its implementation is given as follows:
    - Check if <code>user_role_code</code> points to a valid <code>UserRole</code> value, otherwise throw.
    - Check if <code>department_code</code> points to a valid <code>Department</code> value, otherwise throw.
    - Get the ID of the supplied <code>UserRole</code> and <code>Department</code>.
    - Get the ID of the <code>UserStatus</code> pointed to by <code>ACTIVE</code>.
    - Insert into <code>User</code> with the obtained parameters.
- The procedure to add a new space into the <code>Space</code> table is called <code>AddSpace</code>. Its parameters are <code>space_id</code>, <code>space_name</code>, <code>space_type_code</code>, <code>building</code>, <code>floor</code>, <code>room_number</code>, <code>capacity</code>, and <code>space_policy_id</code>. Its implementation is given as follows:
    - Check if <code>space_type_code</code> points to a valid <code>SpaceType</code> value, otherwise throw.
    - Get the ID of the supplied <code>SpaceType</code>.
    - Get the ID of the <code>SpaceStatus</code> pointed to by <code>AVAILABLE</code>.
    - Insert into <code>Space</code> with the obtained parameters.