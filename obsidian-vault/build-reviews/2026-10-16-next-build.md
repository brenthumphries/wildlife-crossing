---
title: "Build Review — Next Build (2026-10-16)"
date: 2026-10-16
tags: [build, review, planning]
status: active
---

> Weekly plan. One question: what work must be done to produce the next
> working build, and who does each piece? The routed plan is
> [`docs/plan/week.json`](../../docs/plan/week.json); `tools/warden.py day`
> dispatches from it.

> [!success] Amendment 2026-10-16 (later) — **Q5 is decided, and C18 is rewritten around the Info panel.**
> Brent chose a keyboard-opened Info panel on the `I` key for this build, with
> arrow keys then Enter to buy and patches labelled by biome and size. Map
> markers for the corridor hotspots move to Phase 2 completion. The decision is
> in the third Phase 3 Decision logged block of `docs/roadmap.md`. C18 now
> creates `information_panel.gd` and its test, adds a free-band accessor to
> `InformationManager` (the manager returned a band only after a purchase), and
> no longer touches `hud.gd`. This is the fourth edit of `week.json` this week.

> [!success] Amendment 2026-10-16 (evening) — **C14, C15, C17 and C18 are closed, and Phase 3's code is complete.**
> Merged pull requests: C14 in #64, C15 in #65, C17 in #66 and C18 in #68. Brent
> walked the Info panel windowed and every keyed step worked; the one finding was
> that the text is very small, which also hid whether B is ignored behind the
> panel, and which settled Q3 (text size earns work) and, in part, a new
> decision, Q6 (a larger default for all text, adjustable from a title screen
> option and with Ctrl+= and Ctrl+-). The steps and where the setting persists are still
> open. The dispatch shows the Phase 3 items as done. The suite is now 31
> scripts / 379 tests / 6,629 asserts. See [[../daily-logs/2026-10-16]].

> [!success] Amendment 2026-10-16 (late) — **Q6 is fully decided, and Q7 and Q8 are decided.**
> The steps and storage left open above are settled. Baseline sizes are body 20,
> title 36 and small 16. The player steps through 100, 125, 150 and 175 percent
> from a title screen option and with Ctrl+=, Ctrl+- and Ctrl+0, stored in
> `user://settings.cfg`, separate from saves. Q7: the fundraising trickle applies
> below the cheapest crossing tile that can be bought, not the cheapest
> information product (item C32). Q8: v0.2.0 goes big behind a feature freeze.
> The calls are in the Phase 3 Decision logged blocks of `docs/roadmap.md`, and
> the work is routed in [[2026-10-19-next-build]]. See [[../daily-logs/2026-10-16]].

> [!info] Snapshot
> Measured against **`3f3d227`** (*Merge pull request #62 from
> brenthumphries/docs/log-2026-10-15-evening*, 2026-10-16T09:59:41-05:00) on
> `main`, via `docs/plan/facts.json`. GitHub read 2026-10-16T15:02:41+00:00 via
> `gh`. Suite as stated in `docs/testing-setup.md` and checked by CI: **29
> scripts / 335 tests / 6,434 asserts**. Previous plan: [[2026-10-15-next-build]].
> Mid-week re-run: written Friday 2026-10-16 for the week of 2026-10-12, at
> Brent's request, to mark Q4 done. This is the third override of
> `edit_midweek: never` for this week (#56, #59, and this one); the earlier
> notes stand, amended by callout.

## 1. Readiness

**Build case: next.** v0.1.0 is published. B7 still blocks: the Gatekeeper and
checksum halves passed on 2026-10-15, and the Windows and Linux launch checks
wait for a machine (Linear ATT-62). Phase 3 has started. C12, C13 and C16 are
merged and Q4 is decided, so C14, C15 and C17 are eligible.

**Verdict: not-ready.** Open blockers: B7.

## 2. What changed since 2026-10-15

- **Landed:** PR #57 (C12), #58 (D3), #59 (plan amendment, Q4 block), #60 (C13),
  #61 (C16), #62 (the evening log). From `recent_merged_pulls`.
- **Closed:** C12, C13, C16, D3 (merged PRs above); Q4 (decided 2026-10-15,
  second Phase 3 Decision logged block, [[2026-10-15]]).
- **New facts:** nothing in `facts.json` beyond the two
  `scripts_without_named_test` (V12).
- **Decisions:** none new. Q4's formula, the no-bump call and the
  `products_by_area` shape are now written into C14, C15 and C17's acceptance.

## 3. This week

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | B7 | Walk the Windows and Linux halves of runbook A8 on clean machines | mac | human | S | none |
| 2 | Q2 | Decide whether D4 is still wanted | decision | human | S | none |
| 3 | Q5 | Decide where a revealed information layer shows before the in-map renderer | decision | human | S | none |
| 4 | C14 | Store the fragmentation deficit on each crossing and in the save | code | sonnet / supervised | M | C12, Q4 |
| 5 | C15 | Pay monthly donations and the fundraising trickle | code | sonnet / auto | M | C12, C14 |
| 6 | C17 | Add the information manager for the three area products | code | sonnet / auto | M | C12, Q4 |
| 7 | C18 | Show purchased information layers in the game | code | sonnet / supervised | M | C17, Q5 |
| 8 | V12 | Name a test for the two minigame scripts or exempt them | verify | sonnet / auto | S | none |
| 9 | V3 | Make every P0 row in docs/test-plan.md §11 name a test or a deferral | docs | sonnet / auto | S | none |
| 10 | D1 | Retire or rewrite docs/pre-build-checklist.md | docs | sonnet / auto | S | none |
| 11 | D4 | Document a safeguard against game/project.godot losing its comments | docs | sonnet / auto | S | Q2 |
| 12 | V5 | Exercise the dco job on a deliberately unsigned commit | mac | human | S | none |
| 13 | V13 | Make warden merge survive a worktree on the item's branch | code | sonnet / supervised | S | none |
| 14 | D5 | Correct docs/adr/0018 line 165, which says Build-review V2 is open | docs | sonnet / supervised | S | none |
| 15 | Q3 | Decide whether HUD and credits text size earns an item | decision | human | S | none |

Of the open items, 5 are code (C14, C15, C17, C18, V13), 4 docs (V3, D1, D4, D5),
1 verify (V12) and 5 are yours (B7, Q2, Q5, V5, Q3). The dispatch picks C14 and
V13, both supervised; C17 and V12 share `docs/testing-setup.md` with C14 and
wait. The week's focus is the first eight.

### Yours this week

- **Q5.** Where a revealed layer shows before the in-map renderer exists.
  Proposal: a keyboard-opened survey panel like the F2 and F3 overlays. Gates
  C18 only.
- **Q2.** Keep, rewrite or drop D4. Gates D4.
- **B7.** The Windows and Linux launch checks, when a machine is available.
- **V5, Q3.** Unchanged.

## 4. Drift and risks

- **ADR 0018 still says V2 is open.** D3 fixed the runbook and left the ADR,
  a forbidden path for `auto`. D5 fixes it, supervised.
- **`warden merge` fails when a worktree holds the branch.** V13 fixes it.
- **v0.1.0 saves carry `economy.budget: 0`.** Loading one gives $0 until
  C15's trickle pays out. Accepted; no item.
- **The last-donation label cannot appear until C15.** Nothing emits
  `donation_received` yet.

## Verification

- **Confirmed** (`facts.json` at `3f3d227`; github-state at
  2026-10-16T15:02:41+00:00): zero open pull requests, suite figure as stated,
  CI required contexts match, tag `v0.1.0`, `scripts_without_named_test`
  listing two scripts. `tools/warden.py day --no-write` validates the plan and
  shows Q4, C12, C13, C16 and D3 as done.
- **Assumed** (carried from [[2026-10-15]]): the clean-Mac results, that C16 has
  not been walked windowed, and that V5 has not been run.
- **Unverifiable** this run: whether any item fits its size until a run tries
  it; whether the Windows and Linux binaries launch (B7).

## Related

- [[2026-10-15-next-build]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) §Phase 3
