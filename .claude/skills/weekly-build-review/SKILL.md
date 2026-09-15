---
name: weekly-build-review
description: >-
  Superseded on 2026-09-14 by the weekly-plan skill. Kept only so old prompts
  and scheduled tasks that name "weekly-build-review" land somewhere useful:
  it redirects to weekly-plan and does nothing else. Do not run this for a
  build review; run weekly-plan.
model: haiku
---

# weekly-build-review — superseded

This skill produced the ten long build-review notes from 2026-07-06 through
2026-09-08. It was replaced on 2026-09-14 by **`weekly-plan`**
(`.claude/skills/weekly-plan/SKILL.md`), which writes a short dated note in
the same folder plus the machine-readable `docs/plan/week.json` that
`tools/warden.py` dispatches from.

Why it was replaced, in one paragraph: this skill re-derived the repository's
inventory with a model every week, and its own Step 6 audits kept finding the
derived figures wrong — sixteen defects in the 09-08 note, mostly counts and
line numbers. Those facts are now computed by `tools/facts.py` and pinned to
a SHA, GitHub-side facts by `tools/github_state.py` with a `read_at`, and the
model does only what a script cannot: readiness judgment and routing.

**If you were invoked by name:** stop, and run the `weekly-plan` skill
instead. Its references replace `references/inspection-checklist.md` (now
`tools/facts.py`) and `references/note-template.md` (now
`.claude/skills/weekly-plan/references/note-template.md`).

This directory can be removed once nothing references it; the last
scheduled task that did was retired the same day.
