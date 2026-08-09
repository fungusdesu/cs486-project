# G06 Project Prompts

`AGENTS.md`, `MEMORY.md`, and `.codex/skills/db-design-pipeline/SKILL.md` are the source of truth. These prompts are optional shortcuts for human operators; they do not replace the project rules.

## Start a session

```text
Read AGENTS.md and MEMORY.md first. Summarize the current pipeline status, open questions, locked decisions, and the exact files relevant to my request. Do not regenerate completed outputs.
```

## Continue the database pipeline

```text
Continue from MEMORY.md. Identify the first pending Phase 2 deliverable whose prerequisites are complete. Read its direct inputs, produce only that deliverable, validate it, and update MEMORY.md. Do not skip dependencies or modify another owner's placeholder.
```

## Update one file

```text
Update only <path>. Read MEMORY.md and the file's direct inputs first. Preserve locked decisions, record new assumptions/open questions, run the smallest relevant validation, and update MEMORY.md if project state changed.
```

## Test Thien Loc's work on Windows

```powershell
# Backend
cd backend
npm install
npm test
npm start

# In another terminal
Invoke-RestMethod http://localhost:3000/api/health

# SQL Server concurrency runner
$env:DB_SERVER='.\MSSQL2025'
$env:DB_DATABASE='tempdb'
$env:SQLCMD_TRUST_CERTIFICATE='true'
cd ..\outputs\13-concurrency-tests-G06
npm install
npm test

# Generator
cd ..\14-data-generator-G06
python -m unittest discover -s test
python -m src.cli generate --bookings 100000 --seed 48606
python -m src.cli validate
```

## Test with Docker on Fedora or Linux

```bash
export MSSQL_SA_PASSWORD='local-only-password'
./scripts/run-docker-phase2.sh 100000
```

This starts SQL Server 2022 Developer, waits for readiness, runs the concurrency suite, runs generator reproducibility tests, validates generated data, and removes the container. Set `KEEP_CONTAINER=true` when debugging.

## Ask for a review

```text
Review <path> against AGENTS.md, MEMORY.md, and the relevant Phase 2 acceptance criteria. Report concrete defects with file and line references. Do not edit files unless I explicitly ask for fixes.
```

## Important boundaries

- Use synthetic identities only; never add credentials or real personal data.
- Keep generated CSVs, logs, results, `.env` files, and `node_modules` out of Git.
- Parts 13–14 currently use provisional adapters until outputs 09–12 are approved.
- The concurrency runner opens independent SQL Server sessions itself; a second runner terminal is not required.
- When a task changes files, run relevant tests and update MEMORY.md before finishing.