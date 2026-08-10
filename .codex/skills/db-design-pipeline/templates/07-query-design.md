# Query Design Guidance — outputs/07-query-design-G##.sql

For each query:

```sql
-- Business question: <verbatim or paraphrased from step 1>
-- Tables/joins used: <list>
SELECT ...
```

Cover a spread of query types unless the business requirement implies
otherwise: simple filter, multi-table join, aggregation (GROUP BY/HAVING),
a subquery or CTE, and at least one query that demonstrates a business
rule from step 1 (e.g. enforcing a constraint logically at the query
level, like "active customers only").
