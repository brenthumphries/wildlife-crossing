---
title: "Build Review - Next Build (2026-10-26)"
date: 2026-10-26
tags: [build, review, planning]
status: active
---

> Weekly plan: what must be done to produce the next working build, and who
> does each piece. Routed plan: [`docs/plan/week.json`](../../docs/plan/week.json).

> [!success] Amendment 2026-10-30 — **C29, C30, C31, C34, C39, C40, C42 and V20 are merged.**
> Merged 2026-10-29 and 2026-10-30 as #105, #106, #107, #108, #112, #110, #111 and #109. Rows 2, 5, 6, 7, 8, 9, 10 and 24 of the §3 table are done. ADR 0022 (accepted 2026-10-30) records C39's design; `simulation-design` §6 and `architecture` §6 still describe patch re-derivation (Linear ATT-82). #113 refreshed the suite figure to 44 scripts / 688 tests / 7,800 asserts. `week.json` is not edited midweek and still lists the eight as open. Still open: D6, D9, D4 (behind Q2), D8, V15 to V19, Q2, Q10, Q11, V5, D7, B9. See [[../daily-logs/2026-10-30]].

> [!success] Amendment 2026-10-26 — **C37, C38 and C36 are merged, and #95 is cleared.**
> Merged later the same day as #101, #102 and #103, with #100 and #95 also merged. Rows 1, 3 and 4 of the §3 table are done; "Merge or close #95" under *Yours this week* is done. `week.json` is not edited midweek and still lists them as open. See [[../daily-logs/2026-10-26]].

> [!info] Snapshot
> Measured against **`7f2ad1e`** (*Merge pull request #99 from
> brenthumphries/docs/roadmap-b7-resolved*, 2026-10-25T10:31:52-05:00) on
> `main`, via `docs/plan/facts.json` written 2026-10-26T2026-10-26T11:17:27+00:00. GitHub read
> 2026-10-26T11:17:11+00:00 via curl (unauthenticated; no `gh` in this VM).
> Suite as stated in `docs/testing-setup.md` and checked by CI: **40 scripts /
> 577 tests / 7,372 asserts**. Latest run on `main`: **success** on `7f2ad1e`
> at 2026-10-25T15:31:55Z. Previous plan: [[2026-10-19-next-build]].

## 1. Readiness

**Build case: next.** v0.1.0 is published (tag, release note and a GitHub
prerelease) and CI is green on the measured SHA. B7, the one open blocker last
week, is closed: the `binary-check.yml` workflow launched the v0.1.0 Windows and
Linux binaries, both title-screen screenshots were checked by hand, and Linear
ATT-62 and ATT-67 are Done. No item with `blocker: true` is open, so by the
skill's rule the verdict is ready. That is a narrow kind of ready: it says
nothing stands in the way of a release, not that v0.2.0 is near. The seasons
chain (C34 to C40) and the milestone track (C42) are unbuilt, nothing since C19
has been walked windowed, and B9 still waits on V19 and D7. Phase 5 stays held
behind the cultural-advisor review.

**Verdict: ready**, open blockers: none.

## 2. What changed since 2026-10-19

- **Landed:** PR #96 (docs(plan): week of 2026-10-19 reconcile), #97
  (chore(ci): manual binary-check workflow), #98 (docs(log): v0.1.0 launch
  check, close B7), #99 (docs(roadmap): B7 resolved), from
  `recent_merged_pulls`. No item branch merged; the week was plan and release
  checks, not features.
- **Closed:** B7, [[../daily-logs/2026-10-25]] and PR #98; run 40204770783
  passed on both runners; Linear ATT-62 and ATT-67 Done 2026-10-25.
- **New facts and items:** nothing. `facts.json` reports no stub scripts, uid orphans,
  invalid data files or missing named tests, required contexts match the jobs,
  and `ruleset_drift` is null (in sync).
- **Open pull request:** #95, *fix(ui): keep the build toolbar inside the
  window* (`fix/toolbar-and-trackpad-zoom`), last updated 2026-10-19. Not an
  item; it repairs the toolbar C27 added. See §4.
- **In flight but unlanded:** D6 was started in Cowork on 2026-10-18; no
  commit plan or pull request exists, so it stays open.
- **Decisions:** none new in the logs. Brent noted on 2026-10-25 that v0.2.0 is
  not being tagged yet. Q10 and Q11 remain open.

## 3. This week

The 26 open items are in `week.json` in priority order; the first eight
are the week's focus. The dispatch runs two code items at a time.

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | C37 | Make species absent in their off-season | code | sonnet / auto | M | none open |
| 2 | C34 | Add the TimeControls HUD widget and keys | code | sonnet / auto | S | none open |
| 3 | C36 | Add the season calendar to the HUD | code | sonnet / auto | S | C37 |
| 4 | C38 | Raise crossing attempts in a species' migration season | code | sonnet / auto | M | C37 |
| 5 | C39 | Add seasonal terrain: rivers freeze in winter and flood in spring | code | opus / supervised | M | none open |
| 6 | C40 | Autosave on each season change and add Continue to the title menu | code | sonnet / auto | M | none open |
| 7 | C42 | Show the milestone track and celebrate each milestone | code | sonnet / auto | M | none open |
| 8 | C29 | Show how many crossings already exist on a segment in the confirm panel | code | sonnet / auto | S | none open |
| 9 | C30 | Show a sub-area summary on hover and scale the world map labels | code | sonnet / auto | M | none open |
| 10 | C31 | Show a connectivity score tooltip on segment hover | code | sonnet / auto | M | none open |
| 11 | D6 | Record Phase 2 completion in the roadmap and the test plan | docs | sonnet / auto | S | none open |
| 12 | Q2 | Decide whether D4 is still wanted | decision | human | S | none open |
| 13 | D4 | Document a safeguard against game/project.godot losing its comments | docs | sonnet / auto | S | Q2 |
| 14 | V15 | Walk the text sizes windowed and tune the constants | mac | human | S | none open |
| 15 | V16 | Walk the Phase 2 completion features windowed | mac | human | S | none open |
| 16 | V17 | Walk the seasons windowed | mac | human | S | C34, C36, C37, C38, C39, C40 |
| 17 | V18 | Walk the first-play loop as a new player | mac | human | S | C42 |
| 18 | Q10 | Call the feature freeze for v0.2.0 | decision | human | S | none open |
| 19 | V19 | Run the stabilization walk | mac | human | M | V15, V16, V17, V18, C29, C30, C31 |
| 20 | D8 | Record Phase 4 and Phase 6 completion in the roadmap and test plan | docs | sonnet / auto | S | V17, V18, D6 |
| 21 | D7 | Draft the v0.2.0 release notes | docs | sonnet / auto | S | V19 |
| 22 | B9 | Cut v0.2.0 | mac | human | L | V19, D7 |
| 23 | V5 | Exercise the dco job on a deliberately unsigned commit | mac | human | S | none open |
| 24 | V20 | Stub the gh query in the warden land test so the tool tests pass without gh | verify | sonnet / auto | S | none open |
| 25 | D9 | Correct ADR 0021's stale method name and the credits_screen click-path comment | docs | sonnet / supervised | S | none open |
| 26 | Q11 | Decide whether to tighten the segment pick radius | decision | human | S | none open |

Focus is rows 1 to 8. The 26 open items are 11 code (10 code, 1 verify), 5 docs
and 10 yours (7 `mac`, 3 `decision`). The dispatch picks C37 and C34 first, and
D6 and D9 for Cowork.

### Yours this week

- **Merge or close #95.** The toolbar fix has sat open a week. V16 should walk
  the toolbar only after it lands.
- **V15.** Walk the text sizes windowed, and the HUD stack when build mode
  opens (C20 moved the build status readout into it). Unblocks V19.
- **V16.** Walk Phase 2 completion windowed, including the C25 click test and
  the toolbar. Unblocks V19 and D6's record of the exit criteria.
- **Q10.** Call the feature freeze when the features you want are merged and
  walked. Gates V19. Note the Linear freeze window (ATT-75) is a separate
  bops pilot freeze, not this one.
- **Q11.** Keep or tighten `SEGMENT_PICK_RADIUS` (now 1). Can wait for V16.
- **Q2, V5, V17 to V19.** Q2 gates D4; the walks wait on their code.
- **D9 (supervised).** ADR 0021 is on the forbidden list, so run
  `tools/warden cowork D9` and read the diff; the ADR status change from
  proposed to accepted is yours.
- **B9.** Cut v0.2.0 on the Mac after V19 and D7. When cut, run
  `gh workflow run binary-check.yml -f tag=v0.2.0` for the launch check.

## 4. Drift and risks

- **Seasons touch the simulation core.** C37, C38 and C39 change presence,
  pathing and hazards. C39 is opus and supervised and writes an ADR; read it
  before merging.
- **Nothing since C19 has been walked windowed.** Text size, the world map at
  segment zoom, the toolbar and the hints are verified by tests and CI only.
  #95 is a toolbar fix, so the toolbar already showed a screen-only fault.
- **The tool tests need `gh`.** Per the 2026-10-17 log, the Cowork VM errors once
  on `FileNotFoundError: 'gh'`. Fixed by V20.
- **ADR 0021 and `credits_screen.gd` name a click path that no longer exists.**
  Fixed by D9.
- **The freeze approach concentrates risk.** With no release candidate per
  phase, a late problem blocks the release; V15 to V18 are the early warning.
- **Artifact expiry.** Two desktop-build artifacts expire 2026-10-26 (from
  github-state `artifacts`); the v0.1.0 Release assets are unaffected.

## Verification

- **Confirmed** (`facts.json` at `7f2ad1e`; github-state at
  2026-10-26T11:17:11+00:00): `latest_main_run` success on `7f2ad1e`; one open
  pull request (#95); merged pulls #96 to #99 since the last plan; suite figure
  as stated; tag `v0.1.0` and a prerelease on GitHub; no stub scripts, orphans
  or invalid data files; required CI contexts match the jobs; the ruleset
  matches the committed copy; Linear shows ATT-62 and ATT-67 Done.
- **Assumed** (carried from [[../daily-logs/2026-10-25]] and
  [[../daily-logs/2026-10-17]]): the screenshots show the correct title screen
  (Brent's look); the `gh` error in the tool tests; D6 has no unlanded work.
- **Unverifiable** this run: whether anything beyond the title screen works in
  the Windows and Linux builds; windowed behaviour of text size, the map, the
  toolbar and hints; the local test suite (`measured_locally` in `facts.json`
  is a stale September file).

## Related

- [[2026-10-19-next-build]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) §Phase 4 and §Phase 6
