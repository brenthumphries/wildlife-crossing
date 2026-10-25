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

> [!success] Amendment 2026-10-25 — **B7 is closed: the Windows and Linux binaries launch.**
> The new `binary-check.yml` workflow (ATT-67, merged in #97) downloaded the
> v0.1.0 Release assets, checked them against `SHA256SUMS.txt`, launched each
> binary for at least 10 seconds and uploaded a title-screen screenshot. Run
> [40204770783](https://github.com/brenthumphries/wildlife-crossing/actions/runs/40204770783)
> passed on both runners, logging `Title screen ready` under Mesa software
> OpenGL on Linux and ANGLE on Microsoft's software renderer on Windows. Brent
> opened both PNGs and both show the correct title screen, and he is closing
> ATT-62. This review's "open blockers: B7", the B7 row in section 3 and the B7
> line under Verification below are superseded: nothing blocks a release on the launch checks. B9
> still waits on V19 and D7. `docs/plan/week.json` is not edited midweek, so it
> still lists B7 until the next weekly plan closes it. Detail:
> [[../daily-logs/2026-10-25]].

> [!info] Snapshot
> Measured against **`8248874`** (*Merge pull request #94 from
> brenthumphries/chore/suite-figure-per-batch*, 2026-10-18T18:36:52-05:00) on
> `main`, via `docs/plan/facts.json` written 2026-10-19T14:59:32+00:00. GitHub
> read 2026-10-19T14:59:32+00:00 via curl (unauthenticated; `gh` is absent in
> this VM). Suite as stated in `docs/testing-setup.md` and checked by CI:
> **40 scripts / 577 tests / 7,372 asserts**. Latest run on `main`:
> **success** on `8248874` at 2026-10-18T23:36:55Z. Previous plan:
> [[2026-10-16-next-build]].
> This is Monday's version of the plan first written early on Friday
> 2026-10-16. It replaces that version: carried ids are unchanged, closed items
> are marked done, and three items are new.

## 1. Readiness

**Build case: next.** v0.1.0 is published and CI is green on `main`. B7 still
blocks: the Windows and Linux launch checks wait for a machine (Linear ATT-62).
Since Friday the v0.2.0 push has gone fast. Text size is built end to end
(C19 to C23), Phase 2 completion is merged apart from three polish items
(C24 to C28), and the seasons and milestones work has started: TimeController
(C33), SeasonManager (C35), MilestoneTracker (C41) and the first-time hints
(C43) are in. Nothing is walked windowed yet, so every "done" below means
merged and green in CI, not proven on a screen. Phase 5 stays held behind the
cultural-advisor review.

**Verdict: not-ready.** Open blockers: B7.

## 2. What changed since 2026-10-16

- **Landed:** PR #72 to #94 on `main`, from `recent_merged_pulls`: text size
  (#72, #73, #78, #79, #88), Phase 2 map work (#74, #75, #76, #84), trickle fix
  (#80), minigame tests and housekeeping (#77, #81, #82), docs (#85, #86, #87),
  TimeController (#89), toolbar (#90), MilestoneTracker (#91), hints (#92),
  SeasonManager (#93), suite-figure tooling (#94).
- **Closed (22):** C19, C20, C21, C22 (2026-10-17 log); C23 (#88); C24, C25,
  C28 (2026-10-17 log); C26 (#84); C27 (#90); C32 (#80); C33 (#89); C35 (#93);
  C41 (#91); C43 (#92); V12, V13, V14 (2026-10-17 log); V3 (#86); D5 (#85);
  D1 (#87); Q9 (decided 2026-10-16, Phase 4 Decision logged block in
  `docs/roadmap.md`).
- **New items:** V20 (the warden land test needs `gh`), D9 (stale ADR 0021
  method name and a `credits_screen.gd` comment), Q11 (the segment pick
  radius). All three come from the Open questions in
  [[../daily-logs/2026-10-17]].
- **New facts:** nothing in `facts.json` beyond the figures above.
- **Open pull request:** #95, *fix(ui): keep the build toolbar inside the
  window* (branch `fix/toolbar-and-trackpad-zoom`), is not an item. It repairs
  the toolbar C27 added; V16 should walk it once merged.
- **In flight but unlanded:** D6 was started in Cowork on 2026-10-18 (see
  `queue/log.jsonl`); no commit plan or pull request exists, so it stays open.
- **Decisions:** 2026-10-16, Brent: Q9 (only the grizzly is absent, in winter).
  Q10 and Q11 are open.

## 3. This week

The 27 open items are in `week.json` in priority order; the first eight are the
week's focus. The dispatch runs two code items at a time.

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | B7 | Walk the Windows and Linux halves of runbook A8 on clean machines | mac | human | S | none |
| 2 | C37 | Make species absent in their off-season | code | sonnet / auto | M | none open |
| 3 | C34 | Add the TimeControls HUD widget and keys | code | sonnet / auto | S | none open |
| 4 | C36 | Add the season calendar to the HUD | code | sonnet / auto | S | C37 |
| 5 | C38 | Raise crossing attempts in a species' migration season | code | sonnet / auto | M | C37 |
| 6 | C39 | Add seasonal terrain: rivers freeze in winter and flood in spring | code | opus / supervised | M | none open |
| 7 | C40 | Autosave on each season change and add Continue to the title menu | code | sonnet / auto | M | none open |
| 8 | C42 | Show the milestone track and celebrate each milestone | code | sonnet / auto | M | none open |

Later: C29, C30, C31, D6, Q2, D4, V15 to V19, Q10, D8, D7, B9, V5, V20, D9, Q11.

The 27 open items are 10 code, 1 verify, 5 docs and 11 yours (8 `mac`, 3
`decision`). The dispatch picks C37 and C34 first (code), and D6 and D9 for
Cowork. Seven items wait on the shared suite-figure file or the two-at-a-time
limit, and nine are blocked on dependencies.

### Yours this week

- **B7.** Walk the Windows and Linux halves of runbook A8 on clean machines.
  Unblocks B9 and so the v0.2.0 release.
- **V15.** Walk the text sizes windowed. Also check the HUD stack when build
  mode opens, since C20 moved the build status readout into it. Unblocks V19.
- **V16.** Walk Phase 2 completion windowed, including the C25 click test from
  the 2026-10-17 log and the toolbar once #95 is merged. Unblocks V19 and D6's
  record of the exit criteria.
- **Q10.** Call the feature freeze when the features you want are merged and
  walked. Gates V19.
- **Q11.** Keep or tighten `SEGMENT_PICK_RADIUS` (now 1). Can wait for V16.
- **Q2, V5, V17 to V19.** Q2 gates D4; the walks wait on their code.
- **D9 (supervised).** ADR 0021 is on the forbidden list, so run it as
  `tools/warden cowork D9` and read the diff; the ADR status change from
  proposed to accepted is yours.
- **B9.** Cut v0.2.0 on the Mac after B7, V19 and D7.

## 4. Drift and risks

- **ADR 0021 and `credits_screen.gd` name a click path that no longer exists.**
  The ADR says `Main._pick_segment_at_mouse` (now `_pick_segment_at`); the
  comment describes a fall-through that C25 removed. Fixed by D9.
- **The tool tests need `gh`.** In the Cowork VM,
  `python3 -m unittest discover -s tools/tests -b` errors once on
  `FileNotFoundError: 'gh'` (per the 2026-10-17 log, not re-run this session).
  Fixed by V20.
- **Seasons touch the simulation core.** C37, C38 and C39 change presence,
  pathing and hazards. C39 is opus and supervised and writes an ADR; read it
  before merging.
- **Nothing since C19 has been walked windowed.** Text size, the world map at
  segment zoom, the toolbar and the first-time hints are verified by tests and
  CI only. #95 is a toolbar fix, so the toolbar already shows a screen-only
  fault. V15 and V16 are the real check.
- **The freeze approach concentrates risk.** With no release candidate per
  phase, a late problem blocks the release; V15 to V18 are the early warning.

## Verification

- **Confirmed** (`facts.json` at `8248874`; github-state at
  2026-10-19T14:59:32+00:00): `latest_main_run` success on `8248874`; one open
  pull request (#95); merged pulls #72 to #94; suite figure as stated; tag
  `v0.1.0` and a prerelease on GitHub; no stub scripts, orphans or invalid data
  files; required CI contexts match the jobs; the ruleset matches the committed
  copy; `python3 tools/warden.py day --no-write` validates the plan.
- **Assumed** (carried from [[../daily-logs/2026-10-17]] and
  [[../daily-logs/2026-10-16]]): the review notes on C25, the V13 behaviour on
  a real merge, and the `gh` error in the tool tests. No daily log exists after
  2026-10-17; closures for C23, C26, C27, C33, C35, C41, C43, D1, D5 and V3
  rest on merged pull requests.
- **Unverifiable** this run: any windowed behaviour of C19 to C28 and C33 to
  C43; whether the Windows and Linux binaries launch (B7); the outcome of the
  unlanded D6 Cowork session.

## Related

- [[2026-10-16-next-build]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) §Phase 2, §Phase 4 and §Phase 6
