---
name: weekly-plan
description: >-
  Write this week's Wildlife Crossing plan: a build-readiness verdict and a
  routed list of work items (lane, model, mode) as docs/plan/week.json plus a
  short dated note in obsidian-vault/build-reviews/. Use when asked for the
  "weekly plan", "build review", "what's left for the next build", "plan the
  week", or when the Monday routine fires. Reads facts from
  tools/facts.py and tools/github_state.py; never re-derives them.
model: sonnet
---

# Weekly plan

You are planning one week of work on **Wildlife Crossing** (Godot 4.6 /
GDScript). You produce two things that describe the same week:

1. `docs/plan/week.json` — the routed plan `tools/warden.py` dispatches from.
2. `obsidian-vault/build-reviews/YYYY-MM-DD-next-build.md` — a **short**
   note (target 100 lines, hard cap 150) answering one question: *what work
   must be done to produce the next working build, and who does each piece?*

Run this with **Sonnet**. The facts are pre-computed; your job is routing and
readiness judgment. Opus is for a large re-plan only.

## Ground rules

- **Facts come from files. You never recount.** `docs/plan/facts.json` is the
  inventory of the tree at a SHA; the freshest of `docs/plan/github-state.json`
  and `docs/github-state.json` is GitHub at a `read_at`. Every figure in the
  note cites one of those or is labelled Assumed / Unverifiable. If a fact you
  need is missing from `facts.json`, say so in the note and propose adding it
  to `tools/facts.py` as an item — do not derive it by hand.
- **No line-number citations.** Cite files and headings (`docs/roadmap.md
  §Phase 1 exit criteria`), never `:123`. Three consecutive reviews named
  stale line numbers their largest error category; the fix is not to write
  them.
- **Read, then write, once.** One note, one plan, one commit plan. Do not
  modify game code, docs, or other vault notes.
- **Ids are stable.** An item carried from last week keeps its id. New items
  take the next free number in their series (`docs/plan/routing.md` §Ids).
- **Cozy, honest tone.** Setbacks are interesting; blockers are still blockers.
- **Never run a git command that takes a lock** when the repository is a
  Cowork mount (add, commit, checkout, stash, pull). In a cloud routine with
  the repository attached, commit and push per §Step 6.

## Procedure

### Step 0 — Refresh the facts

Run, from the repository root:

```
python3 tools/facts.py
```

If `gh` is available (a cloud routine with the repository attached, or the
Mac), also run `python3 tools/github_state.py --output docs/plan/github-state.json`.
If it is not, run it with `--curl` (unauthenticated; works from the Cowork
device VM). If both fail, use the tracked `docs/github-state.json` and say in
the note how old it is. Then read `docs/plan/facts.json` in full and the
github-state file's `reads` values for `open_pull_requests`,
`recent_merged_pulls`, `latest_main_run`, `artifacts`, `releases`, and
`ruleset_drift`.

### Step 1 — Read the record

1. `docs/plan/routing.md` — the rubric you will apply.
2. The previous `docs/plan/week.json`, if any. Its items are your starting
   list. If none exists, the newest note in `obsidian-vault/build-reviews/`
   is; its §3 items (`B…`, `C…`, `V…`) and its amendment callouts are the
   record, and the amendments close items the body still lists.
3. Every `obsidian-vault/daily-logs/` note dated after the previous plan (or
   the previous review), for closures, decisions, and the `## Next session`
   ordering.
4. `docs/roadmap.md` — only the current phase's **Exit criteria** and any
   `Decision logged` blocks under it. `facts.build_case` says which phase.
5. `docs/plan/queue/log.jsonl`, if present — what was dispatched and what it
   produced.

### Step 2 — Reconcile

For each carried item decide **done / open / blocked / dropped** with one
piece of evidence each:

- A merged pull request whose head branch carries the item's id
  (`recent_merged_pulls` in github-state) → done.
- A daily log or review amendment saying it closed, naming a commit → done
  (cite the note).
- Dependencies not done → blocked.
- Superseded by a decision → dropped, with the decision cited.

Then add new items **only** from these sources: an unmet exit criterion of
the target phase; a failure `facts.json` reports (`data_files_invalid`,
`stub_scripts`, `uid_orphans`, `required_contexts_match_jobs: false`,
`scripts_without_named_test`); a `latest_main_run` that is not `success`;
`ruleset_drift.in_sync: false`; an open question in a daily log that names
work. Do not invent work from taste.

### Step 3 — Readiness

State the build case from `facts.build_case` and say what the verdict rests
on. `ready` means every item with `blocker: true` is done and
`latest_main_run` is `success` on the measured SHA. Otherwise `not-ready`,
with the open blockers listed. One paragraph.

### Step 4 — Route every open item

Apply `docs/plan/routing.md`. For each item fill every field in
`docs/plan/README.md` §week.json. Acceptance criteria are checkable
statements; a criterion a pull request cannot show evidence for is not one.
`files` lists real paths; if a path is on the forbidden list, the item is
`mode: supervised` at most, never `auto` (`warden` refuses the plan
otherwise). Split any `L` that is not human. Order by
`priority`: blockers first, then the shortest path to the exit criteria, then
verification, then drift. The plan holds **every** open item between the
tree and the target build, in that order — it is the backlog as well as the
week — and the dispatch only ever picks from the top of it, two code items
in flight at a time. The week's focus is the first eight or so; say which in
the note.

### Step 5 — Write

1. `docs/plan/week.json` per the schema. `measured_against.head_sha` is
   `facts.measured_against.head_sha`; `github_state_read_at` is the state
   file's `read_at`.
2. The note, from `references/note-template.md`. Front matter per
   `obsidian-vault/CLAUDE.md`. Link the previous note and the plan file.
3. One line at the top of the list in `obsidian-vault/build-reviews/README.md`
   (newest first), under 400 characters.
4. A commit plan at the repository root, `commit-plan-YYYY-MM-DD-plan.json`,
   for `tools/ship.py`: branch `docs/plan-YYYY-MM-DD`, one commit
   `docs(plan): week of YYYY-MM-DD`, paths: the three files above. If
   `docs/github-state.json` was refreshed deliberately (`--tracked`), claim it
   too. Nothing else may be dirty; if it is, say so and leave it unclaimed.

### Step 6 — Verify, then land

- `python3 tools/warden.py day --no-write` must run clean. It validates the
  plan's shape and prints the first dispatch; read it and check it is the
  week you meant.
- `python3 tools/ship.py commit-plan-YYYY-MM-DD-plan.json --allow-branch-mismatch`
  (dry run) must account for every changed path.
- Every item id in the note exists in `week.json`; every path in the note
  exists in the tree (or is marked *new*); the note is under 150 lines.
- Label the `## Verification` section: **Confirmed** (read from `facts.json`
  at its SHA, or from github-state at its `read_at`), **Assumed** (carried
  from a log or review), **Unverifiable** (nothing this run could read — CI
  on an unpushed tree, whether an export launches).

**In a cloud routine** (the repository is a clone, `gh` works through the
proxy): configure the identity ADR 0019 requires and land the plan as a pull
request —

```
git config user.name "Brent Humphries"
git config user.email "brent.humphries@gmail.com"
git checkout -b claude/plan-YYYY-MM-DD
git add docs/plan/week.json obsidian-vault/build-reviews/
git commit -s -m "docs(plan): week of YYYY-MM-DD" -m "<two sentences: verdict and headline>" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
git push -u origin claude/plan-YYYY-MM-DD
gh pr create --title "docs(plan): week of YYYY-MM-DD" --body-file <a file with the note's §1 and §3>
```

Do not merge. The operator reads the note and merges with
`tools/warden.py merge <n>`.

**In a Cowork or Claude Code session on the Mac**: stop after Step 6's dry
run and say: *"Ready — `tools/warden land commit-plan-YYYY-MM-DD-plan.json`."*

## Deliver

Three sentences: the build case and verdict, the number of items by lane
(`N code, N docs, N yours`), and where the note is.

## Not this skill's job

- The project-state dashboard. Retired 2026-09-14; `tools/warden.py status`
  and `day` replace it.
- The daily queue. `tools/warden.py day` derives it from `week.json` with no
  model, so it cannot drift from GitHub.
- Editing the plan mid-week. Monday's document stands; what happened is in
  GitHub and `queue/log.jsonl`, and next Monday reads both.
