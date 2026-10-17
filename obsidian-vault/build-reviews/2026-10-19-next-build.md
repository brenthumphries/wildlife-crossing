---
title: "Build Review — Next Build (2026-10-19)"
date: 2026-10-19
tags: [build, review, planning]
status: active
---

> Weekly plan. One question: what work must be done to produce the next
> working build, and who does each piece? The routed plan is
> [`docs/plan/week.json`](../../docs/plan/week.json); `tools/warden.py day`
> dispatches from it.

> [!success] Amendment 2026-10-16 (evening) — **Q9 is decided, and Q10 stays open.**
> Brent accepted the seasonal rules in Q9 with one change: elk and pronghorn are
> present all year, with migration spikes in spring and fall only. The grizzly is
> the only species absent in a season (winter). The rest of Q9 stands: both
> migration patterns migrate in spring and fall at 1.5 times, winter clears river
> hazard, spring widens it by one tile. The decision is in the Phase 4 Decision
> logged block of `docs/roadmap.md`. C37 now builds an absence table for the
> grizzly only. C37 already says to follow the logged answer and C38's 1.5 is unchanged, so
> `week.json` is unchanged and still lists Q9 as open. Q10 is not decided: Brent
> will call a fixed freeze date after the features he wants are merged and
> walked. The plan itself landed as #70 (`49ac737`). See [[../daily-logs/2026-10-16]].

> [!success] Amendment 2026-10-17 — **C19 to C22, C24, C25, C28, C32 and V12 to V14 are closed.**
> Eleven pull requests merged, #72 to #82, between 2026-10-16 19:30 and
> 2026-10-17 09:57 (-0500). `TextScale` and the HUD, Info panel, credits, confirm
> panel, title menu and both minigames moved onto it (C19 to C22). The live world
> renders at segment zoom and takes segment clicks (C24, C25), corridor-study
> hotspots are ringed in build mode (C28), and the trickle pays below the
> cheapest buyable crossing tile (C32). The two minigame scripts have named tests
> (V12), `build_mode_test.gd` casts the registry cost to int (V14; the warning's
> removal is unconfirmed in CI), and `warden merge` removes the item's worktree
> first (V13). Suite 31 / 379 / 6,629 to 34 / 475 / 7,092. `week.json` is
> unchanged; `warden status` derives 26 done, 15 open and 20 blocked. The
> dispatch's only code pick is C26; C23, C27, C33, C41, C29 and C30 queue behind it
> on the suite-figure line. Q9 still shows open in `week.json`. See
> [[../daily-logs/2026-10-17]].

> [!info] Snapshot
> Measured against **`6ddeb4e`** (*Merge pull request #69 from brenthumphries/docs/log-2026-10-16*,
> 2026-10-16T16:58:19-05:00) on `main`, via `docs/plan/facts.json`.
> GitHub read 2026-10-16T22:05:05+00:00 via `gh`. Suite as stated in
> `docs/testing-setup.md` and checked by CI: **31 scripts / 379 tests / 6,629
> asserts**. Latest run on `main`: **success** on `6ddeb4e` at
> 2026-10-16T21:58:23Z. Previous plan: [[2026-10-16-next-build]].
> Written early: Friday 2026-10-16 for the week of 2026-10-19, at Brent's
> request, so he can use a reset token budget from Saturday to Tuesday. This is a
> new week's plan, not another mid-week edit; the earlier notes stand.

## 1. Readiness

**Build case: next.** v0.1.0 is published. B7 still blocks: the Windows and
Linux launch checks wait for a machine (Linear ATT-62). Phase 3's code is
complete. Brent decided on 2026-10-16 to go big for v0.2.0: Phase 2 completion,
text size, Phase 4 seasons and Phase 6 milestones, with Phase 5 held behind the
cultural-advisor review, a feature freeze and one stabilization pass. This plan
routes all of it.

**Verdict: not-ready.** Open blockers: B7.

## 2. What changed since 2026-10-16

- **Landed:** PR #63 to #69, ending with the 2026-10-16 log. From
  `recent_merged_pulls`.
- **Closed:** C14, C15, C17, C18 (merged); Q3, Q5, Q6, Q7, Q8 (decided). Carried
  as done: Q1, Q4, C12, C13, C16, D3.
- **New facts:** nothing in `facts.json` beyond the two
  `scripts_without_named_test` (V12).
- **Decisions:** 2026-10-16, Brent: Q5 (Info panel on `I`), Q3 and Q6 (text size
  and its settings), Q7 (trickle at the cheapest crossing tile), Q8 (v0.2.0
  scope and the freeze). Recorded in the Phase 3 Decision logged blocks of
  `docs/roadmap.md` ([[2026-10-16]]).

## 3. This week

The first 24 of 46 open items, in order. The rest follow the table.

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | B7 | Walk the Windows and Linux halves of runbook A8 on clean machines | mac | human | S | none |
| 2 | Q9 | Confirm the seasonal presence, migration and terrain rules | decision | human | S | none |
| 3 | C19 | Add TextScale: named text sizes and a live scale step | code | sonnet / auto | S | none |
| 4 | C24 | Make the world map render the live world at segment zoom | code | opus / supervised | M | none |
| 5 | V13 | Make warden merge survive a worktree on the item's branch | code | sonnet / supervised | S | none |
| 6 | V12 | Name a test for the two minigame scripts or exempt them | verify | sonnet / auto | S | none |
| 7 | C28 | Mark corridor-study hotspots on the map in build mode | code | sonnet / auto | M | none |
| 8 | C32 | Pay the trickle below the cheapest crossing tile, not the cheapest information product | code | haiku / auto | S | none |
| 9 | C20 | Rebuild the HUD layout on containers and TextScale | code | sonnet / auto | M | C19 |
| 10 | C21 | Move the Info panel, credits and confirm panel onto TextScale | code | sonnet / auto | M | C19 |
| 11 | C25 | Route segment-mode clicks to the picker and the confirm panel | code | sonnet / supervised | M | C24 |
| 12 | C26 | Highlight the hovered segment on valid tiles only | code | sonnet / auto | M | C25 |
| 13 | C22 | Move the title menu and both minigames onto TextScale | code | sonnet / auto | M | C19, V12 |
| 14 | C23 | Add the text-size setting: title option, Ctrl+= and Ctrl+- | code | sonnet / auto | M | C19, C20, C21, C22 |
| 15 | C27 | Add the on-screen toolbar with Add crossing and Info | code | sonnet / auto | M | C19 |
| 16 | C33 | Add TimeController: pause, 1x, 2x and 4x | code | sonnet / auto | S | none |
| 17 | C35 | Add SeasonManager: the clock, seasons and season_changed | code | sonnet / auto | M | C33 |
| 18 | C37 | Make species absent in their off-season | code | sonnet / auto | M | C35 |
| 19 | C34 | Add the TimeControls HUD widget and keys | code | sonnet / auto | S | C33, C20 |
| 20 | C36 | Add the season calendar to the HUD | code | sonnet / auto | S | C35, C20, C37 |
| 21 | C38 | Raise crossing attempts in a species' migration season | code | sonnet / auto | M | C37 |
| 22 | C39 | Add seasonal terrain: rivers freeze in winter and flood in spring | code | opus / supervised | M | C35 |
| 23 | C40 | Autosave on each season change and add Continue to the title menu | code | sonnet / auto | M | C35, C23 |
| 24 | C41 | Add MilestoneTracker: first-crossing milestones and the capstone | code | sonnet / auto | M | C32 |

Later in the plan, in order: C42, C43, C29, C30, C31, V14, D5, V3, D6, D1, Q2, D4, V15, V16, V17, V18, Q10, V19, D8, D7, B9, V5.

The 46 open items are 27 code, 1 verify, 7 docs and
11 yours. The dispatch picks C19 and V14 first; V13, C24, C25, C39 and D5 are
supervised sessions. Every code item that adds a GUT test edits the single suite-figure line in
`docs/testing-setup.md`, so the dispatch runs those one at a time.

### Yours this week

- **Q9.** Confirm the seasonal rules in the item (grizzly absent in winter, elk
  and pronghorn absent in winter, migration seasons spring and fall at 1.5 times,
  winter freezes rivers, spring widens them). C37 to C39 do not wait for it.
- **Q10.** Call the feature freeze when the features you want are merged and
  walked.
- **Walks.** V15 (text sizes), V16 (Phase 2), V17 (seasons), V18 (the first-play
  loop), then V19 (the stabilization pass after the freeze).
- **Release.** D7 drafts the notes; B9 cuts v0.2.0 on the Mac, after B7.
- **Q2, V5, B7.** Unchanged.
- **Supervised sessions.** `tools/warden run <id> --interactive`.

## 4. Drift and risks

- **The scope is larger than four days of merges.** 46 open items, most of them serialised by the shared suite-figure line, is more
  than a long weekend. The order puts text size and Phase 2
  first, then seasons, then milestones; whatever is not merged by Tuesday night
  carries into the next plan, and the freeze waits for it.
- **Seasons touch the simulation core.** C35 gives the clock one owner, C39 changes
  terrain, pathing and mortality. C39 is opus and supervised, writes an ADR, and is
  narrowed to hazard changes only; read the ADR before merging.
- **The freeze approach concentrates risk.** With no release candidates per phase,
  a late problem blocks the release. V15 to V18 are the early warning.
- **Larger text moves layout.** C20 replaces the fixed HUD positions; V15 is the
  real check.
- **A release needs Brent and the Mac.** B9 uses his Apple identity and keys.

## Verification

- **Confirmed** (`facts.json` at `6ddeb4e`; github-state at 2026-10-16T22:05:05+00:00):
  `latest_main_run` success, zero open pull requests, suite figure as stated,
  tag `v0.1.0`, `scripts_without_named_test` listing two scripts.
  `tools/warden.py day --no-write` validates the plan.
- **Read from the tree this run** (not in `facts.json`): the controller's opaque
  backdrop and click guard, the hard-coded HUD positions, the literal font
  sizes, `Simulation.time_scale` with no owner, the stub `milestone_bonus()`,
  `milestones.json` and the species `seasonal_pattern` values.
- **Assumed** (carried from [[2026-10-16]]): Brent's decisions in chat and his
  windowed walk of the Info panel.
- **Unverifiable** this run: that C24's and C39's proposed designs work; that any
  item fits its size until a run tries it; whether the Windows and Linux
  binaries launch (B7).

## Related

- [[2026-10-16-next-build]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) §Phase 2, §Phase 3, §Phase 4 and §Phase 6
