# 6/24/26 Design Validation

## 1. Changes Made to Better Match `03-logical-design-G06.md`

### `User` Table

Changed attribute names to align with the logical design:

| Previous in `05` | Updated in `05` | Reason                                                         |
| ---------------- | --------------- | -------------------------------------------------------------- |
| `role_id`        | `user_role_id`  | Matches `03` attribute name                                    |
| `department`     | `department_id` | Matches `03` and changes from department name to department ID |

Updated related foreign key:

```sql
FOREIGN KEY (user_role_id) REFERENCES UserRole(role_id)
```

Added/kept department foreign key:

```sql
FOREIGN KEY (department_id) REFERENCES DepartmentName(department_id)
```

---

### `Space` Table

Changed several data types and attribute names to match `03` more closely:

| Attribute           | Previous in `05` |   Updated in `05` |             Matching `03` |
| ------------------- | ---------------: | ----------------: | ------------------------: |
| `space_id`          |     `VARCHAR(5)` |     `VARCHAR(10)` |             `VARCHAR(10)` |
| `space_name`        |   `NVARCHAR(50)` |    `NVARCHAR(30)` |            `NVARCHAR(30)` |
| `building`          |    `NVARCHAR(1)` |            `CHAR` |                    `CHAR` |
| `capacity`          |            `INT` |        `SMALLINT` |                `SMALLINT` |
| `current_status_id` |        `TINYINT` | `space_status_id` | `space_status_id TINYINT` |

Updated related foreign key:

```sql
FOREIGN KEY (space_status_id) REFERENCES SpaceStatus(status_id)
```

---

### `Facility` Table

Changed the facility type attribute:

| Previous in `05`                | Updated in `05`            | Reason                                      |
| ------------------------------- | -------------------------- | ------------------------------------------- |
| `facility_type_code VARCHAR(3)` | `facility_type_id TINYINT` | Matches `03`, which uses `facility_type_id` |

Updated generated `facility_id` expression to use `facility_type_id`.

Updated unique constraint:

```sql
UNIQUE (facility_type_id, facility_sequence_number)
```

---

### `BookingRequest` Table

Changed purpose from plain text to lookup ID:

| Previous in `05`        | Updated in `05`      | Matching `03`        |
| ----------------------- | -------------------- | -------------------- |
| `purpose NVARCHAR(500)` | `purpose_id TINYINT` | `purpose_id TINYINT` |

Added foreign key:

```sql
FOREIGN KEY (purpose_id) REFERENCES Purpose(purpose_id)
```

---

### `Reservation` Table

Changed ID types to better match `03`:

| Attribute            | Previous in `05` | Updated in `05` | Matching `03` |
| -------------------- | ---------------: | --------------: | ------------: |
| `reservation_id`     |    `NVARCHAR(8)` |    `VARCHAR(6)` |  `VARCHAR(6)` |
| `booking_request_id` |    `NVARCHAR(8)` |    `VARCHAR(8)` |  `VARCHAR(8)` |

---

### `Maintenance` Table

Renamed and resized the problem description attribute:

| Previous in `05`                    | Updated in `05`                                | Related `03` attribute                 |
| ----------------------------------- | ---------------------------------------------- | -------------------------------------- |
| `problem_description NVARCHAR(500)` | `maintenance_problem_description NVARCHAR(50)` | `maintenance_description NVARCHAR(50)` |

The user specifically requested the name:

```sql
maintenance_problem_description
```

---

### `Maintaining` Table

Changed two attribute types to better match `03`:

| Attribute        | Previous in `05` | Updated in `05` | Matching `03` |
| ---------------- | ---------------: | --------------: | ------------: |
| `maintenance_id` |     `VARCHAR(6)` |    `VARCHAR(8)` |  `VARCHAR(8)` |
| `space_id`       |     `VARCHAR(5)` |   `VARCHAR(10)` | `VARCHAR(10)` |

---

## 2. Lookup Table Code Column Additions

Added one code column to each lookup table so each row has a stable uppercase snake_case abbreviation/code.

The pattern follows the existing `Purpose` table:

```sql
purpose_code NVARCHAR(25) NOT NULL UNIQUE
```

---

### `UserRole`

Added:

```sql
role_code NVARCHAR(30) NOT NULL UNIQUE
```

Updated insert values:

```sql
("STUDENT", "student")
("LECTURER", "lecturer")
("TEACHING_ASSISTANT", "teaching assistant")
("FACILITY_STAFF", "facility staff")
("DEPARTMENT_ADMINISTRATOR", "department administrator")
("FACILITY_MANAGER", "facility manager")
```

---

### `UserAccountStatus`

Added:

```sql
status_code NVARCHAR(30) NOT NULL UNIQUE
```

Updated insert values:

```sql
("PENDING_APPROVAL", "pending approval")
("ACTIVE", "active")
("SUSPENDED", "suspended")
("DISABLED", "disabled")
```

---

### `DepartmentName`

Added:

```sql
department_code NVARCHAR(10) NOT NULL UNIQUE
```

Updated insert values:

```sql
('MCS', 'Faculty of Mathematics and Computer Science')
('IT', 'Faculty of Information Technology')
('PEP', 'Faculty of Physics and Engineering Physics')
('EET', 'Faculty of Electronics and Telecommunications')
('CHEM', 'Faculty of Chemistry')
('BIO', 'Faculty of Biology and Biotechnology')
('GEO', 'Faculty of Geology')
('ENV', 'Faculty of Environment')
('MST', 'Faculty of Materials Science and Technology')
('IDS', 'Faculty of Interdisciplinary Sciences')
```

---

### `SpaceStatus`

Added:

```sql
status_code NVARCHAR(30) NOT NULL UNIQUE
```

Updated insert values:

```sql
("AVAILABLE", "available")
("IN_USE", "in use")
("UNDER_MAINTENANCE", "under maintenance")
("CLOSED", "closed")
("RETIRED", "retired")
```

---

### `SpaceType`

Added:

```sql
type_code NVARCHAR(30) NOT NULL UNIQUE
```

Updated insert values:

```sql
("CLASSROOM", "classroom")
("MEETING_ROOM", "meeting room")
("LABORATORY", "laboratory")
("LECTURE_HALL", "lecture hall")
("OTHER", "other")
```

---

### `ReservationStatus`

Added:

```sql
status_code NVARCHAR(30) NOT NULL UNIQUE
```

Updated insert values:

```sql
("PENDING", "pending")
("APPROVED", "approved")
("REJECTED", "rejected")
("CANCELLED", "cancelled")
("OTHER", "other")
```

---

### `DecisionStatus`

Added:

```sql
status_code NVARCHAR(30) NOT NULL UNIQUE
```

Updated insert values:

```sql
("ACCEPTED", "accepted")
("REJECTED", "rejected")
("CANCELLED", "cancelled")
```

---

### `MaintenanceStatus`

Added:

```sql
status_code NVARCHAR(30) NOT NULL UNIQUE
```

Updated insert values:

```sql
("PENDING", "pending")
("IN_PROGRESS", "in progress")
("COMPLETED", "completed")
("CANCELLED", "cancelled")
("OTHER", "other")
```

---

## 3. Constraints Added for Code Columns

For each new code column, an uppercase check constraint was added.

Example:

```sql
CONSTRAINT chk_space_status_code_uppercase
    CHECK (status_code COLLATE Latin1_General_BIN = UPPER(status_code) COLLATE Latin1_General_BIN)
```

This ensures code values stay uppercase, such as:

```sql
IN_PROGRESS
UNDER_MAINTENANCE
FACILITY_MANAGER
```

## **Remaining mismatches **


These are the mismatches still left between `03-logical-design-G06.md` and the current `05-db-definition-G06(2).sql`.

**Main Tables**

| Table            | In `03`                                | Current in `05`                                | Mismatch                                      |
| ---------------- | -------------------------------------- | ---------------------------------------------- | --------------------------------------------- |
| `Space`          | `policy NVARCHAR(200)`                 | `usage_policy NVARCHAR(500)`                   | name + length mismatch                        |
| `User`           | `surname NVARCHAR(30)`                 | `surname NVARCHAR(100)`                        | length mismatch                               |
| `User`           | `email NVARCHAR(255)`                  | `email VARCHAR(100)`                           | type + length mismatch                        |
| `User`           | `status VARCHAR(10)`                   | `account_status_id TINYINT`                    | name + type mismatch                          |
| `Facility`       | `facility_name NVARCHAR(30)`           | `facility_name NVARCHAR(50)`                   | length mismatch                               |
| `Facility`       | `space_id VARCHAR(10)`                 | `space_id VARCHAR(5)`                          | length mismatch                               |
| `BookingRequest` | `booking_request_id VARCHAR(8)`        | `booking_request_id NVARCHAR(8)`               | type mismatch                                 |
| `BookingRequest` | `expected_participants SMALLINT`       | `expected_participants INT`                    | type mismatch                                 |
| `Reservation`    | `reservation_status_id TINYINT`        | `resevation_status_id TINYINT`                 | typo in column name                           |
| `Reservation`    | `usage_note NVARCHAR(50)`              | `usage_note NVARCHAR(100)`                     | length mismatch                               |
| `Maintenance`    | `maintenance_description NVARCHAR(50)` | `maintenance_problem_description NVARCHAR(50)` | name mismatch, though you requested this name |
| `Maintenance`    | `maintenance_status_id TINYINT`        | `maintenance_status TINYINT`                   | name mismatch                                 |
| `Maintenance`    | `result_note NVARCHAR(50)`             | `result_note NVARCHAR(500)`                    | length mismatch                               |

**Relationship Tables**

| Table in `03`                                            | Current in `05`                                   | Mismatch                                                                                                                                          |
| -------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Booking`                                                | missing                                           | `03` has a separate `Booking` table with `booking_request_id`, `user_id`, `space_id`; `05` folds `booker_id` and `space_id` into `BookingRequest` |
| `Review`                                                 | `BookingDecision`                                 | table name mismatch                                                                                                                               |
| `Review.reviewer_id VARCHAR(8)`                          | `BookingDecision.decision_maker_id VARCHAR(8)`    | column name mismatch                                                                                                                              |
| `Review.decision_id TINYINT`                             | `BookingDecision.decision_status_id TINYINT`      | column name mismatch                                                                                                                              |
| `Review.decision_note NVARCHAR(50)`                      | `BookingDecision.decision_note NVARCHAR(500)`     | length mismatch                                                                                                                                   |
| `Review.rejection_reason NVARCHAR(50)`                   | `BookingDecision.rejection_reason NVARCHAR(500)`  | length mismatch                                                                                                                                   |
| `ReservationCheckIn.space_initial_condition VARCHAR(10)` | `space_initial_condition_id TINYINT`              | name + type mismatch                                                                                                                              |
| `ReservationCheckIn.space_final_condition VARCHAR(10)`   | `space_final_condition_id TINYINT`                | name + type mismatch                                                                                                                              |
| `ReservationCheckIn`                                     | has extra `check_in_status NVARCHAR(20)`          | extra column not in `03`                                                                                                                          |
| `ReservationCheckIn`                                     | has extra `usage_note NVARCHAR(500)`              | extra column not in `03`                                                                                                                          |
| `Maintaining`                                            | has extra `maintenance_time_slot` computed column | extra column not in `03`                                                                                                                          |

**Lookup Tables**

| Logical table in `03` | Current table in `05` | Mismatch                                                |
| --------------------- | --------------------- | ------------------------------------------------------- |
| `Department`          | `DepartmentName`      | table name mismatch                                     |
| `FacilityType`        | missing               | table missing in `05`                                   |
| `Decision`            | `DecisionStatus`      | table name mismatch                                     |
| `UserAccountStatus`   | extra table           | not in `03`; `03` has `User.status VARCHAR(10)` instead |

**Lookup Column Names / Types**

| Table               | In `03`                                         | Current in `05`                                          | Mismatch                      |
| ------------------- | ----------------------------------------------- | -------------------------------------------------------- | ----------------------------- |
| `UserRole`          | `user_role_id`                                  | `role_id`                                                | name mismatch                 |
| `UserRole`          | `user_role_code VARCHAR(20)`                    | `role_code NVARCHAR(30)`                                 | name + type + length mismatch |
| `UserRole`          | `user_role_name VARCHAR(50)`                    | `role_name NVARCHAR(30)`                                 | name + type + length mismatch |
| `SpaceStatus`       | `space_status_id`                               | `status_id`                                              | name mismatch                 |
| `SpaceStatus`       | `space_status_code VARCHAR(20)`                 | `status_code NVARCHAR(30)`                               | name + type + length mismatch |
| `SpaceStatus`       | `space_status_name VARCHAR(50)`                 | `status_name NVARCHAR(20)`                               | name + type + length mismatch |
| `SpaceType`         | `space_type_id`                                 | `type_id`                                                | name mismatch                 |
| `SpaceType`         | `space_type_code VARCHAR(20)`                   | `type_code NVARCHAR(30)`                                 | name + type + length mismatch |
| `SpaceType`         | `space_type_name VARCHAR(50)`                   | `type_name NVARCHAR(20)`                                 | name + type + length mismatch |
| `ReservationStatus` | `reservation_status_id`                         | `status_id`                                              | name mismatch                 |
| `ReservationStatus` | `reservation_status_code VARCHAR(20)`           | `status_code NVARCHAR(30)`                               | name + type + length mismatch |
| `ReservationStatus` | `reservation_status_name VARCHAR(50)`           | `status_name NVARCHAR(20)`                               | name + type + length mismatch |
| `Purpose`           | `purpose_code VARCHAR(20)`                      | `purpose_code NVARCHAR(25)`                              | type + length mismatch        |
| `Decision`          | `decision_id`, `decision_code`, `decision_name` | `DecisionStatus.status_id`, `status_code`, `status_name` | table + column name mismatch  |
| `MaintenanceStatus` | `maintenance_status_id`                         | `status_id`                                              | name mismatch                 |
| `MaintenanceStatus` | `maintenance_status_code VARCHAR(20)`           | `status_code NVARCHAR(30)`                               | name + type + length mismatch |
| `MaintenanceStatus` | `maintenance_status_name VARCHAR(50)`           | `status_name NVARCHAR(20)`                               | name + type + length mismatch |

**Extra Columns in `05` Not Present in `03`**

| Table                | Extra column                            |
| -------------------- | --------------------------------------- |
| `User`               | `full_name` computed column             |
| `Space`              | `space_location` computed column        |
| `Facility`           | `facility_id` computed column           |
| `BookingRequest`     | `booker_id`                             |
| `BookingRequest`     | `space_id`                              |
| `BookingRequest`     | `requested_time_slot` computed column   |
| `ReservationCheckIn` | `check_in_status`                       |
| `ReservationCheckIn` | `actual_time_slot` computed column      |
| `ReservationCheckIn` | `usage_note`                            |
| `Maintaining`        | `maintenance_time_slot` computed column |


