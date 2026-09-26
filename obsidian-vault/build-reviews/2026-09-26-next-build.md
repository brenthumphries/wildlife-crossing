---
title: "Build Review — Next Build (2026-09-26)"
date: 2026-09-26
tags: [build, review, planning]
status: active
---

> Weekly plan. One question: what work must be done to produce the next
> working build, and who does each piece? The routed plan is
> [`docs/plan/week.json`](../../docs/plan/week.json); `tools/warden.py day`
> dispatches from it.

> [!info] Snapshot
> Measured against **`becf605`** (*Merge pull request #43 from
> brenthumphries/docs/log-2026-09-25d*, 2026-09-26T09:45:55-05:00) on `main`,
> via `docs/plan/facts.json` written 2026-09-26T14:49:50+00:00. GitHub read
> 2026-09-26T14:49:46+00:00 via `gh`. Suite as stated in
> `docs/testing-setup.md` and checked by CI: **28 scripts / 310 tests / 6,378
> asserts**. Latest run on `main`: **success** on `becf605` at
> 2026-09-26T14:45:58Z. Previous plan: [[2026-09-14-next-build]].

## 1. Readiness

**Build case: first.** Every blocker but two has closed since 2026-09-14.
B1b (Apple enrolment, certificate, API key) is done; B4 (the packaging
decision) is done, archive not `embed_pck`, and its implementation landed as
C1 and C2 in PR #37. C3, C7, and V4 are also done. What's left is C5 (the
visual and audio QA walk) and C6 (the website download copy), both unblocked
and neither started, which is what keeps B6 (the release cut) and B7 (the
clean-Mac acceptance test) open behind them.

**Verdict: not-ready.** Open blockers: B6, B7.

## 2. What changed since 2026-09-14

- **Landed:** PRs #21–#30, #32, #34, #35 (C10, V1, V2, D2, V8, C11, V7, C3,
  V6, V11, V10, C9, V4, ten items merged 2026-09-23, plus C9 and V4 the
  next day) and #37 (C1, C2). 26 pull requests in total since the last plan;
  the full list is `github-state.json`'s `recent_merged_pulls`.
- **Closed:** C4 (tutorial camera stays at (13, 6), no code change, decided
  2026-09-23) and C9 (Phase 2's fourth exit criterion dispositioned in the
  roadmap, decided 2026-09-23), both decisions with no items of their own left.
  B1b closed 2026-09-25 (A2/A3/A4 all confirmed; [[2026-09-25]] third and
  fourth threads). B4 closed 2026-09-23 ([[2026-09-23]] Decisions made),
  implementation landed as C1 and C2 via PR #37, merged 2026-09-26.
- **New facts:** CI's `Export desktop builds` job broke the moment C1
  landed: `codesign/codesign=3` and `notarization/notarization=2` need Xcode
  tools this `ubuntu-latest` runner does not have. Fixed as PR #42: CI no
  longer exports macOS at all; the release `.dmg` is built and checked only
  on the Mac now. `docs/export-setup.md` and `docs/signing-runbook.md` Part D
  updated to match ([[2026-09-25]] fourth thread).
- **Decisions:** 2026-09-23: B4 (archive per platform), C4 (camera focus),
  C9 (Phase 2 criterion), V4 (arm64 sandbox-only). 2026-09-25: C2 stays
  scoped to the local Mac; CI drops macOS export rather than adding a
  `macos-latest` runner (a bigger, separate decision, declined for now).

## 3. This week

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | C5 | Visual and audio QA pass, written down | mac | human | S | — |
| 2 | C6 | Website download-section copy | docs | sonnet / auto | S | — |
| 3 | D1 | Retire or rewrite pre-build-checklist.md | docs | sonnet / auto | S | — |
| 4 | V3 | Close the test-plan.md §11 P0 rows | docs | sonnet / auto | S | — |
| 5 | V5 | Exercise the dco job unsigned | mac | human | S | — |
| 6 | D3 | Fix a stale line in signing-runbook.md Part D | code | haiku / auto | S | — |
| 7 | D4 | Document the project.godot comment-loss risk | docs | sonnet / auto | S | — |
| 8 | B6 | Cut v0.1.0 | mac | human | M | C5, C6 |
| 9 | B7 | Walk signing-runbook A8 on a clean Mac | mac | human | S | B6 |

1 code item (D3, on Haiku), 4 for Cowork (C6, D1, V3, D4), 4 yours (C5, V5,
B6, B7). The dispatch picks D3 and C6 first.

### Yours this week

- **C5.** The QA walk `docs/roadmap.md` §Phase 2 exit criteria still wants:
  the connectivity overlay's orange-to-teal treatment at segment zoom, the
  HUD and credits screen at the new `[display]` settings, the Mac's Godot
  version. Unblocks nothing but itself and B6.
- **V5.** Fifteen minutes with `gh`: an unsigned commit on a throwaway pull
  request should fail the dco check, then pass once signed off. Proves the
  gate ADR 0019 and 0020 rest on.
- **B6.** The v0.1.0 cut, once C5 and C6 are done: release note, tag, signed
  GitHub Release, `builds/` cleared before the manifest sweep. The real
  signed `.dmg` finally gets checked with `check_pck_contents.py` here. C2
  never got that verification locally, and B6 is where it happens.
- **B7.** The actual acceptance test, once B6 lands: download the Release
  DMG on a Mac that's never had the project, no Gatekeeper warning of any
  kind.

## 4. Drift and risks

- **`game/project.godot` can silently lose every comment.** Happened live
  2026-09-25, most likely from the editor resaving the file when the export
  preset was opened for signing. Caught before it landed in any commit; no
  fix is known yet, only a documented pre-commit check (D4).
- **`docs/signing-runbook.md` Part D point 3 names an open build-review item
  (V2) that looks closed elsewhere in the repo.** D3 fixes the line.
- **`tools/ship.py --execute --allow-branch-mismatch` used to commit onto
  whatever branch was checked out, not the plan's own branch.** Fixed
  2026-09-25 (PR #40); no open item, already closed.

## Verification

- **Confirmed** (`facts.json` at `becf605`; github-state at
  2026-09-26T14:49:46+00:00): the suite figure (28/310/6,378), `latest_main_run`
  success on the measured SHA, zero open pull requests, `ruleset_in_sync`
  true, `build_case` first (no tags, no release notes).
- **Assumed** (carried from [[2026-09-25]], not re-verified this run): B1b's
  A2/A3/A4 completion, C7's `godot` on `PATH`.
- **Unverifiable** this run: whether the real signed `.dmg` export actually
  launches and passes Gatekeeper (B6/B7's job); the state of C5's QA items on
  screen, since that needs eyes on the Mac, not a file read.

## Related

- [[2026-09-14-next-build]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) §Phase 2 — Location selection + sub-areas
