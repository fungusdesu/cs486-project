---
description: Run the database design pipeline (reads MEMORY.md, generates the next pending artifact, or a specific one if named)
---

Read AGENTS.md and MEMORY.md first.

Use the `db-design-pipeline` skill (`.opencode/skills/db-design-pipeline/SKILL.md`)
to determine what to generate:

- If the user passed a specific output filename or step name as an argument,
  generate only that file (and check its prerequisites are `done` per
  MEMORY.md first).
- If the user passed `req/business-requirement.md` or no argument, and
  this is a fresh project, start at step 1.
- Otherwise, continue from the first non-`done` step in MEMORY.md's
  pipeline status table.

After generating, update MEMORY.md per the skill's instructions, then stop
and report status — do not auto-continue to the next step without the user
asking.
