SELECT 'Users' AS table_name, COUNT_BIG(*) AS row_count FROM staging_phase2.Users
UNION ALL SELECT 'Spaces', COUNT_BIG(*) FROM staging_phase2.Spaces
UNION ALL SELECT 'Maintenance', COUNT_BIG(*) FROM staging_phase2.Maintenance
UNION ALL SELECT 'BookingRequests', COUNT_BIG(*) FROM staging_phase2.BookingRequests
UNION ALL SELECT 'Bookings', COUNT_BIG(*) FROM staging_phase2.Bookings
UNION ALL SELECT 'Reviews', COUNT_BIG(*) FROM staging_phase2.Reviews
UNION ALL SELECT 'Reservations', COUNT_BIG(*) FROM staging_phase2.Reservations
UNION ALL SELECT 'AdvisoryAcknowledgements', COUNT_BIG(*) FROM staging_phase2.AdvisoryAcknowledgements;
GO
