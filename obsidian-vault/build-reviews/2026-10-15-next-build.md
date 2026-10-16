---
title: "Build Review — Next Build (2026-10-15)"
date: 2026-10-15
tags: [build, review, planning]
status: active
---

> Weekly plan. One question: what work must be done to produce the next
> working build, and who does each piece? The routed plan is
> [`docs/plan/week.json`](../../docs/plan/week.json); `tools/warden.py day`
> dispatches from it.

> [!warning] Amendment 2026-10-15 — **Q4's deficit proposal is corrected, and C13 gains the budget save sync.**
> The proposal below for how a crossing's deficit is measured (one minus the
> larger network's share of the combined total) tops out at 0.5 for a link
> between two networks, so the multiplier could never reach 2.0. The plan now
> proposes the share of the largest network that the link newly joins to it,
> capped at 1: two equal halves score 1.0, a sliver joined to a large network
> scores near 0. Separately, C12 (PR #57) added the economy manager without
> wiring its balance into the save path, so C13's acceptance now requires the
> sync. Both changes are in `docs/plan/week.json`; nothing else in the plan
> moves.

> [!success] Amendment 2026-10-15 (evening) — **C12, C13, C16 and D3 are closed, and Q4 is decided.**
> Merged pull requests: C12 in #57, D3 in #58, C13 in #60 (walked windowed by
> Brent: the budget drops per tile, F5 then F9 keeps it, an over-budget build is
> refused) and C16 in #61. Q4 was accepted as recommended and recorded in the
> second Phase 3 Decision logged block of `docs/roadmap.md` (#59). The
> dispatch still shows C14, C15 and C17 as blocked, because it cannot see a
> decision as done; the next weekly plan marks Q4 done. C18 also waits on Q5.
> The suite is now 29 scripts / 335 tests / 6,434 asserts. See
> [[../daily-logs/2026-10-15]].

> [!info] Snapshot
> Measured against **`d013c6d`** (*Merge pull request #55 from
> brenthumphries/docs/log-2026-10-15-q1*, 2026-10-15T21:36:19-05:00) on
> `main`, via `docs/plan/facts.json` written 2026-10-16T02:50:10+00:00. GitHub
> read 2026-10-16T02:50:10+00:00 via `gh`. Suite as stated in
> `docs/testing-setup.md` and checked by CI: **28 scripts / 310 tests / 6,378
> asserts**. Latest run on `main`: **success** on `d013c6d` at
> 2026-10-16T02:36:23Z. Previous plan: [[2026-10-12-next-build]].
> Mid-week re-run: written Thursday 2026-10-15 for the week of 2026-10-12, at
> Brent's request, to route Phase 3. This overrides `edit_midweek: never` for
> one run; the earlier note stands unamended.

## 1. Readiness

**Build case: next.** v0.1.0 is published. B7 is half done: on 2026-10-15 the
DMG opened on a clean Mac with no Gatekeeper warning and the downloaded
`SHA256SUMS.txt` verified against its `.asc`, but the Windows and Linux launch
checks are deferred until a machine is free (Linear ATT-62). The next build is decided: Phase 3 (economy and
information), then Phase 2 completion.

**Verdict: not-ready.** Open blockers: B7.

## 2. What changed since 2026-10-12

- **Landed:** PR #54 (the 2026-10-12 plan) and PR #55 (the 2026-10-15 log, the
  Phase 3 decision, the YouTube pipeline files). From `recent_merged_pulls`.
- **Closed:** Q1 (Phase 3 is the next build; [[2026-10-15]], PR #55).
- **Part closed:** B7, the Gatekeeper and checksum halves ([[2026-10-15]]).
- **New facts:** nothing in `facts.json` beyond last week's two
  `scripts_without_named_test` (V12).
- **Decisions:** 2026-10-15, Brent: Phase 3 next and Phase 2 completion after
  it; milestone bonuses pay 0 until Phase 6; the liaison briefing moves to
  Phase 5; the fragmentation deficit is stored on the crossing.

## 3. This week

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | B7 | Windows and Linux halves of runbook A8 | mac | human | S | none |
| 2 | Q2 | Decide whether D4 is still wanted | decision | human | S | none |
| 3 | Q4 | Settle the fragmentation deficit and the information save shape | decision | human | S | none |
| 4 | Q5 | Decide where a revealed layer shows | decision | human | S | none |
| 5 | C12 | Economy manager, starting budget, spend and credit | code | sonnet / auto | M | none |
| 6 | C13 | Charge for crossings, functional budget gate | code | sonnet / auto | M | C12 |
| 7 | C16 | Budget and last donation on the HUD | code | sonnet / auto | S | C12, C13 |
| 8 | C14 | Store the fragmentation deficit on each crossing | code | sonnet / supervised | M | C12, Q4 |
| 9 | C15 | Monthly donations and the trickle | code | sonnet / auto | M | C12, C14 |
| 10 | C17 | Information manager, three area products | code | sonnet / auto | M | C12, Q4 |
| 11 | C18 | Show purchased layers in the game | code | sonnet / supervised | M | C17, Q5 |
| 12 | V12 | Name a test for the two minigame scripts or exempt them | verify | sonnet / auto | S | none |
| 13 | D3 | Fix a stale line in signing-runbook.md Part D | docs | haiku / auto | S | none |
| 14 | V3 | Close the test-plan.md §11 P0 rows | docs | sonnet / auto | S | none |
| 15 | D1 | Retire or rewrite pre-build-checklist.md | docs | sonnet / auto | S | none |
| 16 | D4 | Document the project.godot comment-loss risk | docs | sonnet / auto | S | Q2 |
| 17 | V5 | Exercise the dco job unsigned | mac | human | S | none |
| 18 | Q3 | Decide whether HUD text size earns an item | decision | human | S | none |

7 code items (C12 to C18, two of them supervised), 3 for Cowork (V3, D1, D4),
6 yours (B7, Q2, Q4, Q5, V5, Q3), plus V12 and D3 for Claude Code. The dispatch picks C12
and D3 first; V12 shares `docs/testing-setup.md` with C12 and waits. The roadmap
named five Phase 3 items: C12 is its first, C13 its second, C14 to C16 split its
third, C17 its fourth and C18 its fifth. The week's focus is the first eight.

### Yours this week

- **Q4.** Two spec gaps. The PRD's fragmentation multiplier comes from a
  "pre-crossing connectivity deficit" that nothing defines. The plan proposes
  deficit = 1 minus the larger pre-crossing network's share of the combined
  network, mapped linearly onto 1.0 to 2.0. Also: does the new optional field on
  `crossings[]` bump `save_version`, and how is a purchased product recorded
  when `areas_revealed[]` cannot say which of three it was. Unblocks C14, C15
  and C17.
- **Q5.** The confirm panel and segment label are unreachable in v0.1.0, so the
  only live surfaces are the HUD and build mode. Proposal: a keyboard-opened
  survey panel like the F2 and F3 overlays. Unblocks C18.
- **Q2.** Keep, rewrite or drop D4. Unblocks D4.
- **B7.** The Windows and Linux launch checks, when a machine is available.
- **V5, Q3.** Unchanged.

## 4. Drift and risks

- **The dispatch cannot see a decision as done.** Q4 and Q5 block C14, C15, C17
  and C18 until the next weekly plan marks them done. Log the answer the day
  you give it and expect the unblock on Monday 2026-10-19 or a mid-week re-run.
- **Test-plan names are now acceptance criteria.** `docs/test-plan.md` §6 and §7
  already list the economy and information tests by name; V3 (the §11 P0
  rows) should be done before these land so the table is not edited twice.
- **Every Phase 3 test file moves the stated suite figure.** Each item updates
  one line in `docs/testing-setup.md`, so those items serialise.

## Verification

- **Confirmed** (`facts.json` at `d013c6d`; github-state at
  2026-10-16T02:50:10+00:00): `latest_main_run` success on the measured SHA,
  zero open pull requests, ruleset in sync, tag `v0.1.0`, release note and
  GitHub Release, suite figure as stated, `scripts_without_named_test` listing
  two scripts. `tools/warden.py day --no-write` validates the plan.
- **Read from the tree this run** (not in `facts.json`): the economy constants,
  the three EventBus signals, a budget that defaults to 0 and a minimum
  crossing cost of 0 in `main.gd`, `status_weight` on every species, and the
  absence of `economy_manager.gd` and `information_manager.gd`.
- **Assumed** (carried from [[2026-10-15]]): the clean-Mac Gatekeeper and
  checksum results, and that V5 has not been run.
- **Unverifiable** this run: whether any Phase 3 item fits its size until a
  run tries it; whether the Windows and Linux binaries launch (B7).

## Related

- [[2026-10-12-next-build]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) §Phase 3
