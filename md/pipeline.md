## Project Structure

```text
.
├── .codex/                     # Canonical Codex skills and commands
├── req/                        # Business requirement input
├── outputs/                   # Phase 1 and Phase 2 database artifacts
├── backend/                   # Localhost Express adapter and API tests
├── scripts/                   # Skill sync and cross-platform test runners
├── assets/                    # ERD source and rendered diagrams
├── report/                    # LaTeX project reports
├── reference/                 # Phase 2 assignment source materials
├── AGENTS.md                  # Shared agent rules
├── MEMORY.md                 # Live project state
├── TODO.md                   # Ownership and remaining work
├── docker-compose.yml        # Local SQL Server integration container
└── .gitignore
```

# Database Design Pipeline

Phase 1 follows the seven ordered steps in `AGENTS.md`. Phase 2 extends the database with requirement changes, schema migration, concurrency design/implementation, concurrency tests, procedural data generation, index tuning, and analytical queries. Do not mark a later phase complete while its prerequisite or owner-owned interface is unresolved.

See `MEMORY.md` for current status and `TODO.md` for ownership. See `md/thienloc.md` for the Fedora/Docker handoff and parts 13–14 commands.
