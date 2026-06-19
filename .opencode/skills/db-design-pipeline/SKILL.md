---
name: db-design-pipeline
description: Use this skill whenever the user asks to analyze a business requirement, design a database, produce an ERD, write DDL/SQL, generate sample data, or write queries for the cs486-demo project. Also use it whenever the user says "continue", "next step", "regenerate <file>", or references outputs/<filename>. This skill defines the mandatory 7-step pipeline order, the required output filenames, and how to read/update MEMORY.md so work is never redone or done out of order. Trigger this even for requests that only ask for one step (e.g. "just do the ERD") — the skill enforces that prior steps exist and are not stale before producing anything.
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
