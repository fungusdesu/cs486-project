# Campus Space Management System — G06

CS486 (Introduction to Database Systems) project. An AI agent pipeline transforms a business requirement into database design artifacts, from requirement analysis to SQL queries.

## Group Members
- Trần Tôn Minh Kỳ — 24125102
- Quách Thiên Lạc — 24125092
- Nguyễn Đình Thiên Lộc — 24125093
- Nguyễn Hồng Tấn Tài — 24125038

## Project Structure

```text
.
├── .opencode/                  # Canonical agent skills & commands (OpenCode)
│   ├── commands/design-db.md
│   └── skills/db-design-pipeline/
├── .claude/                    # Synced skill copy (Claude Code)
├── .openclaw/                  # Synced skill copy (OpenClaw)
├── req/
│   └── business-requirement.md # Input business requirement
├── outputs/                    # Generated pipeline artifacts (01–07)
├── report/                     # LaTeX write-up (main.tex)
├── reference/                  # Teacher's demo repo (for comparison)
├── scripts/
│   └── sync-skills.sh          # Sync canonical skill to .claude/.openclaw
├── AGENTS.md                   # Shared agent rules (all tools read this)
├── MEMORY.md                   # Live project state (agents read/update)
├── CLAUDE.md                   # Pointer for Claude Code → AGENTS.md
├── SETUP.md                    # Per-tool setup guide
├── PROMPTS.md                  # Prompt templates for each agent
└── .gitignore
```

## Agent Tools Supported

| Tool | How it finds rules |
|---|---|
| **Antigravity** | Reads `AGENTS.md` automatically |
| **OpenCode** | Reads `AGENTS.md` automatically; skill at `.opencode/skills/` |
| **Codex CLI** | Reads `AGENTS.md` automatically |
| **Claude Code** | Reads `CLAUDE.md` → points to `AGENTS.md` |
| **OpenClaw** | Skill at `.openclaw/skills/`; add pointer if needed |
| **Claude.ai (browser)** | Paste `AGENTS.md` + `MEMORY.md` manually |

See [SETUP.md](SETUP.md) for detailed per-tool instructions and [PROMPTS.md](PROMPTS.md) for prompt templates.

## Pipeline (7 steps)

1. Business requirement analysis → `outputs/01-business-req-analysis-G06.md`
2. Conceptual design (ERD) → `outputs/02-erd-design-G06.md`
3. Logical design → `outputs/03-logical-design-G06.md`
4. Design validation → `outputs/04-design-validation-G06.md`
5. DDL → `outputs/05-db-definition-G06.sql`
6. Sample data → `outputs/06-sample-data-G06.sql`
7. Query design → `outputs/07-query-design-G06.sql`

## Quick Start

```bash
# Clone
git clone https://github.com/fungusdesu/cs486-project .

# Using OpenCode
cd d:\cs486-project
opencode
# then: /design-db

# Using Antigravity — just open the folder, AGENTS.md is read automatically

# LaTeX report
cd report
latexmk -pvc -pdf main.tex
```

## Notes
- **Do not commit API keys** or access tokens to Git.
- Compiled PDFs must be included as binaries in the Releases section, not directly committed.
- See `MEMORY.md` for current pipeline progress.