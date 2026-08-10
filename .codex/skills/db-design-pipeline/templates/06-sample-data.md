# Sample Data Guidance — outputs/06-sample-data-G##.sql

- INSERT order must respect FK dependencies (parents before children).
- Include enough rows (suggest 5-10 per core table) to support every query
  planned in step 7 — check step 1's business questions before finalizing
  row count and variety.
- Include at least one edge case per nullable/optional column (a row with
  NULL where allowed) and at least one boundary value per CHECK constraint.
- Comment each INSERT block with which table it targets.
