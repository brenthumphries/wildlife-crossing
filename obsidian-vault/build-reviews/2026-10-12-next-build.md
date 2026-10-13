---
title: "Build Review — Next Build (2026-10-12)"
date: 2026-10-12
tags: [build, review, planning]
status: active
---

> Weekly plan. One question: what work must be done to produce the next
> working build, and who does each piece? The routed plan is
> [`docs/plan/week.json`](../../docs/plan/week.json); `tools/warden.py day`
> dispatches from it.

> [!info] Snapshot
> Measured against **`4273b1e`** (*Merge pull request #53 from
> brenthumphries/docs/runbook-b3-flat-manifest*, 2026-10-12T11:50:01-05:00) on
> `main`, via `docs/plan/facts.json` written 2026-10-13. GitHub read
> 2026-10-13T19:42:29+00:00 via `curl`. Suite as stated in
> `docs/testing-setup.md` and checked by CI: **28 scripts / 310 tests / 6,378
> asserts**. Latest run on `main`: **success** on `4273b1e` at
> 2026-10-12T16:50:04Z. Previous plan: [[2026-09-26-next-build]].
> Mid-week catch-up: written Tuesday 2026-10-13 for the week of 2026-10-12.

## 1. Readiness

**Build case: next.** The first build exists. C5 (the QA walk) and C6 (the
website download copy) closed on 2026-10-12, and B6 followed the same day:
v0.1.0 was tagged at `d023ef7` and published as a pre-release with eight
assets, a notarized `.dmg` with the licence notices inside, and a GPG-signed
`SHA256SUMS.txt`. One blocker stands. B7, the clean-Mac acceptance test of the
published Release, has not been run, and the rebuilt `.dmg` is an APFS image
where Godot's was HFS+, so it has only been mounted on the Mac that made it.

**Verdict: not-ready.** Open blockers: B7.

## 2. What changed since 2026-09-26

- **Landed:** PR #45 (C6, website download copy), #46 (runbook paths after the
  move to `~/projects`), #47 (`project.godot` committed comment-free), #48
  (log: C5 and C6), #49 and #50 (v0.1.0 release note and notices), #51 (log:
  B6), #52 (runbook A6: notices are added by hand), #53 (runbook B3: flat
  staging folder). From `recent_merged_pulls`.
- **Closed:** C5 (QA walk passed, [[2026-10-12]]), C6 (PR #45, [[2026-10-12]]),
  B6 (tag `v0.1.0`, GitHub Release 2026-10-12T16:26Z, `releases` in
  github-state). The two runbook corrections the B6 log left without items
  (A6 notices claim, B3 flat manifest) landed as PRs #52 and #53.
- **New facts:** `scripts_without_named_test` lists `snowpack_minigame` and
  `telemetry_minigame`; neither is on the exempt list. Added as V12.
- **Decisions:** 2026-10-12: notices go inside the `.dmg` (Option 1); v0.1.0
  ships as a pre-release. Both Brent's calls, per [[2026-10-12]].

## 3. This week

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | B7 | Walk signing-runbook A8 on a clean Mac | mac | human | S | none |
| 2 | Q1 | Decide what the next build contains | decision | human | S | none |
| 3 | Q2 | Decide whether D4 is still wanted | decision | human | S | none |
| 4 | V5 | Exercise the dco job unsigned | mac | human | S | none |
| 5 | V3 | Close the test-plan.md §11 P0 rows | docs | sonnet / auto | S | none |
| 6 | V12 | Name a test for the two minigame scripts or exempt them | verify | sonnet / auto | S | none |
| 7 | D3 | Fix a stale line in signing-runbook.md Part D | docs | haiku / auto | S | none |
| 8 | D1 | Retire or rewrite pre-build-checklist.md | docs | sonnet / auto | S | none |
| 9 | D4 | Document the project.godot comment-loss risk | docs | sonnet / auto | S | Q2 |
| 10 | Q3 | Decide whether HUD text size earns an item | decision | human | S | none |

2 code items (V12, D3), 3 for Cowork (V3, D1, D4), 5 yours (B7, Q1, Q2, V5,
Q3). The dispatch picks V12 and D3 first. The whole plan is the week's focus;
it is ten items and Q1 shapes whatever comes after.

### Yours this week

- **B7.** Download the DMG from the Release URL on a Mac that has never had the
  project and confirm no Gatekeeper warning of any kind. Extract and launch the
  Windows and Linux assets on clean machines. Two extra criteria came from the
  B6 log: check the Windows and Linux binaries report 0.1.0, and verify the
  downloaded `SHA256SUMS.txt` against its `.asc`. The only blocker.
- **Q1.** What the next build is. Roadmap Phase 2 completion (in-map segment
  renderer, hover highlight) was deferred to post-v0.1.0; Phase 3 needs
  `economy_manager_test.gd` and `information_manager_test.gd`, which do not
  exist. This item is the planner's inference from the roadmap, not a log
  request. Unblocks all feature work.
- **Q2.** PR #47 and `docs/project-godot-settings.md` may have made D4
  redundant. Keep, rewrite, or drop. Unblocks D4.
- **V5.** Fifteen minutes with `gh`: an unsigned commit on a throwaway pull
  request should fail the dco check, then pass once signed off.
- **Q3.** HUD and credits text passed C5 as small but legible at 1280x720.
  Whether that earns a follow-up is yours; the 2026-10-12 log leaves it open.

## 4. Drift and risks

- **`docs/pre-build-checklist.md` still says there is no Godot project to
  build.** The repository is public. D1 fixes it.
- **`docs/signing-runbook.md` Part D point 3 still says Build-review V2 is
  open.** D3 fixes the line.
- **Local release working files are still on the Mac** (`~/wc-release-v0.1.0/`,
  `~/wc-dmg-work/`, `~/wc-release-notes-body.md`). The 2026-10-12 log asks to
  keep them until B7 passes. Nothing to fix; delete after B7.
- **Unclaimed changes in the tree:** `CLAUDE.md` (`## youtube` block, modified)
  and untracked `obsidian-vault/youtube/`. Left out of the commit plan.

## Verification

- **Confirmed** (`facts.json` at `4273b1e`; github-state at
  2026-10-13T19:42:29+00:00): the suite figure as stated (28/310/6,378),
  `latest_main_run` success on the measured SHA, zero open pull requests,
  `ruleset_drift` in sync, tag `v0.1.0`, release note `v0.1.0.md` and GitHub
  Release `v0.1.0` (pre-release, published 2026-10-12T16:26Z), D1, D3, V3 and
  D4 acceptance still unmet in the tree, `scripts_without_named_test` listing
  two scripts.
- **Assumed** (carried from [[2026-10-12]], not re-verified): C5's on-screen
  results, the notarization and `spctl` results for the rebuilt `.dmg`, the
  eight asset sizes, and that V5 has not been run (no log mentions it).
- **Unverifiable** this run: whether the exports launch on a clean machine
  (B7); the local suite, since `game/gut_results.xml` dates from 2026-09-15 and
  reads 26/294/6,312 against the stated 28/310/6,378.

## Related

- [[2026-09-26-next-build]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) §Phase 2 — Location selection + sub-areas
