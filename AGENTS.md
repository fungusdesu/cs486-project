# AGENTS.md - cs486-demo

Shared instructions for every agent working in this repository. Keep this file
limited to stable, project-wide rules. The canonical database workflow lives
in `.codex/skills/db-design-pipeline/SKILL.md`; current state and decisions live
in `MEMORY.md`.

## Project facts

- Root directory: `./`
- Group: `G06`
- DBMS: Microsoft SQL Server unless `MEMORY.md` records a user-approved change.
- This is a graded CS486 project. Correctness, reproducibility, evidence, and
  requirement traceability take priority over speed.
- Codex and Antigravity are the primary project agents.

## Instruction map

Use each file for one purpose:

| File | Purpose |
|---|---|
| `AGENTS.md` | Stable repository-wide rules |
| `MEMORY.md` | Current status, locked decisions, assumptions, and open questions |
| `TODO.md` | Phase 2 ownership, dependencies, and remaining work |
| `.codex/skills/db-design-pipeline/SKILL.md` | Operational workflow and routing |
| `req/business-requirement.md` | Phase 1 business source |
| `reference/CS486_Project_Phase02.pdf` | Phase 2 assignment source |

Do not duplicate detailed workflow text across these files. Edit the canonical
skill in `.codex/skills/db-design-pipeline/`; other tools should follow this
pointer instead of maintaining a copied skill.

If the files disagree, do not resolve the conflict silently. Report it and use
the user's latest explicit instruction. File presence is ground truth for
whether an artifact exists; it does not prove that the artifact is complete.

## Mandatory session start

Before any other project action:

1. Read `MEMORY.md` completely.
2. List `outputs/`, including hidden entries (`Get-ChildItem -Force outputs/`
   in PowerShell or `ls -la outputs/` on POSIX).
3. Read `.codex/skills/db-design-pipeline/SKILL.md` before producing or
   revising any database-pipeline artifact.
4. For Phase 2 work, also read `TODO.md` and the relevant assignment section.
5. Read the named artifact and its direct prerequisites before editing it.

Do not regenerate or re-derive a locked decision. If a decision is unclear or
conflicts with an artifact, ask the user rather than guessing.

## Workflow gates

Follow the Phase 1 sequence strictly:

1. Business requirement analysis
2. Conceptual design
3. Logical design
4. Design validation
5. Database implementation (DDL)
6. Sample data (DML)
7. Query design

Use the Phase 2 dependencies and completion gates defined by the canonical
skill and `TODO.md`. Do not mark a later artifact complete while a required
predecessor is missing, `in-progress`, or `needs revision`.

The user may explicitly authorize out-of-order scaffolding. Record the
override in `MEMORY.md`, label all affected mappings and claims provisional,
and do not mark the downstream deliverable complete until its real
prerequisites are approved.

## Design and traceability rules

- Trace every entity, table, relationship, constraint, migration, test, and
  query to a requirement or a user-confirmed decision.
- Record assumptions in the relevant artifact and in `MEMORY.md`.
- Record ambiguity under `MEMORY.md` open questions; never invent a business
  rule to close a gap.
- Use Mermaid `erDiagram` syntax for new or regenerated ER diagrams unless an
  approved artifact explicitly requires another representation.
- Preserve the exact output paths and names defined by the pipeline skill.
- Use SQL Server syntax and behavior unless a different DBMS is locked in
  `MEMORY.md`.

## Ownership and edit scope

- Use `TODO.md` as the source of truth for Phase 2 ownership.
- Keep one active owner per deliverable. Do not implement, complete, or
  silently revise another contributor's part unless the user explicitly asks.
- Default to editing only the file or deliverable named by the user and the
  minimal state/index files required by these rules.
- If a revision invalidates downstream work, mark the affected artifacts
  `needs revision` in `MEMORY.md` and identify them to the user. Do not
  regenerate them without authorization.

## Evidence, data, and credentials

- A file existing or SQL parsing successfully is not runtime evidence.
- Make completion claims only from the verification required by the relevant
  skill reference.
- Keep generated CSVs, validation outputs, load evidence, and credentials out
  of version control unless an assignment deliverable explicitly requires a
  sanitized evidence file.
- Supply database configuration through `DB_SERVER`, `DB_DATABASE`,
  `DB_USERNAME`, and `DB_PASSWORD`. Never write or print passwords.
- The ignored Part 14 `.env` may provide local values, but exported parent
  environment variables must take priority.
- On Linux/Fedora, require SQL authentication, target database `School`, redact
  secrets in dry runs, and never fall back to Windows integrated
  authentication.

## State updates

Before ending any task that changes project state, update `MEMORY.md`. Keep it
an index, not a duplicate report:

- update only the affected status or summary;
- append concise locked decisions and assumptions;
- add or resolve open questions explicitly;
- add one dated completion-log bullet for material work.

Do not rewrite unrelated `MEMORY.md` sections.
