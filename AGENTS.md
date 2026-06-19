# AGENTS.md — cs486-demo

CS486 database systems project. AI agent transforms a business requirement
into database design artifacts, from requirement analysis to SQL queries.

> This file is the shared instruction set for every agent tool used on this
> project (OpenCode, Antigravity, Codex CLI, OpenClaw, and others that read
> AGENTS.md natively). Claude Code does not read AGENTS.md automatically —
> see `CLAUDE.md` in the repo root, which just points back here. If you're
> adding a new tool, check whether it reads AGENTS.md natively first; if
> not, add a one-line pointer file the same way CLAUDE.md does, rather than
> duplicating these rules.

## Recurring context

- Root directory: `d:\cs486-project`
- Group number: G06
- This is a graded academic project. Output quality and traceability matter
  more than speed.
- Run `ls -la outputs/` before assuming any file exists or doesn't exist.

## Skill location

The detailed pipeline workflow (per-step templates, prerequisite checks)
lives in a `db-design-pipeline` skill, duplicated/symlinked per tool so
each one's native skill loader can find it:

- OpenCode: `.opencode/skills/db-design-pipeline/SKILL.md`
- Claude Code: `.claude/skills/db-design-pipeline/SKILL.md`
- OpenClaw: `.openclaw/skills/db-design-pipeline/SKILL.md`
- Antigravity / Codex CLI: no required skill folder location as of this
  writing — they will find the skill via this AGENTS.md pointer instead.
  Read `.opencode/skills/db-design-pipeline/SKILL.md` (treat this path as
  canonical/source-of-truth if copies drift) before producing any pipeline
  output.

All copies must stay identical. If you edit the skill, edit the canonical
copy in `.opencode/skills/db-design-pipeline/` first, then sync the others
(see `scripts/sync-skills.sh` if present, or copy manually).


## ⚠️ Always read MEMORY.md first

Before doing anything else in a session, read `MEMORY.md` in the project
root. It contains the current pipeline stage, which files are
done/in-progress/not started, open questions, and locked decisions.
Do not regenerate or re-derive anything MEMORY.md says is already decided —
ask the user instead of guessing if something is unclear.

After completing any task that changes project state (a file is finished,
a decision is locked, an assumption is recorded), update MEMORY.md before
ending the turn. Keep entries short — bullet facts, not prose.

# Database Design Agent Rules

This project transforms business requirements into database design artifacts.

## Workflow Order

Always follow this strict order. Do not skip ahead or jump to DDL/SQL early:

1. Business requirement analysis
2. Conceptual design (ERD, Crow's Foot notation)
3. Logical design (tables, keys, normalization)
4. Design validation (normal forms, constraint check, traceability check)
5. Database implementation (DDL)
6. Sample data preparation (DML)
7. Query design (SQL queries answering business questions)

Each step's output document must be read by the agent before producing the
next step's output. Never produce a later-stage artifact if an earlier-stage
artifact is missing, marked "in-progress," or marked "needs revision" in
MEMORY.md.

## Required Outputs

All outputs go in `outputs/` using this exact naming (replace `G##` with the
actual group number from this file):

```
01-business-req-analysis-G##.md
02-erd-design-G##.md
03-logical-design-G##.md
04-design-validation-G##.md
05-db-definition-G##.sql
06-sample-data-G##.sql
07-query-design-G##.sql
```

## DBMS

Use Microsoft SQL Server unless the user specifies another DBMS in
MEMORY.md.

## Design Rules

- Record assumptions explicitly in the relevant output file AND in
  MEMORY.md under "Locked decisions" or "Open questions."
- Record open questions explicitly; do not silently resolve them by
  guessing — ask the user.
- Preserve traceability: every table and constraint must be traceable back
  to a specific line/requirement in `req/business-requirement.md`.
- Use Mermaid `erDiagram` syntax for all ER diagrams.
- Do not silently invent business rules not present in the requirement doc
  or in a user-confirmed assumption.

## Token / cost discipline

- Default to regenerating or editing ONLY the specific file(s) the user
  names. Do not re-read or regenerate the whole pipeline unless asked.
- When asked to "continue" or "keep going," consult MEMORY.md for the next
  pending step rather than re-analyzing prior outputs from scratch.
- Summarize long file contents into MEMORY.md once finalized, instead of
  re-reading the full file in future sessions.
