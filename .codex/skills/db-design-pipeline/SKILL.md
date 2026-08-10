---
name: db-design-pipeline
description: Use this skill whenever the user asks to analyze a business requirement, design a database, produce an ERD, write DDL/SQL, generate sample data, write queries, or continue work for the cs486-demo project. This skill defines the mandatory Phase 1 pipeline and the Phase 2 ownership-aware workflow, including detailed instructions only for user-owned parts 13 and 14. Trigger this even for requests that name only one step: prerequisite status, ownership, MEMORY.md, and outputs/ must be checked first.
---

# Database Design Pipeline

Turns `req/business-requirement.md` into 7 ordered design artifacts. This
skill is the single source of truth for *how* each step is produced. Global
project rules (DBMS choice, naming, traceability) live in `AGENTS.md`.
Current project status lives in `MEMORY.md`. Read both before doing
anything in this skill.

## Step 0 — Always do this first, every invocation

1. Read `MEMORY.md`. Determine: current stage, status of each of the 7
   files, locked decisions, open questions.
2. Run `ls -la outputs/` to confirm what actually exists on disk — MEMORY.md
   is a cache, not ground truth. If they disagree, trust the filesystem and
   flag the mismatch to the user before proceeding.
3. If the user's request matches a step whose prerequisites are not
   `done` in MEMORY.md, stop and tell the user which earlier step is
   blocking it. Do not generate out of order. Exception: the user can
   explicitly override with "skip ahead anyway" — if they do, record this
   override in MEMORY.md.
4. If the user asked to "continue" with no specific file named, pick the
   first step in the table below whose status is not `done`.

## The 7 steps

Each step lists: required input(s), the template to follow, what makes it
"done," and what to write back to MEMORY.md.

### 1. Business requirement analysis → `outputs/01-business-req-analysis-G##.md`
- Input: `req/business-requirement.md`
- Template: `templates/01-business-req-analysis.md`
- Extract actors, business processes, data entities (informal), business
  rules, constraints, and explicit assumptions/open questions for anything
  ambiguous. Do not invent rules not in the text.
- Done when: every requirement sentence is reflected in at least one
  extracted item (traceability), and open questions are listed rather than
  silently resolved.
- Write to MEMORY.md: status → done; any open questions; any assumptions.

### 2. Conceptual design (ERD) → `outputs/02-erd-design-G##.md`
- Input: step 1 output (not the raw requirement doc again)
- Template: `templates/02-erd-design.md`
- Crow's Foot notation, expressed as Mermaid `erDiagram`. Every entity must
  cite which part of step 1 it came from.
- Done when: every entity/relationship traces to step 1, and cardinalities
  are justified in prose, not just drawn.
- Write to MEMORY.md: status → done; entity list in the traceability
  snapshot section; any new open questions.

### 3. Logical design → `outputs/03-logical-design-G##.md`
- Input: step 2 output
- Template: `templates/03-logical-design.md`
- Convert ERD to tables: PKs, FKs, data types, normalization to at least
  3NF (state the normal form reasoning).
- Done when: every table traces to an entity/relationship from step 2.
- Write to MEMORY.md: status → done; table list; normal form achieved.

### 4. Design validation → `outputs/04-design-validation-G##.md`
- Input: step 3 output
- Template: `templates/04-design-validation.md`
- Check: normalization correctness, constraint completeness, traceability
  from step 1 through step 3, and flag any unresolved open questions that
  block implementation.
- Done when: every check has a pass/fail/N-A with reasoning. If anything
  fails, set step 3's status to `needs revision` in MEMORY.md instead of
  silently patching it here.
- Write to MEMORY.md: status → done (or blocked, if validation failed).

### 5. Database implementation (DDL) → `outputs/05-db-definition-G##.sql`
- Input: step 3 (and step 4 must be `done`, not `needs revision`)
- Template: `templates/05-db-definition.md`
- Target the DBMS recorded in MEMORY.md (default SQL Server). Include all
  constraints from step 3/4: PK, FK, NOT NULL, CHECK, UNIQUE.
- Done when: it can be read top-to-bottom and create the schema with no
  forward-reference errors (order CREATE TABLE statements by dependency).
- Write to MEMORY.md: status → done.

### 6. Sample data → `outputs/06-sample-data-G##.sql`
- Input: step 5 output
- Template: `templates/06-sample-data.md`
- INSERT statements respecting FK order and all CHECK/UNIQUE constraints.
  Enough rows per table to exercise the query designs in step 7 (joins,
  edge cases like NULLs where allowed).
- Done when: inserts run cleanly against the step 5 schema in declared
  order.
- Write to MEMORY.md: status → done.

### 7. Query design → `outputs/07-query-design-G##.sql`
- Input: step 1 (for business questions) + step 5 (for schema)
- Template: `templates/07-query-design.md`
- Each query commented with: the business question it answers (traced to
  step 1) and which tables/joins it uses.
- Done when: every query maps to a real business question from step 1.
- Write to MEMORY.md: status → done. This is the final step — note
  pipeline-complete in MEMORY.md.

## Updating MEMORY.md (do this at the end of every step, not just at the end of a session)

Edit these sections only — do not rewrite unrelated parts of MEMORY.md:
- The pipeline status table row for the step just completed
- Locked decisions (append, never delete without telling the user)
- Open questions (append new ones; remove ones the user just answered)
- Assumptions recorded (append)
- Traceability snapshot (append a short pointer, not the full content —
  the full content lives in the output file itself)

Keep every MEMORY.md entry to one line. MEMORY.md is a pointer/index, not a
duplicate of the output files.

## When asked to fix/revise a single file

1. Read MEMORY.md to confirm what's currently locked vs open.
2. Read only the named file (and its direct input, per the table above) —
   not the whole pipeline.
3. Make the change.
4. If the fix changes something a later step already depended on, mark
   that later step `needs revision` in MEMORY.md and tell the user which
   downstream files are now stale. Do not auto-regenerate them — ask first.

## Hard rules (inherited from AGENTS.md, repeated here for emphasis)

- Never skip ahead to a step whose prerequisite isn't `done`.
- Never silently invent a business rule absent from the requirement doc.
- Never regenerate a file the user didn't ask about "just to be safe."
- Always prefer asking an open question over guessing.


## Phase 2 workflow (outputs 08–16)

Phase 2 extends the completed Phase 1 database. Read `MEMORY.md`, `TODO.md`,
and the relevant existing output before changing a Phase 2 artifact. Preserve
the dependency order below. A part owned by another contributor is a
placeholder only: do not implement, complete, or silently revise it.

### Part 08 — Requirement-change analysis

Placeholder — owned by another team member. Do not produce or revise this part from this
skill unless the user explicitly requests that work.

### Part 09 — Updated ERD and logical design

Placeholder — owned by another team member. Do not produce or revise this part from
this skill unless the user explicitly requests that work.

### Part 10 — Schema migration

Placeholder — owned by another team member. Do not produce or revise this part from this
skill unless the user explicitly requests that work.

### Part 11 — Concurrency design

Placeholder — owned by another team member. Do not produce or revise this part from
this skill unless the user explicitly requests that work.

### Part 12 — Concurrency implementation

Placeholder — owned by another team member. Do not produce or revise this part from this
skill unless the user explicitly requests that work.

### Part 13 — Concurrency tests (`outputs/13-concurrency-tests-G06/`)

This is Thien Loc's part. It must remain reproducible and must target the
final protected database operation from part 12 once that interface is
available. Until parts 09–12 are approved, scaffolding, configuration, and
isolated test fixtures may be prepared, but final schema/procedure mappings
and final claims must remain explicitly provisional.

Required implementation:

- Provide a README with prerequisites, setup, one-command execution, expected
  outcomes, cleanup, and the exact environment/configuration used.
- Use two or more independent SQL Server connections/processes; do not use an
  in-process mutex as the concurrency solution.
- Include scenarios for instant-versus-instant, instant-versus-staff, and
  staff-versus-staff approval attempts for the same overlapping slot.
- Include non-overlapping and boundary-adjacent requests that should both
  succeed.
- Include advisory maintenance with acknowledgement, out-of-service
  maintenance blocking an overlap, and advisory escalation identifying
  affected approved bookings.
- Assert final database state, not only returned messages. Repeat race-sensitive
  scenarios enough times to make the result meaningful.
- Keep unsafe demonstrations isolated from the real schema and clearly label
  them as demonstrations. Clean up all test objects and data.
- Preserve machine-readable results plus a concise Markdown evidence table,
  including outcome, elapsed time, approved count, fixture identifier, and
  environment versions.

Part 13 is done only when a clean migrated database can reproduce the tests,
the unsafe race is demonstrated in isolation, the protected operation allows
only one conflicting approval, and legitimate non-conflicting requests are
not unnecessarily blocked.

### Part 14 — Procedural data generator (`outputs/14-data-generator-G06/`)

This is a user-owned part. It must generate synthetic data procedurally
without consuming agent tokens during normal use. It must target the final
schema from parts 09–10; until that schema is approved, keep mappings and
production-load assertions provisional.

Required implementation:

- Provide a seeded Python CLI with documented commands for `generate`,
  `load`, `validate`, and `clean`; support at least 100,000 bookings and a
  configurable 500,000-booking run.
- Cover at least three academic years using a documented, configurable term
  calendar. Reuse a realistic smaller synthetic user population across
  bookings; identities must be synthetic only.
- Use lazy generators/iterators and streaming CSV output. Do not accumulate
  the full dataset in memory, recurse once per row, or emit one SQL INSERT per
  generated row.
- Generate parent/staging data before dependent data and provide SQL Server
  staging, bulk-load, validation, transformation, and cleanup scripts.
- Include meaningful non-zero distributions for approvals (pending,
  approved, rejected, and instant approval), cancellations, no-shows,
  maintenance impact levels, and booking-level advisory acknowledgement flags.
- Validate requested versus generated counts, duplicate identifiers, foreign
  keys, required values, time ranges, approved-slot uniqueness, academic-year
  coverage, and reproducibility from the same seed.
- Record the seed, configuration, Python/runtime versions, row counts by
  table/status, generated size, generation time, staging-load time, and any
  final database-load measurements available after part 10.
- Keep generated CSVs, logs, results, and credentials out of version control;
  provide `.env.example` or equivalent names without secrets.
- For the G06 final-schema adapter, use the committed sequence
  `create-staging.sql` -> `bcp` -> `validate.sql` -> `load-final.sql` ->
  `validate-final.sql`. The production transformation must be transactional,
  rerunnable for the staged synthetic keys, set-based, and followed by final
  row-count, approved-overlap, acknowledgement, and database-size checks.
- On Fedora/Linux, pass development connection values through `DB_SERVER`,
  `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD`. Never print, commit, or
  retain the password in evidence; dry-run command output must redact it.
- The part-14 CLI may load its ignored local `.env` without an external
  package, but it must not override values already exported by the parent
  shell and must never echo secrets.
- On Fedora/Linux, do not use `sqlcmd -E` or `bcp -T` as an implicit fallback.
  Fail before execution if SQL credentials are absent. For G06, require the
  `School` database created/migrated by outputs 05 and 10, and apply the
  requested trust-certificate option consistently to both clients.
- Validate a 500,000-booking run with bounded memory. A generated/validated
  local dataset proves the generator, but only successful retained SQL output
  and load evidence prove that the server load ran.

Part 14 implementation is done only when another group member can reproduce a
clean load using committed scripts and README instructions, validation reports
zero unexpected errors, and the generated dataset satisfies the declared
size, coverage, referential-integrity, and distribution requirements. Record
server execution separately: do not claim it until final SQL validation and
credential-free load evidence have actually been retained.

### Part 15 — Index-tuning report

Placeholder — owned by another team member. Do not produce or
revise this part from this skill unless the user explicitly requests that
work.

### Part 16 — Analytical queries

Placeholder — owned by another team member. Do not produce or revise this part from this
skill unless the user explicitly requests that work.

## Post-project review

After Phase 2 is complete, perform a review before marking the project closed.
The review is not a new owned pipeline part and must not be used to fill in
another contributor's placeholder. Record concise findings in `MEMORY.md` and,
where appropriate, in the final Phase 2 report.

Review checklist:

- Verify every Phase 2 requirement traces through the approved design,
  migration, generator/tests, queries, and retained evidence.
- Confirm parts 13 and 14 are reproducible from a clean database using only
  committed code and documented commands.
- Verify generated data is synthetic, seeded, size-compliant, referentially
  valid, and covered by the declared distributions.
- Verify concurrency evidence tests the final protected operation and that
  unsafe fixtures cannot affect production data.
- Run final backend smoke tests, query checks, and migration/data-load checks
  where the owning contributors provide the required interfaces.
- Record unresolved questions, known limitations, environment details, and
  follow-up work. Do not claim completion where evidence is missing.

When the review is complete, append a dated one-line review result to
`MEMORY.md` and mark only the actually verified work as done.
