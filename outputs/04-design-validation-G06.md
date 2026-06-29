# Design validation
This section serves as a second iteration of the design, refining any detail that was unclear and/or inaccurate to the model. While we were designing, we pinpointed and recorded any vagueness in the given requirements to inquire our users. In addition, this section will also be dedicated to discuss extensively about the rows that the reference entities can contain. In other words, we shall discuss the domain of attributes that reference a reference entity.

# Conceptual refinement
The exact definition of department was unclear. It has been clarified by the users that a department is an academic department that dedicates itself to one specific major (e.g., IT, maths). As a consequence, this shows that not all of our users will belong to a specific department (facility staff, administrators). Thankfully, our original design correctly reflects this, however this gives rationale to our design.

The exact relationship between a space and facility was not acknowledged. More specifically, we were not sure whether a space must contain a facility, and a facility must belong to one space. It has been implied by the users that both participations are mandatory. Thus, **the cardinality of <code>Space</code> and <code>Facility</code> in the relationship <code>is_equipped_with</code> is now <code>(1, N)</code> and <code>(1, 1)</code>, respectively**.

Previously, we modeled the policy of a space as a simple paragraph. Upon further deliberation, we find it more appropriate to model it instead as its own entity. More specifically, we shall design an entity type <code>SpacePolicy</code> which the attribute <code>policy</code>&mdash;henceforth be renamed as <code>space_policy_id</code> will reference. The entity type consists of the following attribute:
- <code>policy_id</code>: the ID of the policy. We standardized the policy ID to be an alphabetic uppercase five characters long string, such as <code>SAHUR</code>.
- <code>booking_window_days</code>: the number of days ahead of the actual date in which one can request booking. For example, if the booking window is 14 days, all booking requests made earlier than 14 days until the requested time will automatically be guarded or invalidated.
- <code>min_duration_minutes</code>: the minimum duration in minutes that the room may be occupied.
- <code>max_duration_minutes</code>: the maximum duration in minutes that the room may be occupied.
- <code>check_in_grace_minutes</code>: the maximum amount of time in minutes the first person who checks in may be late.

This thus warrants a <code>1:N</code> relationship <code>follows_policy</code> where the cardinalities of the participating entities <code>Space</code> and <code>SpacePolicy</code> are <code>(1, 1)</code> and <code>(0, N)</code>, respectively.

Upon further inquiries with the users, we find it is more appropriate to promote some attributes such that they reference reference entities:
- Since the status of a user exhibit enum-like properties, it is more accurate to rename it as <code>user_status_id</code> of the entity type <code>User</code>. It also goes without saying that this attribute now references <code>UserStatus</code>.
- For the same reason, <code>space_initial_condition</code> and <code>space_final_condition</code> are repurposed and renamed as <code>space_initial_condition_id</code> and <code>space_final_condition_id</code>, referencing <code>SpaceCondition</code>.

Note that due to the space condition now behaves like an enum, the relationship <code>checks_in</code> is now forced to be promoted into an associative entity <code>ReservationCheckin</code> in order to participate in newfound relationships <code>has_initial_space_condition</code> and <code>has_final_space_condition</code>. Otherwise, the associative entity still pertains the delineated attributes. For each relationship, the participation of <code>ReservationCheckin</code> and <code>SpaceCondition</code> are both <code>(1, 1)</code> and <code>(0, N)</code>. As for the relationship <code>has_user_status</code>, it is relatively simple&mdash;<code>(1, 1)</code> and <code>(0, N)</code> for <code>User</code> and <code>UserStatus</code>, respectively.

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

<code>UserRole</code>:
<div align="center">

| **user_role_id** |      **user_role_code**     |    **user_role_name**    |
|------------------|:---------------------------:|:------------------------:|
| 1                |     <code>STUDENT</code>    |          Student         |
| 2                |    <code>LECTURER</code>    |         Lecturer         |
| 3                |       <code>TA</code>       |    Teaching Assistant    |
| 4                | <code>FACILITY_STAFF</code> |      Facility Staff      |
| 5                |   <code>DEPT_ADMIN</code>   | Department Administrator |
| 6                |  <code>FACILITY_MGR</code>  |     Facility Manager     |

</div>

<code>SpaceStatus</code>:
<div align="center">

| **space_status_id** |    **space_status_code**    | **space_status_name** |
|---------------------|:---------------------------:|:---------------------:|
| 1                   |    <code>AVAILABLE</code>   |       Available       |
| 2                   |     <code>IN_USE</code>     |        In use         |
| 3                   | <code>UNDER_MAINT</code>    |  Under maintenance    |
| 4                   | <code>TEMP_CLOSED</code>    |  Temporarily closed   |
| 5                   |    <code>RETIRED</code>     |        Retired        |

</div>

<code>Department</code>:
<div align="center">

| **department_id** |   **department_code**   |     **department_name**      |
|-------------------|:-----------------------:|:----------------------------:|
| 1                 |      <code>IT</code>    |    Information Technology    |
| 2                 |     <code>TCS</code>    | Theoretical Computer Science |
| 3                 |      <code>AI</code>    |   Artificial Intelligence    |
| 4                 |      <code>SE</code>    |     Software Engineering     |
| 5                 |    <code>CRYP</code>    |         Cryptography         |
| 6                 |      <code>IC</code>    |     Integrated Circuits      |

</div>

<code>FacilityType</code>:
<div align="center">

| **facility_type_id** | **facility_type_code** | **facility_type_name** |
|----------------------|:----------------------:|:----------------------:|
| 1                    |    <code>chr</code>    |         Chair          |
| 2                    |    <code>aic</code>    |    Air Conditioner     |
| 3                    |    <code>pro</code>    |       Projector        |
| 4                    |    <code>whb</code>    |       Whiteboard       |
| 5                    |    <code>dsk</code>    |          Desk          |

</div>

<code>Purpose</code>:
<div align="center">

| **purpose_id** |       **purpose_code**       |    **purpose_name**    |
|----------------|:----------------------------:|:----------------------:|
| 1              |      <code>LECTURE</code>    |         Lecture        |
| 2              |       <code>EXAM</code>      |      Examination       |
| 3              |     <code>SEMINAR</code>     |        Seminar         |
| 4              |    <code>WORKSHOP</code>     |        Workshop        |
| 5              |     <code>MEETING</code>     |        Meeting         |
| 6              | <code>STUDENT_ACTIVITY</code> |    Student activity    |
| 7              |   <code>ADMIN_EVENT</code>   | Administrative event   |

</div>

<code>Decision</code>:
<div align="center">

| **decision_id** |   **decision_code**    | **decision_name** |
|-----------------|:----------------------:|:-----------------:|
| 1               |   <code>PENDING</code> |      Pending      |
| 2               |  <code>APPROVED</code> |     Approved      |
| 3               |  <code>REJECTED</code> |     Rejected      |
| 4               | <code>CANCELLED</code> |    Cancelled      |

</div>

<code>ReservationStatus</code>:
<div align="center">

| **reservation_status_id** | **reservation_status_code** | **reservation_status_name** |
|---------------------------|:---------------------------:|:---------------------------:|
| 1                         |     <code>PENDING</code>    |           Pending           |
| 2                         |   <code>CHECKED_IN</code>   |         Checked in          |
| 3                         |   <code>COMPLETED</code>    |          Completed          |
| 4                         |    <code>NO_SHOW</code>     |           No-show           |

</div>

<code>MaintenanceStatus</code>:
<div align="center">

| **maintenance_status_id** | **maintenance_status_code** | **maintenance_status_name** |
|---------------------------|:---------------------------:|:---------------------------:|
| 1                         |    <code>ONGOING</code>     |           Ongoing           |
| 2                         |   <code>COMPLETED</code>    |          Completed          |

</div> 

<code>UserStatus</code>:
<div align="center">

| **user_status_id** | **user_status_code** | **user_status_name** |
|--------------------|:--------------------:|:--------------------:|
| 1                  | <code>ACTIVE</code>  |        Active        |
| 2                  | <code>INACTIVE</code>|       Inactive       |
| 3                  | <code>DISABLED</code>|       Disabled       |

</div>

<code>SpaceCondition</code>:
<div align="center">

| **space_condition_id** | **space_condition_code** | **space_condition_name** |
|------------------------|:------------------------:|:------------------------:|
| 1                      | <code>GOD_FORSAKEN</code>|       God-forsaken       |
| 2                      |      <code>BAD</code>    |           Bad            |
| 3                      |     <code>GOOD</code>    |           Good           |
| 4                      |    <code>GREAT</code>    |          Great           |
| 5                      |   <code>PERFECT</code>   |         Perfect          |

</div>

# Updated ER diagrams
Based on the new modifications, the new ER diagrams are presented below:
- Conceptual ERD:
![diagram](../assets/refined_conceptual.svg)

- Logical ERD:
![diagram](../assets/refined_logical.svg)