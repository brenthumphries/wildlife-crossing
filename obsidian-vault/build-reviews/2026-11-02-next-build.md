---
title: "Build Review - Next Build (2026-11-02)"
date: 2026-11-02
tags: [build, review, planning]
status: active
---

> Weekly plan: what must be done to produce the next working build, and who
> does each piece. Routed plan: [`docs/plan/week.json`](../../docs/plan/week.json).

> [!info] Snapshot
> Measured against **`4a58683`** (*Merge pull request #114 from
> brenthumphries/docs/log-2026-10-30*, 2026-10-30T21:08:27-05:00) on `main`,
> via `docs/plan/facts.json` written 2026-11-02T12:26:50+00:00. GitHub read
> 2026-11-02T12:26:50+00:00 via curl (unauthenticated; no `gh` in the Cowork
> VM). Suite as stated in `docs/testing-setup.md` and checked by CI: **44
> scripts / 688 tests / 7,800 asserts**. Latest run on `main`: **success** on
> `4a58683` at 2026-10-31T02:08:29Z. Previous plan: [[2026-10-26-next-build]].

## 1. Readiness

**Build case: next.** v0.1.0 is published and CI is green on the measured SHA.
No item with `blocker: true` is open, so by the skill's rule the verdict is
ready. That is a narrow kind of ready: nothing stands in the way of a release,
and v0.2.0 is not yet cut. The good news is that the code is done. The seasons
chain, the milestone track, the Phase 2 hover extras and the autosave all
merged last week, and the plan holds no code item. What remains is what only
Brent can do: walk the features in a real window (V15 to V18), call the freeze
(Q10), run the stabilization walk (V19), then notes (D7) and the cut (B9).
Phase 5 stays held behind the cultural-advisor review.

**Verdict: ready** - open blockers: none.

## 2. What changed since 2026-10-26

- **Landed:** #101 C37, #102 C38, #103 C36, #105 C29, #106 C30, #107 C31, #108
  C34, #109 V20, #110 C40, #111 C42, #112 C39 (with ADR 0022), #113 suite
  figure refresh, #114 the 2026-10-30 log; #100 and #95 cleared. From
  `recent_merged_pulls`, [[../daily-logs/2026-10-26]] and [[../daily-logs/2026-10-30]].
- **Closed:** C29, C30, C31, C34, C36, C37, C38, C39, C40, C42, V20 (merged
  pull requests on each item's branch). The 2026-10-26 plan still listed them
  as open; this plan marks them done.
- **New facts:** nothing. `facts.json` reports 0 stub scripts, 0 uid orphans,
  0 invalid data files, 0 scripts without a named test, and required contexts
  match the jobs. Open pull requests: 0.
- **Decisions:** 2026-10-30, accept ADR 0022 (overlay, not patch re-derivation).
- **New items:** D10 (the docs half of ADR 0022, Linear ATT-82), Q12 and Q13,
  both open questions from the 2026-10-30 log.
- **Changed:** D6 now depends on V16, per the 2026-10-30 log ("walk V16 before
  running D6").

## 3. This week

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | D10 | Point simulation-design and architecture section 6 at ADR 0022 | docs | sonnet / auto | S | none open |
| 2 | V16 | Walk the Phase 2 completion features windowed | mac | human | S | none open |
| 3 | D6 | Record Phase 2 completion in the roadmap and the test plan | docs | sonnet / auto | S | V16 |
| 4 | V15 | Walk the text sizes windowed and tune the constants | mac | human | S | none open |
| 5 | V18 | Walk the first-play loop as a new player | mac | human | S | none open |
| 6 | V17 | Walk the seasons windowed | mac | human | S | none open |
| 7 | Q12 | Decide whether flooded banks next to a crossing stay lethal | decision | human | S | V17 |
| 8 | Q13 | Decide where the milestone track sits | decision | human | S | V18 |
| 9 | Q10 | Call the feature freeze for v0.2.0 | decision | human | S | none open |
| 10 | V19 | Run the stabilization walk | mac | human | M | V15 to V18 |
| 11 | D8 | Record Phase 4 and Phase 6 completion | docs | sonnet / auto | S | V17, V18, D6 |
| 12 | D7 | Draft the v0.2.0 release notes | docs | sonnet / auto | S | V19 |
| 13 | B9 | Cut v0.2.0 | mac | human | L | V19, D7 |
| 14 | D9 | Correct ADR 0021's stale method name and a click-path comment | docs | sonnet / supervised | S | none open |
| 15 | Q2 | Decide whether D4 is still wanted | decision | human | S | none open |
| 16 | D4 | Document a safeguard against project.godot losing its comments | docs | sonnet / auto | S | Q2 |
| 17 | Q11 | Decide whether to tighten the segment pick radius | decision | human | S | none open |
| 18 | V5 | Exercise the dco job on a deliberately unsigned commit | mac | human | S | none open |

The 18 open items are 0 code, 6 docs and 12 yours (7 `mac`, 5 `decision`).
Focus is rows 1 to 10. The dispatch picks D10 and D9 for Cowork; no Claude Code
item is eligible, so the week is gated on Brent's walks.

### Yours this week

- **V16 first.** Walk Phase 2 windowed, including the C25 click test from
  [[../daily-logs/2026-10-17]] and the toolbar fix. It unblocks D6 and V19.
- **V15, V18, V17.** Text sizes; the first-play loop (also shows the C42 track
  and the C40 Continue button); the seasons. Caveat on V17: Bow Valley has no
  river tiles, so C39 cannot be seen there (see section 4). Each unblocks V19.
- **Q12 and Q13.** Decide after V17 and V18 show the behaviour.
- **Q10.** Call the freeze once the walks are done. Gates V19.
- **D9 (supervised).** ADR 0021 is on the forbidden list: `tools/warden cowork D9`,
  read the diff; the ADR status change is yours.
- **Q2, Q11, V5.** Small and independent; Q2 gates D4.
- **Housekeeping, not items:** commit or set aside the uncommitted edit to
  `docs/test-plan.md` (it stops `ship.py` on unclaimed paths); land
  `commit-plan-2026-10-30-log.json`; `git pull`, delete the two merged remote
  branches, `tools/warden clean`; read the test-history paragraph in
  `docs/testing-setup.md`.

## 4. Drift and risks

- **simulation-design section 6, architecture section 6 and the roadmap Q9
  block still describe patch re-derivation.** ADR 0022 narrows it. Fixed by D10.
- **C39 is invisible in v0.2.0.** Bow Valley, the only playable sub-area, has no
  river tiles, and the tests run on sub-area 1. The overlay is verified by tests
  only. V17 should say so rather than imply the rule was seen. Open call: Q12.
- **ADR 0022 known gap:** two banks joined by ice still count as separate
  patches, so connectivity does not reward the winter link. Recorded in the log;
  no item, since it is a deliberate narrowing.
- **Two untested seams in `Main`** (C34 key routing, C40's `_autosave` versus
  `_quick_save`). They need a scene tree, so V18 and V17 are the check.
- **C42 gaps against the ui-ux spec** (position, click-through). Q13.
- **Nothing since C19 has been walked windowed.** Seventeen features have merged
  on tests and CI alone. This is the main risk to the freeze approach, and why
  the walks lead the week.
- **Desktop-build artifacts expire from 2026-11-13** (github-state `artifacts`).
  v0.1.0 Release assets are unaffected.

## Verification

- **Confirmed** (facts.json at `4a58683`; github-state at
  2026-11-02T12:26:50+00:00): `latest_main_run` success on `4a58683`; 0 open
  pull requests; merged pulls #101 to #114 as listed; suite figure as stated;
  tag `v0.1.0` and a prerelease; no stubs, orphans or invalid data; required
  contexts match the jobs; `warden day --no-write` ran clean on this plan.
- **Assumed** (carried from [[../daily-logs/2026-10-30]] and [[../daily-logs/2026-10-26]]):
  Bow Valley has no river tiles; the C34 and C40 seams are untested; the
  `docs/test-plan.md` edit is Brent's; ATT-77 and ATT-82 states in Linear.
- **Unverifiable** this run: windowed behaviour of everything since C19; whether
  the gitop hook is set in any worktree; the local suite (`measured_locally` in
  `facts.json` is a stale September file; the Cowork VM has no Godot); the
  `ship.py` dry run (see the log of this run).

## Related

- [[2026-10-26-next-build]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) Phase 4 and Phase 6
