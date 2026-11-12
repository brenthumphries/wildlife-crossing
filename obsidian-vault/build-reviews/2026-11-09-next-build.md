---
title: "Build Review - Next Build (2026-11-09)"
date: 2026-11-09
tags: [build, review, planning]
status: active
---

> Weekly plan: what must be done to produce the next working build, and who
> does each piece. Routed plan: [`docs/plan/week.json`](../../docs/plan/week.json).

> [!info] Snapshot
> Measured against **`f33dfa9`** (*Merge pull request #116 from
> brenthumphries/docs/att-82-point-section-6-at-adr-0022*, 2026-11-07T12:49:42-06:00)
> on `main`, via `docs/plan/facts.json` written 2026-11-09 and
> `docs/plan/github-state.json` read 2026-11-09T17:22:58+00:00 via curl
> (unauthenticated; no `gh` in the Cowork VM). Suite as stated in
> `docs/testing-setup.md` and checked by CI: **44 scripts / 688 tests / 7,800
> asserts** (unchanged since 2026-11-02). Latest run on `main`: **success** on
> `f33dfa9` at 2026-11-07T18:49:44Z. Previous plan: [[2026-11-02-next-build]].

## 1. Readiness

**Build case: next.** v0.1.0 is published and CI is green on the measured SHA.
No item with `blocker: true` is open, so by the skill's rule the verdict is
ready. That is still the narrow kind of ready: nothing stands in the way of a
release, and v0.2.0 is not cut. The week moved one step: D10 merged (#116), so
the docs now point at ADR 0022. No daily log is newer than 2026-10-30, so
nothing records any of the windowed walks (V15 to V18) as done, and the plan
holds no code item. The path to v0.2.0 is unchanged and sits with Brent:
walk V16 first, then V15, V18 and V17, decide Q10, run V19, then D7 and B9.
Phase 5 stays held behind the cultural-advisor review.

**Verdict: ready** - open blockers: none.

## 2. What changed since 2026-11-02

- **Landed:** #115 (last week's plan, with the crossing-selection test names)
  and #116 (D10, ATT-82). From `recent_merged_pulls`.
- **Closed:** D10 (merged pull request on its branch). Every other carried
  item stays open: no merged pull request or log names it.
- **New facts:** nothing. Open pull requests: 0. No ruleset drift.
- **Decisions:** none logged since 2026-10-30.
- **New items:** none.
- **Changed:** nothing in the routing. Dependencies are as last week.

## 3. This week

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | V16 | Walk the Phase 2 completion features windowed | mac | human | S | none open |
| 2 | D6 | Record Phase 2 completion in the roadmap and the test plan | docs | sonnet / auto | S | V16 |
| 3 | V15 | Walk the text sizes windowed and tune the constants | mac | human | S | none open |
| 4 | V18 | Walk the first-play loop as a new player | mac | human | S | none open |
| 5 | V17 | Walk the seasons windowed | mac | human | S | none open |
| 6 | Q12 | Decide whether flooded banks next to a crossing stay lethal | decision | human | S | V17 |
| 7 | Q13 | Decide where the milestone track sits | decision | human | S | V18 |
| 8 | Q10 | Call the feature freeze for v0.2.0 | decision | human | S | none open |
| 9 | V19 | Run the stabilization walk | mac | human | M | V15 to V18 |
| 10 | D8 | Record Phase 4 and Phase 6 completion | docs | sonnet / auto | S | V17, V18, D6 |
| 11 | D7 | Draft the v0.2.0 release notes | docs | sonnet / auto | S | V19 |
| 12 | B9 | Cut v0.2.0 | mac | human | L | V19, D7 |
| 13 | D9 | Correct ADR 0021's stale method name and a click-path comment | docs | sonnet / supervised | S | none open |
| 14 | Q2 | Decide whether D4 is still wanted | decision | human | S | none open |
| 15 | D4 | Document a safeguard against project.godot losing its comments | docs | sonnet / auto | S | Q2 |
| 16 | Q11 | Decide whether to tighten the segment pick radius | decision | human | S | none open |
| 17 | V5 | Exercise the dco job on a deliberately unsigned commit | mac | human | S | none open |

The 17 open items are 0 code, 5 docs and 12 yours (7 `mac`, 5 `decision`).
Focus is rows 1 to 9. The dispatch picks D9 for Cowork (supervised); no Claude
Code item is eligible, so the week is gated on Brent's walks.

### Yours this week

- **V16 first.** It unblocks D6 and V19. Then V15, V18 and V17 (each unblocks
  V19), then Q12 and Q13 once V17 and V18 show the behaviour, then Q10, then V19.
- **D9 (supervised).** ADR 0021 is on the forbidden list: `tools/warden cowork D9`,
  read the diff; the ADR status change is yours.
- **Q2, Q11, V5.** Small and independent; Q2 gates D4.

## 4. Drift and risks

- **Nothing since C19 has been walked windowed.** Seventeen features merged on
  tests and CI alone, and a week has passed with no log of a walk. This is the
  main risk to the freeze approach.
- **C39 is invisible in v0.2.0.** Bow Valley has no river tiles; the overlay is
  verified by tests only (Assumed, from the 2026-10-30 log). Open call: Q12.
- **Two untested seams in `Main`** (C34 key routing, C40's `_autosave` versus
  `_quick_save`). V18 and V17 are the check (Assumed).
- **Desktop-build artifacts expire from 2026-11-13** (github-state `artifacts`),
  four days from now. v0.1.0 Release assets are unaffected.

## Verification

- **Confirmed** (facts.json at `f33dfa9`; github-state at
  2026-11-09T17:22:58+00:00): `latest_main_run` success on `f33dfa9`; 0 open
  pull requests; #115 and #116 merged; build case next, tag `v0.1.0`; no ruleset
  drift; `week.json` item statuses (49 done, 18 open before D10, 17 after).
- **Assumed** (carried from [[../daily-logs/2026-10-30]]): Bow Valley has no
  river tiles; the C34 and C40 seams are untested; no windowed walk since C19.
- **Unverifiable** this run: whether any walk happened but was not logged; the
  local suite (the Cowork VM has no Godot); whether the gitop hook is set.

## Related

- [[2026-11-02-next-build]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) Phase 4 and Phase 6
