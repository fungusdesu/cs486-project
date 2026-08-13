# Phase 2 workflow

Use this reference for outputs `08` through `16`, Part 13 concurrency tests,
and the Part 14 procedural data generator. Treat
`reference/CS486_Project_Phase02.pdf` as the assignment source and `TODO.md`
as the live source for ownership, dependencies, and status.

## Contents

- Dependency and ownership gates
- Parts 13 and 14
- Evidence and final review

## Dependency and ownership gates

Before editing a Phase 2 artifact:

1. Read `MEMORY.md`, list `outputs/`, and read `TODO.md`.
2. Read the relevant assignment section and target artifact.
3. Read the direct predecessor artifacts in the approved Phase 2 plan.
4. Confirm the owner and current status.
5. Treat file presence as existence only, never as completion evidence.

Use this high-level order unless `TODO.md` records a newer approved plan:

`08 -> 09 -> 10 -> 11 -> 12 -> 13`

Part `14` requires the final schema from `09`-`10`. Part `16` requires
the final schema and approved reporting requirements. Part `15` requires the
large validated dataset and final queries it measures. The final report and
review require all claimed artifacts and retained evidence.

For outputs other than Parts 13 and 14, follow the assignment and `TODO.md`
directly. Do not copy their ownership or detailed procedures into this skill.
Do not implement another contributor's deliverable unless explicitly asked.

An explicit scaffold-only override permits preparatory work before a
predecessor is approved. Label schema or procedure mappings provisional and do
not claim integration or completion.

## Part 13 - Concurrency tests

- Path: `outputs/13-concurrency-tests-G06/`
- Owner: user
- Final dependencies: approved outputs `09`-`12`

Until the final protected operation from output `12` is approved, allow only
reproducible scaffolding, isolated fixtures, and provisional adapters.

### Required implementation

- Document prerequisites, setup, one-command execution, expected results,
  cleanup, and exact environment or configuration.
- Use at least two independent SQL Server connections or processes. An
  in-process mutex is not a concurrency solution.
- Test overlapping instant-versus-instant, instant-versus-staff, and
  staff-versus-staff approval attempts.
- Test non-overlapping and boundary-adjacent requests that should both succeed.
- Test advisory maintenance with acknowledgement, out-of-service maintenance
  blocking an overlap, and advisory escalation identifying affected approved
  bookings.
- Assert final database state, not only messages or return codes.
- Repeat race-sensitive cases enough times to support the conclusion.
- Keep unsafe demonstrations isolated from the real schema and clean up every
  fixture and object.
- Retain machine-readable results and a concise Markdown evidence table with
  outcomes, elapsed time, approved count, fixture ID, repetition count, and
  environment versions.

### Completion gate

Mark Part 13 done only when a clean migrated database can reproduce the suite
against the final protected operation, the isolated unsafe race is
demonstrated, at most one conflicting approval succeeds, and legitimate
non-conflicting requests are not unnecessarily blocked.

Passing isolated fixtures proves the runner, not final production integration.

## Part 14 - Procedural data generator

- Path: `outputs/14-data-generator-G06/`
- Owner: user
- Final dependencies: approved outputs `09`-`10`
- Accepted benchmark: 500,000 booking requests, 10,000 users, 100 spaces,
  2,500 maintenance rows, seed `48606`

Until the final schema is approved, keep production mappings and load claims
provisional.

### Generator requirements

- Provide a seeded Python CLI with documented `generate`, `validate`, `load`,
  and `clean` commands.
- Support at least 100,000 bookings and a configurable 500,000-booking run.
- Cover at least three academic years through a documented, configurable term
  calendar and use synthetic identities only.
- Reuse a realistic smaller user population across bookings.
- Use lazy generators or iterators and streaming CSV output. Do not retain the
  full dataset in memory, recurse per row, or emit one `INSERT` per row.
- Generate parent or staging data before dependent data.
- Include meaningful non-zero distributions for pending, approved, rejected,
  and instant approvals; cancellations; no-shows; maintenance impacts; and
  booking-level advisory acknowledgement flags.

### SQL Server load requirements

- Provide staging, bulk-load, validation, set-based transformation, final
  validation, and cleanup scripts.
- For the G06 adapter, run:
  `create-staging.sql -> bcp -> validate.sql -> load-final.sql -> validate-final.sql`.
- Make the final transformation transactional and rerunnable for staged
  synthetic keys.
- Validate final row counts, approved-slot uniqueness, acknowledgements, and
  database size.
- Target the `School` database created and migrated by outputs `05` and `10`.

### Configuration and secret handling

- Read connection values from `DB_SERVER`, `DB_DATABASE`, `DB_USERNAME`, and
  `DB_PASSWORD`.
- Permit the ignored local `.env` to provide defaults without external
  packages, but never override variables exported by the parent shell.
- Never print, commit, or retain passwords. Redact them from dry runs and
  evidence.
- On Linux or Fedora, require username and password authentication. Never fall
  back to `sqlcmd -E`, `bcp -T`, or another Windows-integrated mode.
- Apply trust-certificate behavior consistently to `sqlcmd` and `bcp`; fail
  before subprocess execution when configuration is incomplete.

### Validation and evidence

- Validate requested versus generated counts, duplicate IDs, foreign keys,
  required values, time ranges, approved-slot uniqueness, academic-year
  coverage, declared distributions, and same-seed reproducibility.
- Validate the 500,000-booking run with bounded memory.
- Record seed, configuration, Python or runtime versions, counts by table and
  status, generated size, generation time, staging-load time, final-load time,
  and database size when available.
- Keep generated CSVs, logs, validation files, load evidence, and credentials
  out of version control unless a sanitized assignment artifact is explicitly
  required.

### Completion gate

Mark the generator implementation done only when another group member can
reproduce a clean load using committed code and documentation and all declared
validation checks pass.

Keep server execution as a separate claim. Generation plus bounded-memory
validation proves the generator; static SQL review proves neither staging nor
the final load. Claim a final server load only after successful staging bulk
load, `load-final.sql`, `validate-final.sql`, and retained credential-free
evidence.

## Evidence and final review

After all Phase 2 deliverables are complete:

- trace every requirement through design, migration, tests or generator,
  queries, tuning, and retained evidence;
- reproduce Parts 13 and 14 from a clean database using committed commands;
- confirm generated data is synthetic, seeded, size-compliant, referentially
  valid, and distribution-compliant;
- confirm concurrency evidence targets the final protected operation and
  unsafe fixtures cannot affect production data;
- run final backend, migration, load, analytical-query, and tuning checks
  supported by the delivered interfaces;
- record unresolved questions, limitations, environment details, and follow-up
  work without overstating completion.

Append a dated one-line review result to `MEMORY.md` and mark only verified
work done.
