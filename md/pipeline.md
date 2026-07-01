## Project Structure

```text
.
├── .opencode/                  # Canonical agent skills & commands (OpenCode)
│   ├── commands/design-db.md
│   └── skills/db-design-pipeline/
├── .openclaw/                  # Synced skill copy (OpenClaw)
├── req/
│   └── business-requirement.md # Input business requirement
├── outputs/                    # Generated pipeline artifacts (01–07)
├── report/                     # LaTeX write-up (main.tex)
├── reference/                  # Teacher's demo repo (for comparison)
├── scripts/
│   └── sync-skills.sh          # Sync canonical skill to .openclaw
├── md/
│   ├── pipeline.md             # Project structure tree and pipeline overview
│   ├── setup.md                # Per-tool installation and launch instructions
│   └── usage.md                # Guide for executing database setup and queries in SQL Server
├── AGENTS.md                   # Shared agent rules (all tools read this)
├── MEMORY.md                   # Live project state (agents read/update)
├── PROMPTS.md                  # Prompt templates for each agent
└── .gitignore
```

# Database Design Pipeline

This project follows a strict 7-step pipeline to transform a business requirement into database design artifacts:

1. Business requirement analysis → `outputs/01-business-req-analysis-G06.md`
2. Conceptual design (ERD) → `outputs/02-erd-design-G06.md`
3. Logical design → `outputs/03-logical-design-G06.md`
4. Design validation → `outputs/04-design-validation-G06.md`
5. DDL → `outputs/05-db-definition-G06.sql`
6. Sample data → `outputs/06-sample-data-G06.sql`
7. Query design → `outputs/07-query-design-G06.sql`

See `MEMORY.md` to track the current progress of each step.
