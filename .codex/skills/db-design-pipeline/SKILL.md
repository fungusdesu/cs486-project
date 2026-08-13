---
name: db-design-pipeline
description: Analyze requirements and create, revise, validate, or continue database-design artifacts for the cs486-demo project. Use for ERDs, logical schemas, normalization, SQL Server DDL or DML, sample data, concurrency, synthetic-data generation, indexing, analytical queries, Phase 1 outputs 01-07, Phase 2 outputs 08-16, Parts 13-14, or general requests to continue the CS486 database project; check memory, filesystem state, prerequisites, and ownership before acting.
---

# Database Design Pipeline

Use this skill as the operational router for the CS486 project. Keep stable
repository policy in `AGENTS.md`, current facts in `MEMORY.md`, and Phase 2
ownership in `TODO.md`.

## Start every invocation

1. Read `MEMORY.md` completely before any other project action.
2. List `outputs/`, including hidden entries. Treat the filesystem as truth
   for existence only; a present file may still be incomplete.
3. Read `AGENTS.md`.
4. Classify the request as Phase 1, Phase 2, a single-file revision, or
   project administration.
5. For Phase 2, read `TODO.md` and the relevant assignment section.
6. Check prerequisites, ownership, status, locked decisions, and open questions.
7. Read only the target, its direct inputs, and the routed phase reference.

Report any mismatch between status and disk. File presence does not prove
completion.

## Route the request

| Request | Required guidance |
|---|---|
| Phase 1 output `01`-`07` | Read `references/phase-1.md` and the named template in `templates/` |
| Phase 2 output `08`-`16` | Read `references/phase-2.md` and `TODO.md` |
| Part 13 concurrency tests | Read the Part 13 section of `references/phase-2.md` |
| Part 14 data generator/load | Read the Part 14 section of `references/phase-2.md` |
| Revise one artifact | Follow the revision workflow below |
| Continue without a target | Select the first incomplete, user-owned, unblocked item in `MEMORY.md` and `TODO.md` |

Do not load both phase references unless the task crosses both phases.

## Enforce prerequisites and ownership

- Do not produce a later artifact when a required predecessor is absent,
  `in-progress`, or `needs revision`.
- Use `TODO.md` for live Phase 2 ownership and status. Keep other
  contributors' detailed procedures out of this skill.
- Do not implement another contributor's deliverable unless explicitly asked.
- Allow out-of-order work only after a user override. Record it in `MEMORY.md`,
  keep final mappings provisional, and withhold completion claims until the
  real prerequisite is approved.
- Ask about unresolved business choices that materially affect the design.
  Never convert ambiguity into an invented rule.

## Produce an artifact

1. Read the direct prerequisite instead of re-deriving it from an earlier source.
2. Use the exact path, template, and acceptance criteria in the phase reference.
3. Preserve requirement-to-artifact traceability.
4. Record assumptions and open questions in the artifact and `MEMORY.md`.
5. Verify in proportion to the claim. Parsing, execution, concurrency,
   bounded-memory generation, and server loading are distinct evidence levels.
6. Update `MEMORY.md` after a material state change.

## Revise an existing artifact

1. Read `MEMORY.md`, the named artifact, and its direct input.
2. Preserve locked decisions and unrelated user changes.
3. Make only the requested correction.
4. Identify downstream artifacts invalidated by the change.
5. Mark them `needs revision` in `MEMORY.md`; do not regenerate them
   automatically.

## Update project memory

Edit only affected status, decisions, assumptions, open questions, short
traceability pointers, and the dated completion log. Keep entries concise.
Never remove a locked decision without telling the user.

## Completion standard

Mark work done only when the relevant reference's acceptance criteria are met.
Distinguish scaffolded from integrated, parsed from executed, locally validated
from server-loaded, provisional from final, and generated output from retained
credential-free execution evidence.
