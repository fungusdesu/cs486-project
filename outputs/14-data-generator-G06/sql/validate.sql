SELECT 'Users' AS table_name, COUNT_BIG(*) AS row_count FROM staging_phase2.Users
UNION ALL SELECT 'Spaces', COUNT_BIG(*) FROM staging_phase2.Spaces
UNION ALL SELECT 'Maintenance', COUNT_BIG(*) FROM staging_phase2.Maintenance
UNION ALL SELECT 'BookingRequests', COUNT_BIG(*) FROM staging_phase2.BookingRequests
UNION ALL SELECT 'Bookings', COUNT_BIG(*) FROM staging_phase2.Bookings
UNION ALL SELECT 'Reviews', COUNT_BIG(*) FROM staging_phase2.Reviews
UNION ALL SELECT 'Reservations', COUNT_BIG(*) FROM staging_phase2.Reservations
;

/*
  Staging deliberately uses NVARCHAR for raw CSV ingestion. Validate the text
  before load-final.sql explicitly converts it to the final output-10 types.
  In particular, both dbo.SpacePolicy.space_policy_id and
  dbo.Space.space_policy_id must be CHAR(5), uppercase A-Z only.
*/
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns c
    INNER JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID(N'dbo.SpacePolicy')
      AND c.name = N'space_policy_id'
      AND t.name = N'char'
      AND c.max_length = 5
      AND c.is_nullable = 0
)
    THROW 51402, 'Schema mismatch: dbo.SpacePolicy.space_policy_id must be CHAR(5) NOT NULL.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns c
    INNER JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID(N'dbo.Space')
      AND c.name = N'space_policy_id'
      AND t.name = N'char'
      AND c.max_length = 5
      AND c.is_nullable = 0
)
    THROW 51403, 'Schema mismatch: dbo.Space.space_policy_id must be CHAR(5) NOT NULL.', 1;

IF EXISTS
(
    SELECT 1
    FROM staging_phase2.Spaces
    WHERE LEN(space_policy_id) <> 5
       OR space_policy_id COLLATE Latin1_General_100_BIN2 LIKE '%[^A-Z]%'
)
    THROW 51404, 'Invalid staged space_policy_id: expected exactly five uppercase ASCII letters.', 1;
GO
