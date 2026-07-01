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