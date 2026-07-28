---
name: weekly-build-review
description: >-
  Run a weekly build review of the Wildlife Crossing project and produce a dated
  Obsidian note describing the work needed to reach the next working build (or
  the first working build if none exists yet). Use when asked for a "weekly
  review", "build review", "what's left for the next build", "what do we need to
  ship", or when a scheduled weekly review fires. Reconciles actual repo state
  against the roadmap, ADRs, and checklists, then writes a prioritized,
  buildable task list.
model: opus
---

# Weekly Build Review Harness

You are the primary builder on **Wildlife Crossing** (Godot 4.6 / GDScript
habitat-corridor simulation). This skill runs a repeatable **weekly build
review**. Its single deliverable is one Obsidian note that answers exactly one
question:

> **What work must be done to produce the next working build of the game — or
> the first working build, if none exists yet?**

Run this with the **Opus model**. The review is analysis-heavy and cross-cuts
the whole repo, so accuracy and judgment matter more than speed. Do not
downgrade the model.

The note must be grounded in the *actual current state of the repo*, not in what
the planning docs assume. The docs drift (e.g. `pre-build-checklist.md` was
written when `game/` was mostly `.gitkeep`; that is no longer true). **Reconcile
docs against reality every time** — flagging that drift is one of this review's
main jobs.

---

## Ground rules

- **Read before writing.** Load the root `CLAUDE.md` and every scoped
  `CLAUDE.md` relevant to what you inspect (`game/`, `docs/`, `obsidian-vault/`,
  `website/`). Follow the project's conventions exactly.
- **Evidence over assumption.** Every claim in the note ("X is done", "Y is
  missing", "tests fail") must trace to something you actually observed — a
  file, a git diff, a test run, an export attempt. No guessing.
- **Cozy, honest tone.** Match the project's north star: setbacks are
  interesting challenges, not alarms. But do not soften real blockers.
- **One note per run.** Do not scatter output. Everything goes in the single
  dated note described under *Output*.
- **Do not modify game code or docs** during a review. This skill only reads,
  runs tests, and writes the review note (plus updating the build-reviews index).

---

## Definition of "working build"

Use these definitions, in priority order:

1. **First working build (if none exists).** The **first playable / P0**, which
   the docs define as roadmap **Phases 1–2** (core simulation + overpass
   validation, then location selection + sub-areas). A "working build" means the
   Godot project exports to a runnable desktop binary, launches to the main
   scene, and satisfies the exit criteria of the target phase(s). There is a
   working build only if you can point to an actual export in `builds/` or a
   GitHub Release **and** it launches.
2. **Next working build (if one exists).** The next roadmap milestone after the
   most recently shipped one. Target its exit criteria (see `docs/roadmap.md`
   §"Exit criteria" per phase) and any release-note follow-ups.

Determine which case you are in during Step 2 below — never assume.

---

## Procedure

Set the objective explicitly at the start. If `/goal` is available, use it:
`/goal Produce this week's Wildlife Crossing build-review note identifying every
task needed for the next/first working build.` Otherwise state the goal in your
first message and hold to it.

### Step 0 — Orient (what changed since last week)

1. Read root `CLAUDE.md`, `docs/roadmap.md`, `docs/pre-build-checklist.md`,
   `docs/test-plan.md`, and `docs/testing-setup.md`.
2. Read the **most recent** note in `obsidian-vault/build-reviews/` (if any).
   This is last week's review — you are producing a *diff* against it. Note
   which of its items are now done, still open, or newly obsolete.
3. `git log --oneline` since the date of the last review note (or last 20
   commits if this is the first review). Skim recent `obsidian-vault/daily-logs/`
   entries for intent behind the changes.

### Step 1 — Inventory actual repo state

Delegate the breadth-first inventory to a subagent so the main thread stays
focused. Launch an **Explore** (or **general-purpose**) subagent with the task
described in `references/inspection-checklist.md`. It should report, with file
paths as evidence:

- Which of the ~13 systems, plus `world_data` / `hex_grid` / `pathfinding`,
  actually exist in `game/scripts/` and are non-stub.
- Which data files in `game/data/` exist and are valid JSON
  (`tiles`, `species_stats`, `entities`, `segments`, `infrastructure`,
  `milestones`, `sub_areas`, `biome_groups`).
- Which scenes exist in `game/scenes/` and whether `Main.tscn` wires the
  autoloads from `project.godot`.
- Which GUT test files exist in `game/tests/` and which systems have **no**
  test.
- Whether CI exists (`.github/workflows/`) and what it runs.
- Whether any build/export exists (`builds/`, `export_presets.cfg`, GitHub
  Releases).

### Step 2 — Run the tests and attempt a build signal

Follow the project's test setup (see the `wildlife-crossing-test-setup` memory
and `docs/testing-setup.md`):

- Run the GUT suite headless with the vendored Godot 4.6 binary at
  `tools/godot/` against `game/` (config: `game/.gutconfig.json`, tests in
  `game/tests/`). Capture pass/fail counts and any failures. Watch for the
  warnings-as-errors pitfall noted in memory.
- Attempt an editor import / headless open of the project to surface load
  errors (missing autoloads, broken `.tscn`, parse errors). If an
  `export_presets.cfg` exists, attempt a headless export to confirm a binary
  can be produced; if not, record "no export path yet" as a finding.
- Decide the case (first build vs next build) from Step 1–2 evidence and state
  it explicitly in the note.

### Step 3 — Gap analysis (the core of the review)

Compare **target** (Step "Definition" + roadmap exit criteria for the relevant
phase) against **actual** (Steps 1–2). For each gap, produce a work item. If the
gap analysis is large or interdependent, spin up a **Plan** subagent to sequence
it, then review its output yourself.

Every work item must be **buildable** — specific enough to hand to a developer —
and include:

- **Title** — imperative, e.g. "Add export_presets.cfg for desktop targets".
- **Why it blocks the build** — tie to a roadmap exit criterion, ADR, or a
  concrete failure observed in Step 2.
- **Files/areas touched** — real paths.
- **Acceptance criteria** — how you'll know it's done (often a test or an
  observable in-game behavior).
- **Dependencies** — which other items must land first.
- **Rough size** — S / M / L.
- **References** — roadmap phase, ADR number(s), PRD section, or doc.

Also capture, separately:

- **Doc drift** — every place the planning docs no longer match reality (e.g.
  the pre-build-checklist's "game/ is almost entirely .gitkeep" is stale). List
  the doc, the stale claim, and the correction. Do **not** edit the docs here;
  just record so the owner can fix them.
- **Risks / open questions** — anything ambiguous that needs an owner decision
  before it can be built (link `docs/p0-open-questions.md` style items).

### Step 4 — Prioritize and sequence

Order the work items into: **Blockers** (nothing ships until these exist) →
**Core build work** (the exit-criteria tasks) → **Verification** (tests, CI,
export) → **Nice-to-have / deferrable**. Number them in the order you'd
actually do them, respecting dependencies. If `/loop` is available and gaps are
still fuzzy, iterate the gap list to convergence before finalizing.

### Step 5 — Write the note

Write **one** note to
`obsidian-vault/build-reviews/YYYY-MM-DD-next-build.md` using
`references/note-template.md`. Fill every section from your evidence. Use the
project's Obsidian front-matter convention (title, date, tags, status) and
`[[wikilinks]]` / relative links to related notes (roadmap, ADRs, the previous
review). Then add a one-line pointer to
`obsidian-vault/build-reviews/README.md` (newest first).

### Step 6 — Verify (do not skip)

Before declaring done:

- Re-read the note against this checklist: Is the build case (first vs next)
  stated and justified? Does every "done/missing" claim cite evidence? Is every
  work item buildable with acceptance criteria? Are items sequenced with
  dependencies? Is doc drift captured?
- Confirm front-matter YAML is valid and every link resolves to a real file.
- For a high-stakes or unusually large review, launch a fresh **general-purpose**
  subagent to red-team the note: "Given the actual repo state, is anything
  needed for the next build missing from this list, and is anything listed
  actually already done?" Fold in its corrections.

Deliver the note path to the user with a two-sentence summary: the build case
and the number of blockers. Then present the note file.

---

## Capabilities this harness uses

- **Opus model** — set via this skill's `model: opus`; keep it for the whole run.
- **`/goal`** — pin the review objective up front (Step "Procedure" intro).
- **`/loop`** — converge the gap list in Step 4 when items are still fuzzy.
- **Subagents** — Explore/general-purpose for the Step 1 inventory, Plan for
  Step 3 sequencing, general-purpose for the Step 6 red-team. Delegating keeps
  the main thread's context clean for judgment.
- **Bash + vendored Godot** — headless test run and export signal in Step 2.

## Running it weekly (optional)

This is a standalone skill invoked on demand. To automate it, create a scheduled
task (weekly, e.g. Monday 07:00) whose prompt is simply: *"Run the
weekly-build-review skill for Wildlife Crossing."* The skill handles the rest
and writes that week's dated note.
