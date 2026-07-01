# Prompts for cs486-demo

> See `md/setup.md` for per-tool installation/launch notes (Antigravity,
> OpenCode, Codex CLI, OpenClaw).
> The prompts below work the same way in all of them, since they all funnel
> through AGENTS.md → MEMORY.md → the db-design-pipeline skill.
>
> The actual step-by-step pipeline logic (what counts as "done," required
> templates, prerequisite checks) lives in
> `.opencode/skills/db-design-pipeline/SKILL.md` (canonical copy, synced to
> `.openclaw/` via `scripts/sync-skills.sh`). AGENTS.md and
> MEMORY.md tell the agent to read MEMORY.md and follow that skill; you
> usually don't need to repeat pipeline details in your prompts — just say
> which file/step you want.

## 0. One-time setup prompt (run once, after adding AGENTS.md + MEMORY.md)

Paste this the very first time you open the project in Antigravity:

---
Read AGENTS.md and MEMORY.md fully before doing anything.

Fill in the group number and confirm the DBMS in both files based on what
I tell you: Group number is G##, DBMS is Microsoft SQL Server (unless I say
otherwise).

Then read req/business-requirement.md and produce ONLY
outputs/01-business-req-analysis-G##.md, following the workflow order and
design rules in AGENTS.md.

After you finish, update MEMORY.md: mark step 1 as done, record any
assumptions you made, and record any open questions you have about the
requirement instead of guessing. Do not proceed to step 2 yet — stop and
wait for me.
---

## 1. Reusable session-starter (paste at the start of every later session)

---
Read MEMORY.md first. Tell me in 3-5 bullets: current pipeline stage, what's
done, what's open/needs revision, and any open questions waiting on me.
Then wait for my instruction — do not generate anything yet.
---

This costs very little context and stops the agent from re-reading every
prior output file or re-deriving decisions you already locked in.

## 2. "Continue the pipeline" prompt

---
Continue from MEMORY.md. Generate only the next pending file in the
pipeline, using the prior outputs already in outputs/ as your source of
truth — do not regenerate them. Follow AGENTS.md design rules. Update
MEMORY.md when done (status, new assumptions, new open questions).
---

## 3. "Fix one file" prompt (cheapest, most common during revision)

---
Update only outputs/<filename>. Reason: <what's wrong, e.g. "ERD is missing
the many-to-many between Student and Course">.
Do not touch any other output file. Do not change locked decisions in
MEMORY.md unless this fix requires it — if it does, tell me before changing
them. Update MEMORY.md's status row for this file when done.
---

## 4. "Answer my open question" prompt

When you want to resolve something the agent flagged in MEMORY.md's
"Open questions" section:

---
Re: open question "<paste the question>" in MEMORY.md — the answer is:
<your answer>.
Record this as a locked decision in MEMORY.md, remove it from open
questions, and apply it to <filename(s)> if those files already exist.
---


- AGENTS.md is read automatically by Antigravity every session — it holds
  rules that never change (workflow order, output paths, DBMS).
- MEMORY.md is NOT automatic by default, so AGENTS.md explicitly tells the
  agent to read it first and update it last. This is your real "save
  state" — cheaper than Antigravity re-reading 7 output files or
  re-deriving the ERD from the requirement doc every time.
- Antigravity also auto-generates its own Knowledge Items from past
  conversations, but MEMORY.md gives you an explicit, human-editable
  version you fully control rather than relying on automatic extraction
  catching the right details.
- Each prompt template names ONE file or ONE action — matching the
  teacher's own cost-control advice ("update only the specific file or
  section that needs improvement").
