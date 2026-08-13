# Phase 1 workflow

Use this reference only for outputs `01` through `07`. Replace `G##` with
the group in `AGENTS.md` (`G06` here). Complete each step before the next.

## Dependency chain

`01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07`

Step `05` requires a passing step `04`. Step `07` uses business questions
from step `01` and the implemented schema from step `05`.

## 01 - Business requirement analysis

- Output: `outputs/01-business-req-analysis-G##.md`
- Input: `req/business-requirement.md`
- Template: `templates/01-business-req-analysis.md`
- Extract actors, processes, informal entities, business rules, constraints,
  assumptions, and open questions.
- Trace every requirement sentence to at least one extracted item. Never
  invent a rule.
- Done when coverage is complete and ambiguity is recorded.
- Memory: status, assumptions, and open questions.

## 02 - Conceptual design

- Output: `outputs/02-erd-design-G##.md`
- Input: output `01`, not a fresh analysis of the raw requirement
- Template: `templates/02-erd-design.md`
- Express the approved conceptual model using the required ERD notation and
  justify every relationship cardinality in prose.
- Trace every entity and relationship to output `01`.
- Done when entity, relationship, cardinality, and traceability coverage are
  complete.
- Memory: status, entity traceability summary, and open questions.

## 03 - Logical design

- Output: `outputs/03-logical-design-G##.md`
- Input: output `02`
- Template: `templates/03-logical-design.md`
- Convert the model into tables, keys, data types, optionality, and constraints.
- Demonstrate normalization to at least Third Normal Form (3NF).
- Done when every table traces to an approved entity or relationship and the
  normalization reasoning is explicit.
- Memory: status, table summary, and achieved normal form.

## 04 - Design validation

- Output: `outputs/04-design-validation-G##.md`
- Input: output `03`
- Template: `templates/04-design-validation.md`
- Check normalization, constraint completeness, and traceability from output
  `01` through output `03`.
- Give every check a `PASS`, `FAIL`, or `N/A` result with reasoning.
- If validation fails, mark the affected design step `needs revision`; do not
  silently repair it inside the validation report.
- Done when every check is evaluated and blocking questions are explicit.
- Memory: validation status and any upstream revision status.

## 05 - Database definition (DDL)

- Output: `outputs/05-db-definition-G##.sql`
- Inputs: approved output `03` and passing output `04`
- Template: `templates/05-db-definition.md`
- Target the DBMS locked in `MEMORY.md` (SQL Server by default).
- Implement named primary-key, foreign-key, `NOT NULL`, `UNIQUE`, and
  `CHECK` constraints required by the approved design.
- Order objects by dependency or add foreign keys after table creation.
- Done when the script executes top to bottom on the target DBMS without
  forward-reference or constraint-definition errors.
- Memory: status and any verified deviations.

## 06 - Sample data (DML)

- Output: `outputs/06-sample-data-G##.sql`
- Input: output `05`
- Template: `templates/06-sample-data.md`
- Insert parents before children and satisfy every key and value constraint.
- Include enough variety to exercise output `07`, including allowed nulls and
  relevant boundary values.
- Done when the inserts execute cleanly against a clean output `05` schema.
- Memory: status.

## 07 - Query design

- Output: `outputs/07-query-design-G##.sql`
- Inputs: output `01` for business questions and output `05` for schema
- Template: `templates/07-query-design.md`
- Comment each query with its business question and tables or joins.
- Use only questions traceable to requirements; do not invent reporting needs
  solely to demonstrate SQL syntax.
- Done when every query maps to a real business question and executes against
  the implemented schema and sample data.
- Memory: status and Phase 1 completion.
