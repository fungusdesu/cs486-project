# SETUP.md — Using this project across different agent tools

This repo works with multiple AI coding agents without duplicating rules.
Two files carry all the logic:

- **`AGENTS.md`** — rules that don't change (workflow order, output
  filenames, DBMS, design rules). Read natively by OpenCode, Antigravity,
  and Codex CLI.
- **`MEMORY.md`** — live project state (what's done, open questions, locked
  decisions). Not read automatically by any tool — `AGENTS.md` explicitly
  tells the agent to read it first and update it last.

The actual step-by-step pipeline procedure lives in a skill,
`db-design-pipeline`, copied into each tool's expected skill folder.

## Per-tool notes

### OpenCode
Works out of the box. `AGENTS.md` is read automatically.
Skill: `.opencode/skills/db-design-pipeline/SKILL.md` (canonical copy —
edit here first).
Slash command: `/design-db` (defined in `.opencode/commands/design-db.md`).

```bash
cd path/to/cs486-demo
opencode
# inside opencode:
/design-db
```

### Antigravity
Works out of the box. `AGENTS.md` is read automatically before the session
starts. Antigravity does not require skills in a specific folder the way
OpenCode does — it can read `.opencode/skills/db-design-pipeline/SKILL.md`
directly because `AGENTS.md` points to it. Antigravity also keeps its own
auto-generated Knowledge Items between sessions; treat those as a bonus,
not a replacement for MEMORY.md, since MEMORY.md is the version you
control directly.

### Codex CLI
Works out of the box — Codex reads `AGENTS.md` files before doing any work,
same as OpenCode/Antigravity. No skill-folder convention as of this
writing, so it follows the same AGENTS.md pointer to
`.opencode/skills/db-design-pipeline/SKILL.md`.

```bash
cd path/to/cs486-demo
codex
```

If you want to confirm which instruction files Codex picked up, you can
ask it directly or check its session log per Codex's own docs.


### OpenClaw
Skills work the same way (`SKILL.md` with YAML frontmatter). Place/keep
the synced copy at `.openclaw/skills/db-design-pipeline/SKILL.md`.
OpenClaw doesn't read `AGENTS.md` as its primary identity/config file by
default — if your OpenClaw setup uses a different bootstrap file (e.g. an
identity or system file under `.openclaw/`), add a short pointer there
rather than re-stating the rules.

## Adding a new tool later

1. Check whether it reads `AGENTS.md` natively. If yes, you're done — no
   extra file needed.
2. If no, add a one-line pointer file at the location that tool expects,
   pointing back to `AGENTS.md` + `MEMORY.md`.
3. If the tool has its own skills system, add its expected folder to
   `scripts/sync-skills.sh`'s `TARGETS` array and re-run it.
4. Note it in this file's "Per-tool notes" section.

## Keeping skill copies in sync

After editing `.opencode/skills/db-design-pipeline/SKILL.md` (the
canonical copy) or anything under its `templates/`, run:

```bash
./scripts/sync-skills.sh
```

This refreshes `.openclaw/skills/`. Antigravity and
Codex CLI don't need a copy — they reach the canonical path via the
`AGENTS.md` pointer.
