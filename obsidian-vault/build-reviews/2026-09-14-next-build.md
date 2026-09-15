---
title: "Build Review — Next Build (2026-09-14)"
date: 2026-09-14
tags: [build, review, planning, decision]
status: active
---

> Weekly plan. One question: what work must be done to produce the next
> working build — or the first, if none exists — and who does each piece?
> The routed plan is [`docs/plan/week.json`](../../docs/plan/week.json);
> `tools/warden.py day` dispatches from it. **First note in the new form** —
> short, facts from scripts, every item routed; see
> [`docs/warden.md`](../../docs/warden.md).

> [!info] Snapshot
> Measured against **`fe901a5`** (*Merge pull request #14 from
> brenthumphries/chore/ruleset-state-sync*, 2026-09-10 14:32 -0500) on
> `main`, via `docs/plan/facts.json`. GitHub read 2026-09-10 19:06 UTC via
> `gh` (the tracked `docs/github-state.json`; four days old, and said so).
> Suite as stated in `docs/testing-setup.md` and checked by CI on every run:
> **24 scripts / 246 tests / 3,154 asserts**. Latest run on `main`:
> **success** on `700cd74` (2026-09-09 21:24 UTC); `fe901a5` itself changed
> only `.github/rulesets/protect_main.json` and `docs/github-state.json`.
> Ruleset `22403399` matches its committed copy. Previous plan:
> [[2026-09-08-next-build]] and its three amendments.

## 1. Readiness

**Build case: first.** `facts.build_case` finds no tag, no release note and
no GitHub Release, the same three facts as the ten reviews before it. Every
Phase 1 and Phase 2 exit criterion is met in code and green in tests; that
has not changed since 09-08, and nothing in `facts.json` is red — no invalid
data file, no stub, no orphaned `.uid`, the five CI job names match the five
required contexts. What stands between this tree and something a stranger
can run is release mechanics: signing, packaging, a version string, a QA
walk. Three of the four open blockers are Apple or Mac steps and the fourth
is a decision, so this week's automatable work is the short items on B6's
critical path that wait on nobody — and the two test gaps and the pack-gate
assertion that make the next review cheaper to trust.

**Verdict: not-ready** — open blockers: **B1b** (Apple, since 08-27),
**B4** (packaging decision), **B6** (the release), **B7** (the clean-Mac
walk).

## 2. What changed since 2026-09-08

- **Landed:** PRs #9–#14 — the 09-09 vault notes, ADR 0020 pointers,
  process-repair phase 2 (`check_required_contexts.py`,
  `suite_figures.py`, `github_state.py`, `check_citations.py`, the skill
  relocation), and the ruleset state sync. Zero game code.
- **Closed:** **B8** (PR #8, per the 09-09 amendment). **C8** — both halves
  met per amendment 2026-09-09b; the one leftover is the wrong date in
  `pipeline-design.md`, which becomes **D2** below.
- **New facts:** `tools/github_state.py` has now been run (read_at
  2026-09-10), so the 09-09 log's first open question is closed; the
  applied ruleset matches the committed copy. `ship.py`'s rename bug and
  the single-mode Tool tests job are still open (09-09 log) and are **V10**
  and **V11**.
- **Decisions, 2026-09-14 (Brent):** code changes go to Claude Code on
  Sonnet or Haiku in auto mode where possible; non-code work stays in
  Cowork; work is routed to the cheapest capable model; the weekly plan
  runs as a cloud routine with the repository attached, on Sonnet; the long
  review form is replaced by this one; the daily dashboard routine is
  retired in favour of `warden status` and `warden day`.

## 3. This week

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | C3 | Version metadata in the export presets | code | sonnet / supervised | S | — |
| 2 | C10 | `[display]` section so HUD and credits are legible | code | sonnet / auto | M | — |
| 3 | V1 | `env_config_test.gd` | verify | sonnet / auto | S | — |
| 4 | V8 | Pack gate names the two runtime assets | code | sonnet / auto | S | — |
| 5 | D2 | Public-since date in `pipeline-design.md` | docs → code | haiku / auto | S | — |
| 6 | V2 | Constants tests | verify | sonnet / auto | S | V1 |
| 7 | C11 | `check_pck_contents.py` reads a `.dmg` | code | sonnet / auto | M | V8 |
| 8 | V7 | `build_encyclopedia.py` deletes, with tests | code | sonnet / auto | M | — |
| 9 | V10 | `ship.py` renames, with a test | code | sonnet / supervised | S | — |
| 10 | D1 | Retire or rewrite `pre-build-checklist.md` | docs | sonnet (Cowork) | S | — |
| 11 | V3 | `test-plan.md` §11 rows name a test or a deferral | docs | sonnet (Cowork) | S | — |
| 12–13 | V6, V11 | CI guard reports why; Tool tests runs in both modes | verify | supervised | S | V2 → V6 |
| 20–23 | C4, C9, B4, V4 | Four decisions | decision | you | S–M | — |
| 30–32 | C7, C5, B1b | Godot on the Mac; the QA walk; Apple | mac | you | S | C5 ← C4, C10 |
| 40–43 | C1, C2, C6, V5 | Signing preset; `.dmg` target; download copy; dco check | mixed | supervised / Cowork / you | S–M | B1b, C11, B4 |
| 50–51 | B6, B7 | The release; the clean-Mac walk | mac | you | M, S | everything above |

Twenty-six items, all of them the open items from 09-08 reconciled plus
four new ones (C10, C11, V10, V11 — three splits of items whose code half
was hiding inside a Mac or forbidden-path item, and one from the 09-09 log).
Eight run in Claude Code unattended, two supervised, three in Cowork, the
rest are yours or wait. The dispatch picks **C10 and V1** first (C3 is
supervised, so it takes no unattended slot), then V8 and D2 as those merge.

### Yours this week

- **C4 — camera focus.** Keep `(13, 6)`, or point the opening camera at rows
  0–2 where the deaths and crossings are? One dated line in a log. C5 waits
  on it. Open since 08-10.
- **C9 — Phase 2's fourth exit criterion.** Met in tests, unreachable in the
  artifact. Deferred-and-acceptable, or deferred outright? Once you say,
  `warden cowork C9` drafts the roadmap block.
- **B4 — how a Release ships.** One archive per platform is the
  recommendation (it is the only shape that carries the licence files
  inside the asset). Your call unblocks C6 and the supervised
  implementation.
- **V4 — the arm64 preset.** Export it in CI, or delete it. Before B6.
- **C7 — Godot 4.6.3 on the Mac.** Lead time, nothing interesting, and it
  is what lets `warden run` tasks test locally instead of trusting CI.
- **B1b — Apple.** Check the enrolment; do A3 (the Xcode licence) today.
- **V5 — fifteen minutes with `gh`** to see the dco job go red once.

## 4. Drift and risks

- `docs/pipeline-design.md` §6.2 says the repository went public on
  2026-09-05; it was 2026-08-29 → **D2**.
- `docs/pre-build-checklist.md` still describes a project with no Godot
  code, on a public repository → **D1**.
- `docs/pipeline-design.md` §9.2's daily dashboard is superseded by
  `docs/warden.md` (recorded in `docs/automation.md`; no item, it is history).
- `README.md`'s tree named `harness/`, which no longer exists; corrected in
  this note's pull request.
- **Risks:** until C7 lands, automated code tasks have CI as their only
  test signal — fine for S items; read C10's and C11's briefs carefully.
  `--permission-mode auto` is unexercised here; `--interactive` is the fallback.

## Verification

- **Confirmed** (facts.json at `fe901a5`; github-state at 2026-09-10 19:06):
  the build-case facts; 30 scripts, 24 test files, 0 invalid data files,
  0 stubs, 0 `.uid` orphans; CI job names match required contexts; `main`
  green on `700cd74`; ruleset in sync; 0 open PRs and issues at read time;
  the 09-05 date in `pipeline-design.md`; empty version fields in
  `export_presets.cfg`; no `[display]` section; no `env_config` or
  constants test.
- **Assumed** (carried from [[2026-09-08-next-build]] and its amendments,
  and [[../daily-logs/2026-09-09]], not re-verified): the exit criteria
  being met in code; the 09-02 legibility failure; B1b still pending with
  Apple; the `ship.py` rename defect; the specific acceptance wording of
  every carried item.
- **Unverifiable** this run: GitHub after 2026-09-10 19:06 UTC (the next
  `warden sync` will say); whether any export launches; Godot on the Mac.

## Related

- [[2026-09-08-next-build]]
- [[../daily-logs/2026-09-09]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [`docs/warden.md`](../../docs/warden.md)
- [roadmap](../../docs/roadmap.md) §Phase 1 and §Phase 2 exit criteria
