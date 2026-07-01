INSERT INTO SpacePolicy (
    space_policy_id,
    booking_window_days,
    min_duration_minutes,
    max_duration_minutes,
    check_in_grace_minutes
)
VALUES
    ('DYWGI', 7, 10, 300, 5),
    ('HKBSL', 3, 10, 120, 10),
    ('NCYTN', 7, 10, 300, 10),
    ('QFJJO', 2, 10, 180, 5),
    ('CDQNA', 3, 10, 250, 5),
    ('QRSCP', 7, 10, 150, 3),
    ('FXADX', 3, 10, 360, 3),
    ('LRYBE', 3, 10, 360, 5),
    ('CXWSK', 3, 10, 300, 10),
    ('DTEHH', 3, 10, 120, 10);
GO

INSERT INTO Space (
    space_id,
    space_name,
    space_type_id,
    building,
    floor,
    room_number,
    capacity,
    space_status_id,
    space_policy_id
)
VALUES
    ('AU1', 'Auditorium 1', 1, 'I', 1, 1, 120, NULL, 'DYWGI'),
    ('AU2', 'Auditorium 2', 1, 'B', 1, 1, 150, NULL, 'DYWGI'),
    ('AU3', 'Auditorium 3', 1, 'C', 1, 1, 120, NULL, 'DYWGI'),
    ('LH1', 'Lecture Hall 1', 3, 'I', 1, 2, 150, NULL, 'NCYTN'),
    ('LH2', 'Lecture Hall 2', 3, 'B', 1, 2, 150, NULL, 'NCYTN'),
    ('LH3', 'Lecture Hall 3', 3, 'C', 1, 2, 150, NULL, 'NCYTN'),
    ('I21', 'Classroom I21', 2, 'I', 2, 1, 50, NULL, 'HKBSL'),
    ('I22', 'Classroom I22', 2, 'I', 2, 2, 50, NULL, 'HKBSL'),
    ('I23', 'Classroom I23', 2, 'I', 2, 3, 50, NULL, 'HKBSL'),
    ('I31', 'Classroom I31', 2, 'I', 3, 1, 50, NULL, 'HKBSL'),
    ('I32', 'Classroom I32', 2, 'I', 3, 2, 50, NULL, 'HKBSL'),
    ('I33', 'Classroom I33', 2, 'I', 3, 3, 50, NULL, 'HKBSL'),
    ('A21', 'Classroom A21', 2, 'A', 2, 1, 55, NULL, 'HKBSL'),
    ('A22', 'Classroom A22', 2, 'A', 2, 2, 55, NULL, 'HKBSL'),
    ('A23', 'Classroom A23', 2, 'A', 2, 3, 55, NULL, 'HKBSL'),
    ('A31', 'Classroom A31', 2, 'A', 3, 1, 55, NULL, 'HKBSL'),
    ('A32', 'Classroom A32', 2, 'A', 3, 2, 55, NULL, 'HKBSL'),
    ('A33', 'Classroom A33', 2, 'A', 3, 3, 55, NULL, 'HKBSL'),
    ('B21', 'Classroom B21', 2, 'B', 2, 1, 60, NULL, 'HKBSL'),
    ('B22', 'Classroom B22', 2, 'B', 2, 2, 60, NULL, 'HKBSL'),
    ('B23', 'Classroom B23', 2, 'B', 2, 3, 60, NULL, 'HKBSL'),
    ('B31', 'Classroom B31', 2, 'B', 3, 1, 60, NULL, 'HKBSL'),
    ('B32', 'Classroom B32', 2, 'B', 3, 2, 60, NULL, 'HKBSL'),
    ('B33', 'Classroom B33', 2, 'B', 3, 3, 60, NULL, 'HKBSL'),
    ('MR201', 'Meeting Room 1', 4, 'C', 2, 1, 10, NULL, 'QFJJO'),
    ('MR202', 'Meeting Room 2', 4, 'C', 2, 2, 15, NULL, 'QFJJO'),
    ('MR203', 'Meeting Room 3', 4, 'C', 2, 3, 20, NULL, 'QFJJO'),
    ('S1', 'Study I', 5, 'I', 4, 1, 1, NULL, 'CDQNA'),
    ('S2', 'Study A', 5, 'A', 4, 1, 2, NULL, 'CDQNA'),
    ('S3', 'Study B', 5, 'B', 4, 1, 2, NULL, 'CDQNA'),
    ('LR1', 'Library Room 1', 6, 'C', 3, 1, 10, NULL, 'QRSCP'),
    ('LR2', 'Library Room 2', 6, 'C', 3, 2, 10, NULL, 'QRSCP'),
    ('SR1', 'IT & TCS Staffroom', 7, 'C', 4, 1, 50, NULL, 'FXADX'),
    ('SR2', 'AI & SE Staffroom', 7, 'C', 4, 2, 50, NULL, 'FXADX'),
    ('SR3', 'CRYP & IC Staffroom', 7, 'C', 4, 3, 50, NULL, 'FXADX'),
    ('SR4', 'Staffroom I', 7, 'I', 4, 2, 20, NULL, 'LRYBE'),
    ('SR5', 'Staffroom A', 7, 'A', 4, 2, 20, NULL, 'LRYBE'),
    ('SR6', 'Staffroom B', 7, 'B', 4, 2, 20, NULL, 'LRYBE'),
    ('LAB1', 'Laboratory I', 8, 'I', 4, 3, 80, NULL, 'CXWSK'),
    ('LAB2', 'Laboratory A', 8, 'A', 4, 3, 50, NULL, 'DTEHH'),
    ('LAB3', 'Laboratory B', 8, 'B', 4, 3, 50, NULL, 'DTEHH');
GO

INSERT INTO [User] (
    user_id,
    surname,
    given_name,
    email,
    phone_number,
    user_role_id,
    department_id,
    user_status_id
)
VALUES
    ('94934230', N'Trần Tôn Minh', N'Kỳ', 'minhkyuwu@gmail.com', '0371633575', 5, NULL, 1),
    ('60847655', N'Quách Thiên', N'Lạc', 'makarov@gmail.com', '0224910990', 6, NULL, 1),
    ('02377047', N'Nguyễn Quốc', 'Nam', 'quocnam612@gmail.com', '0477070069', 2, 1, 1),
    ('28721710', N'Phan Bảo Đức', N'Phát', 'phatpvc@gmail.com', '0532087431', 2, 3, 1),
    ('76303408', N'Nguyễn Chánh', N'Nhân', 'oprisus@gmail.com', '0611430362', 2, 5, 1),
    ('08442878', N'Phan Trần Việt', 'Trung', 'yoruka@gmail.com', '0575588724', 3, 1, 1),
    ('00306823', N'Trần Thanh', N'Hải', 'sliver20503@gmail.com', '0113971141', 3, 5, 1),
    ('05118511', N'Huỳnh Lăng Minh', N'Trị', 'meiji@gmail.com', '0861506616', 3, 2, 1),
    ('87883568', N'Phan Bảo', N'Trọng', 'jangbellwemeantate@gmail.com', '0210886625', 1, 1, 1),
    ('36920217', N'Tôn Thất Nhật', N'Khánh', 'tonhoasen@gmail.com', '0303794447', 1, 1, 1),
    ('23860563', N'Nguyễn Bá', 'Vinh', 'nbvinh@gmail.com', '0741278119', 1, 2, 3),
    ('95177409', N'Nguyễn Hoàng', 'Gia', 'giabell@gmail.com', '0722647706', 1, 2, 1),
    ('29754516', N'Nguyễn Đình Thiên', N'Lộc', 'locgay@gmail.com', '0556491769', 1, 3, 1),
    ('32025141', N'Nguyễn Hồng Tấn', N'Tài', 'tuongtainhungko@gmail.com', '0018434867', 1, 3, 1),
    ('02168701', N'Lê Trung', N'Kiên', 'chokien@gmail.com', '0284205948', 1, 4, 1),
    ('80658968', N'Cao Hồng', N'Vân', 'vana1@gmail.com', '0300927878', 1, 5, 2),
    ('14098089', N'Phan Thị Thanh', N'Huyền', 'mayo212@gmail.com', '0630638150', 1, 6, 1),
    ('29069097', N'Nguyễn Văn', N'Tĩnh', 'nguydien@gmail.com', '0600824687', 4, NULL, 1),
    ('97964809', 'Hatsune', 'Miku', 'omgitmigu@gmail.com', '0117319712', 4, NULL, 1),
    ('46967007', N'Hồ Nguyễn Như', N'Khuyên', 'oitroioilatroi@gmail.com', '0184207295', 4, NULL, 1);
GO

INSERT INTO BookingRequest (
    booking_request_id,
    requested_start_time,
    requested_end_time,
    purpose_id,
    expected_participants
)
VALUES
    ('8hqpp7hu', '2026-06-20T07:30:00', '2026-06-20T11:15:00', 1, 40),
    ('u8qd9snm', '2026-06-20T07:30:00', '2026-06-20T09:15:00', 1, 40),
    ('tiaeue8i', '2026-06-20T09:30:00', '2026-06-20T11:15:00', 3, 40),
    ('20pt040a', '2026-06-20T08:00:00', '2026-06-20T09:30:00', 5, 10),
    ('mqmyjyci', '2026-06-20T09:00:00', '2026-06-20T10:30:00', 5, 8),
    ('yfzoyucf', '2026-06-21T15:00:00', '2026-06-21T16:00:00', 6, 1),
    ('y55nadhp', '2026-06-20T06:00:00', '2026-06-20T11:30:00', 7, 30),
    ('p8onog2q', '2026-06-20T06:00:00', '2026-06-20T11:30:00', 7, 30),
    ('406om3hs', '2026-06-20T06:00:00', '2026-06-20T11:30:00', 7, 15),
    ('q2dxltov', '2026-06-20T06:00:00', '2026-06-20T11:30:00', 7, 10),
    ('pif0j8u8', '2026-06-20T06:00:00', '2026-06-20T11:30:00', 7, 10),
    ('5bo3fynf', '2026-06-22T13:00:00', '2026-06-22T15:00:00', 2, 40),
    ('tr367wjq', '2026-06-20T07:00:00', '2026-06-20T10:00:00', 4, 100),
    ('6mxpqjt1', '2026-06-20T07:00:00', '2026-06-20T10:00:00', 4, 100),
    ('eqo3d53s', '2026-06-20T13:00:00', '2026-06-20T15:00:00', 5, 3);
GO

INSERT INTO Booking (
    booking_request_id,
    user_id,
    space_id
)
VALUES
    ('8hqpp7hu', '02377047', 'I22'),
    ('u8qd9snm', '28721710', 'A33'),
    ('tiaeue8i', '05118511', 'B21'),
    ('20pt040a', '95177409', 'MR201'),
    ('mqmyjyci', '80658968', 'MR201'),
    ('yfzoyucf', '36920217', 'S2'),
    ('y55nadhp', '94934230', 'SR1'),
    ('p8onog2q', '94934230', 'SR2'),
    ('406om3hs', '94934230', 'SR4'),
    ('q2dxltov', '94934230', 'SR5'),
    ('pif0j8u8', '94934230', 'SR6'),
    ('5bo3fynf', '05118511', 'LAB1'),
    ('tr367wjq', '08442878', 'AU3'),
    ('6mxpqjt1', '08442878', 'AU2'),
    ('eqo3d53s', '00306823', 'LR1');
GO


INSERT INTO Review (
    booking_request_id,
    reviewer_id,
    decision_id,
    decision_time,
    decision_note,
    rejection_reason
)
VALUES
    ('8hqpp7hu', '60847655', 3, '2026-06-19T16:07:18', 'Week 3 Scheduled Teaching', 'Maintenance'),
    ('u8qd9snm', '97964809', 2, '2026-06-19T16:13:44', 'Week 3 Scheduled Teaching', NULL),
    ('tiaeue8i', '60847655', 2, '2026-06-19T16:21:05', 'Scheduled Seminar', NULL),
    ('20pt040a', '29069097', 2, '2026-06-19T16:26:32', NULL, NULL),
    ('mqmyjyci', '60847655', 3, '2026-06-19T16:34:29', NULL, 'Requested time unavailable'),
    ('yfzoyucf', '60847655', 2, '2026-06-19T16:39:45', NULL, NULL),
    ('y55nadhp', '60847655', 2, '2026-06-19T16:45:12', 'Automated staffroom booking', NULL),
    ('p8onog2q', '46967007', 2, '2026-06-19T16:48:37', 'Automated staffroom booking', NULL),
    ('406om3hs', '60847655', 2, '2026-06-19T16:55:03', 'Automated staffroom booking', NULL),
    ('q2dxltov', '46967007', 2, '2026-06-19T17:01:41', 'Automated staffroom booking', NULL),
    ('pif0j8u8', '97964809', 2, '2026-06-19T17:06:14', 'Automated staffroom booking', NULL),
    ('5bo3fynf', '60847655', 2, '2026-06-19T17:10:26', 'Week 3 Scheduled Examination', NULL),
    ('tr367wjq', '60847655', 4, '2026-06-19T17:17:58', 'Workshop', NULL),
    ('6mxpqjt1', '60847655', 2, '2026-06-19T17:22:31', 'Workshop', NULL),
    ('eqo3d53s', '60847655', 2, '2026-06-19T17:29:33', NULL, NULL);
GO
INSERT INTO Reservation (
    reservation_id,
    booking_request_id,
    reservation_status_id,
    usage_note
)
VALUES
    ('T6SJ702F', 'u8qd9snm', 3, 'CS486 Lecture 03'),
    ('FM1CA4XH', 'tiaeue8i', 3, 'Seminar on modular representation theory'),
    ('4RJ2R879', '20pt040a', 4, 'No-show meeting, user blacklisted'),
    ('TOQDPKV8', 'yfzoyucf', 1, NULL),
    ('70538BYA', 'y55nadhp', 3, 'Daily staffroom'),
    ('GNF5K5O7', 'p8onog2q', 3, 'Daily staffroom'),
    ('2WCV8QIU', '406om3hs', 3, 'Daily staffroom'),
    ('01F87FW3', 'q2dxltov', 3, 'Daily staffroom'),
    ('CV4IPGH4', 'pif0j8u8', 3, 'Daily staffroom'),
    ('JKQMHM3K', '5bo3fynf', 1, NULL),
    ('CTYMLKD6', '6mxpqjt1', 3, 'Workshop on CV writing'),
    ('4BDHPZNC', 'eqo3d53s', 2, NULL);
GO

INSERT INTO ReservationCheckIn (
    reservation_id,
    attendant_id,
    checked_in_user_id,
    actual_start_time,
    actual_end_time,
    space_initial_condition_id,
    space_final_condition_id
)
VALUES
    ('T6SJ702F', '29069097', '23860563', '2026-06-20T07:32:00', '2026-06-20T09:11:00', 4, 3),
    ('FM1CA4XH', '29069097', '29069097', '2026-06-20T09:35:00', '2026-06-20T11:10:00', 3, 5),
    ('TOQDPKV8', '97964809', '36920217', '2026-06-21T15:01:00', '2026-06-20T16:21:00', 5, 2),
    ('70538BYA', '97964809', '94934230', '2026-06-20T06:17:00', '2026-06-20T11:12:00', 4, 2),
    ('GNF5K5O7', '97964809', '94934230', '2026-06-20T06:02:00', '2026-06-20T11:29:00', 5, 3),
    ('2WCV8QIU', '97964809', '94934230', '2026-06-20T06:10:00', '2026-06-20T11:06:00', 4, 4),
    ('01F87FW3', '46967007', '94934230', '2026-06-20T06:08:00', '2026-06-20T11:27:00', 4, 5),
    ('CV4IPGH4', '46967007', '94934230', '2026-06-20T06:09:00', '2026-06-20T09:54:00', 3, 2),
    ('CTYMLKD6', '97964809', '97964809', '2026-06-20T06:55:00', '2026-06-20T10:24:00', 5, 4),
    ('4BDHPZNC', '97964809', '00306823', '2026-06-20T12:58:00', '2026-06-20T15:00:00', 4, 4);
GO

INSERT INTO Maintenance (
    maintenance_id,
    reporter_id,
    maintenance_description,
    maintenance_status_id,
    result_note
)
VALUES
    ('12as51', '02377047', 'Broken chairs on first row', 2, 'Replaced with new chairs'),
    ('qi19r9', '76303408', 'Board missing', 1, NULL),
    ('a7m2q9', '94934230', 'Projector remote not working', 1, NULL),
    ('x0f4h7', '36920217', 'Power outlet cover cracked', 1, NULL),
    ('z3w8e5', '23860563', 'Door handle feels loose', 1, NULL);
GO

INSERT INTO Maintaining (
    maintenance_id,
    technician_id,
    space_id,
    maintenance_start_time,
    maintenance_end_time
)
VALUES
    ('12as51', '60847655', 'AU1', '2026-06-18T17:00:00', '2026-06-18T17:30:00'),
    ('qi19r9', '60847655', 'MR203', '2026-06-19T02:00:00', NULL),
    ('a7m2q9', '60847655', 'I22', '2026-06-19T08:20:00', NULL),
    ('x0f4h7', '60847655', 'SR3', '2026-06-20T12:00:00', NULL),
    ('z3w8e5', '60847655', 'SR4', '2026-06-20T12:10:00', NULL);
GO