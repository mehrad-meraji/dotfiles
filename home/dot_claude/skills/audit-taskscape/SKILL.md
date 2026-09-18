---
name: audit-taskscape
description: Audit the taskscape obsidian roadmap against the actual code on main, diff against the previous audit, and emit a delta report. Use nightly via cron or on demand.
---

# Audit Taskscape

You are auditing the taskscape project: comparing the roadmap in the obsidian vault against the shipped code, then reporting what's done, what's remaining, and what changed since the last audit.

## Inputs

- **Obsidian roadmap directory:** `/Users/mehrad/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes/Projects/taskscape/`
  - Primary: `weekly-plan-roadmap.md` (the master plan with Phase 1–6 list)
  - Phase implementations: `weekly-plan-phase-0-implementation.md`, `weekly-plan-phase-1a-implementation.md`, `weekly-plan-phase-1b-implementation.md`
- **Codebase:** `/Users/mehrad/Projects/taskscape-app/` (git repo, audit `main` branch)
- **Previous audit state:** `/Users/mehrad/.claude/skills/audit-taskscape/state/last-audit.json` (may not exist on first run)

## Procedure

1. **Read** `weekly-plan-roadmap.md` to refresh the phase list and decisions.
2. **Snapshot the code state.** For each phase item, grep/ls the relevant files and decide: shipped / partial / not started. Use signals like:
   - Migrations in `database/migrations/` (e.g. `weekly_plans`, `plan_entries`, `weekly_objectives`, `add_scheduled_date_to_plan_entries`)
   - Controllers in `app/Http/Controllers/Api/V1/` (PlanEntry, WeeklyPlan, WeeklyObjective)
   - Routes in `routes/api.php` matching `weekly-plans|plan-entries|weekly-objectives|candidate-pool`
   - Components in `resources/js/components/plan/` and pages in `resources/js/pages/plan/`
   - Console commands (e.g. `RollOverWeeklyPlansCommand`)
   - Broadcast events (`grep -rE "broadcast\(.*PlanEntry|WeeklyPlan" app/`)
   - Recurrence column on plan_entries (Phase 6 marker)
   - Slack focus integration (Phase 4 marker)
3. **Capture recent commits** from the taskscape repo: `git -C /Users/mehrad/Projects/taskscape-app log --since="36 hours ago" --oneline main`. List them in the report.
4. **Diff against `state/last-audit.json`** if it exists:
   - Items that flipped not-started → partial → shipped
   - Items that newly became partial (mid-flight)
   - Phases with no movement
5. **Write the new state** to `state/last-audit.json` with this shape:
   ```json
   {
     "audited_at": "ISO-8601 timestamp",
     "head_commit": "<short sha>",
     "phases": {
       "phase_0": {"status": "shipped|partial|not_started", "notes": "..."},
       "phase_1a": {...},
       "phase_1b": {...},
       "phase_2": {...},
       "phase_3": {...},
       "phase_4": {...},
       "phase_5": {...},
       "phase_6": {...}
     },
     "open_items": ["short bullet", ...]
   }
   ```
6. **Compose the email body** as plain text:
   - Subject: `Taskscape audit · YYYY-MM-DD`
   - Body sections:
     - **Since last audit:** commits + status changes (or "no movement")
     - **Phase status:** one line per phase (shipped/partial/not started + 1-line note)
     - **Top open items:** 3–6 bullets, prioritized
     - **Roadmap drift:** if obsidian phase docs have stale unchecked checkboxes for code that shipped, flag it
7. **Update the obsidian vault.** Be conservative — this is the user's source-of-truth notebook, not a scratchpad.
   - **Tick off shipped checklist items** in `weekly-plan-phase-0-implementation.md`, `weekly-plan-phase-1a-implementation.md`, `weekly-plan-phase-1b-implementation.md`. Flip `- [ ]` → `- [x]` ONLY when you have direct code evidence (file exists, route registered, migration applied, component imported). Never flip `- [x]` back to `- [ ]`. If unsure, leave it alone.
   - **Append a status block** to `weekly-plan-roadmap.md` under a `## Audit log` heading (create the heading if missing). Format:
     ```
     ### YYYY-MM-DD
     - HEAD: <short sha>
     - Phase 2: shipped | Phase 3: partial (objectives done, end-of-week review pending) | ...
     - Since last audit: <commits or "no movement">
     ```
     Keep only the **last 14 entries** under `## Audit log` — trim older ones to keep the file bounded.
   - **Write a daily audit note** to `audit-YYYY-MM-DD.md` in the same taskscape vault directory, containing the full audit body (same content as the email). This gives you a browsable history inside obsidian.
   - **Do not modify** any other files: `weekly-plan-phase-1-spec.md`, `taskscape.md`, `ideas.md`, `feature-gaps.md`, `Untitled.md`, anything in `features/` or `docs/`, or anything outside the taskscape directory.
   - If a checkbox edit would change >20 lines in a single phase doc, abort the obsidian update for that file and note it in the email ("audit detected drift in phase-1b doc, manual review needed") rather than mass-editing.
8. **Send via Mail.app** using AppleScript. Compose and send to `mehrad.meraji@gmail.com`:
   ```bash
   osascript <<'APPLESCRIPT'
   tell application "Mail"
     set newMessage to make new outgoing message with properties {subject:"<SUBJECT>", content:"<BODY>", visible:false}
     tell newMessage
       make new to recipient at end of to recipients with properties {address:"mehrad.meraji@gmail.com"}
     end tell
     send newMessage
   end tell
   APPLESCRIPT
   ```
   Escape backslashes, quotes, and `$` in the body before substituting. Prefer writing the body to a temp file and reading it from AppleScript with `read POSIX file "..."` to avoid escaping pain.

## On first run

`state/last-audit.json` won't exist. Skip the diff section, just emit the full snapshot and note "(first audit — no prior baseline)".

## On error

If the obsidian directory is unreachable (iCloud not synced, etc.), still send an email noting the failure rather than silently dying. If the taskscape repo has uncommitted state on `main`, mention it.

## Constraints

- This skill runs non-interactively from cron. Do not ask the user questions. Make reasonable defaults.
- Keep the email under ~60 lines. The point is a quick glance, not the full audit.
- Do not modify the taskscape repo. Read-only.
- Obsidian writes are limited to the files listed in step 7. Conservative-only: tick boxes, append audit log entries, write the daily audit note. Never delete, reorder, or rewrite existing prose.
