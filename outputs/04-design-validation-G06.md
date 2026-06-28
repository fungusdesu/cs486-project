# Design validation
This section serves as a second iteration of the design, refining any detail that was unclear and/or inaccurate to the model. While we were designing, we pinpointed and recorded any vagueness in the given requirements to inquire our users. In addition, this section will also be dedicated to discuss extensively about the rows that the reference entities can contain. In other words, we shall discuss the domain of attributes that reference a reference entity. The exact standards for our entities IDs are also delineated.

# Conceptual refinement
The exact definition of department was unclear. It has been clarified by the users that a department is an academic department that dedicates itself to one specific major (e.g., IT, maths). As a consequence, this shows that not all of our users will belong to a specific department (facility staff, administrators). Thankfully, our original design correctly reflects this, however this gives rationale to our design.

The exact relationship between a space and facility was not acknowledged. More specifically, we were not sure whether a space must contain a facility, and a facility must belong to one space. It has been implied by the users that both participations are mandatory. Thus, **the cardinality of <code>Space</code> and <code>Facility</code> in the relationship <code>is_equipped_with</code> is now <code>(1, N)</code> and <code>(1, 1)</code>, respectively**.

Upon further inquiries with the users, we find it is more appropriate to promote some attributes such that they reference reference entities:
- Since the status of a user exhibit enum-like properties, it is more accurate to rename it as <code>user_status_id</code> of the entity type <code>User</code>. It also goes without saying that this attribute now references <code>UserStatus</code>.
- For the same reason, <code>space_initial_condition</code> and <code>space_final_condition</code> are repurposed and renamed as <code>space_initial_condition_id</code> and <code>space_final_condition_id</code>, referencing <code>SpaceCondition</code>.
The exact details of these new reference entities will soon be discussed.

# Reference entities domain
Below outlines the possible entities of reference entity types.

<code>SpaceType</code>:
<div align="center">

| **space_type_id** |    **space_type_code**    | **space_type_name** |
|-------------------|:-------------------------:|:-------------------:|
| 1                 |  <code>AUDITORIUM</code>  |      Auditorium     |
| 2                 |   <code>CLASSROOM</code>  |      Classroom      |
| 3                 | <code>LECTURE_HALL</code> |     Lecture Hall    |
| 4                 | <code>MEETING_ROOM</code> |     Meeting Room    |
| 5                 |     <code>STUDY</code>    |        Study        |
| 6                 | <code>LIBRARY_ROOM</code> |     Library Room    |
| 7                 |   <code>STAFFROOM</code>  |      Staffroom      |
| 8                 |      <code>LAB</code>     |      Laboratory     |

</div>