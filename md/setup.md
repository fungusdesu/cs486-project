# SETUP.md — Using this project across different agent tools

This repo works with multiple AI coding agents without duplicating rules.
Two files carry all the logic:

- **`AGENTS.md`** — rules that don't change (workflow order, output
  filenames, DBMS, design rules). Used by Codex and Antigravity.
- **`MEMORY.md`** — live project state (what's done, open questions, locked
  decisions). Not read automatically by any tool — `AGENTS.md` explicitly
  tells the agent to read it first and update it last.

The actual step-by-step pipeline procedure lives in a skill,
`db-design-pipeline`, copied into each tool's expected skill folder.

## Per-tool notes

### Codex
Works out of the box. `AGENTS.md` is read automatically.
Skill: `.codex/skills/db-design-pipeline/SKILL.md` (canonical copy —
edit here first).
Slash command: `/design-db` (defined in `.codex/commands/design-db.md`).

```bash
cd path/to/cs486-demo
codex
# inside codex:
/design-db
```

### Antigravity
Works out of the box. `AGENTS.md` is read automatically before the session
starts. Antigravity does not require skills in a specific folder the way
Codex does — it can read `.codex/skills/db-design-pipeline/SKILL.md`
directly because `AGENTS.md` points to it. Antigravity also keeps its own
auto-generated Knowledge Items between sessions; treat those as a bonus,
not a replacement for MEMORY.md, since MEMORY.md is the version you
control directly.

## Adding a new tool later

1. Check whether it reads `AGENTS.md` natively. If yes, you're done — no
   extra file needed.
2. If no, add a one-line pointer file at the location that tool expects,
   pointing back to `AGENTS.md` + `MEMORY.md`.
3. If the tool has its own skills system, point it to the canonical Codex
   skill rather than creating a drifting duplicate.
4. Note it in this file's "Per-tool notes" section.

## Updating the pipeline skill

Edit `.codex/skills/db-design-pipeline/SKILL.md`, the canonical copy.
Antigravity reaches that path through the `AGENTS.md` pointer;
no duplicated skill directory or synchronization command is required.
