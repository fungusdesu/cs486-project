# DDL Guidance — outputs/05-db-definition-G##.sql

Order `CREATE TABLE` statements so no FK references a table that hasn't
been created yet. If using SQL Server, prefer adding FK constraints via
`ALTER TABLE ... ADD CONSTRAINT` after all tables exist, to avoid ordering
headaches entirely.

Required per table:
- PRIMARY KEY
- FOREIGN KEY constraints with explicit names (`CONSTRAINT FK_x_y`)
- NOT NULL where step 3/4 says required
- CHECK constraints for any business rule that maps to a value constraint
- Comment above each table: `-- Traced to: <entity from step 2/3>`

End the file with a comment block listing any deviations from step 3/4
and why (should be rare — if you need a deviation, update step 3/4 instead
and note it in MEMORY.md).
