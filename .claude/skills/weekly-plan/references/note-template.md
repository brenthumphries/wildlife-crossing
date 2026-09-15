---
title: "Build Review — Next Build ({{DATE}})"
date: {{DATE}}
tags: [build, review, planning]
status: active
---

> Weekly plan. One question: what work must be done to produce the next
> working build — or the first, if none exists — and who does each piece?
> The routed plan is [`docs/plan/week.json`](../../docs/plan/week.json);
> `tools/warden.py day` dispatches from it.

> [!info] Snapshot
> Measured against **`{{SHA7}}`** (*{{HEAD_SUBJECT}}*, {{HEAD_DATE}}) on
> `main`, via `docs/plan/facts.json` written {{FACTS_WRITTEN_AT}}. GitHub
> read {{GH_READ_AT}} via {{GH_VIA}}. Suite as stated in
> `docs/testing-setup.md` and checked by CI: **{{SCRIPTS}} scripts /
> {{TESTS}} tests / {{ASSERTS}} asserts**. Latest run on `main`:
> **{{RUN_CONCLUSION}}** on `{{RUN_SHA7}}` at {{RUN_AT}}. Previous plan:
> [[{{PREVIOUS_NOTE}}]].

## 1. Readiness

**Build case: {{first|next}}.** {{One paragraph: what the verdict rests on,
which blockers are open, what changed it since last week. Cozy, honest.}}

**Verdict: {{ready|not-ready}}** — open blockers: {{B4, B6 — or "none"}}.

## 2. What changed since {{PREVIOUS_DATE}}

- **Landed:** {{PR #n — title (item id)}}, … — from github-state
  `recent_merged_pulls`.
- **Closed:** {{item id — evidence (log date or PR)}}.
- **New facts:** {{anything facts.json reports that last week's note did not
  know — or "nothing"}}.
- **Decisions:** {{from daily logs, one line each, dated}}.

## 3. This week

| # | Id | Item | Lane | Model / mode | Size | Depends on |
|---|----|------|------|--------------|------|------------|
| 1 | B4 | … | code | sonnet / auto | M | — |
| 2 | C8 | … | docs | sonnet / auto | S | — |
| 3 | C7 | … | mac | human | S | — |

{{One line under the table: how many code items, how many for Cowork, how
many yours, and the two the dispatch will pick first.}}

### Yours this week

{{For each `decision` / `mac` item: the id, the question or the action, and
what it unblocks. This is the part of the note the operator must read.}}

## 4. Drift and risks

{{Only new rows. Each: the doc, the stale claim, the correction, and the item
id that fixes it — a drift row without an item is a row that never closes.
Cap at ten bullets.}}

## Verification

- **Confirmed** (facts.json at `{{SHA7}}`; github-state at {{GH_READ_AT}}):
  {{list the claims}}.
- **Assumed** (carried from {{log or review}}, not re-verified): {{list}}.
- **Unverifiable** this run: {{CI on unpushed work; whether an export
  launches; anything GitHub-side if the state file is older than a day}}.

## Related

- [[{{PREVIOUS_NOTE}}]]
- [`docs/plan/week.json`](../../docs/plan/week.json)
- [`docs/plan/routing.md`](../../docs/plan/routing.md)
- [roadmap](../../docs/roadmap.md) §{{Phase}}
