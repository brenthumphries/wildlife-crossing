---
title: "Build Review — Next Build ({{DATE}})"
date: {{DATE}}
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **{{BUILD_CASE}}** — either the *first working
> build* (P0 first playable = roadmap Phases 1–2) or the *next working build*
> (next roadmap milestone). One question: what work is needed to get there?

## 1. Summary

- **Build case:** first build / next build (state which, and why).
- **Target milestone & exit criteria:** {{link roadmap phase}}.
- **Headline:** N blockers, M core tasks. One-paragraph read on where the
  project stands versus the target.
- **Change since last review:** {{link previous build-review note}} — what
  closed, what's still open, what's new.

## 2. Current state (evidence)

Grounded snapshot from this week's inspection and test run.

- **Systems:** which exist / are real / are stubbed (paths).
- **Data:** which data files present and valid.
- **Scenes & wiring:** Main.tscn and autoloads.
- **Tests:** GUT run result (pass/fail counts); systems with no test.
- **CI:** present? what it runs.
- **Build/export:** export preset? any binary? — the fact that decides the
  build case.

## 3. Work needed for the next/first build

Ordered the way you'd actually do it. Each item is buildable.

### Blockers (nothing ships until these exist)

#### B1. {{Title}}
- **Why it blocks:** {{roadmap exit criterion / ADR / observed failure}}
- **Files/areas:** {{paths}}
- **Acceptance:** {{test or observable behavior}}
- **Depends on:** {{item ids or "none"}}
- **Size:** S / M / L
- **Refs:** {{roadmap phase, ADR nnnn, PRD section}}

### Core build work (the exit-criteria tasks)

#### C1. {{Title}}
- (same fields)

### Verification (tests, CI, export)

#### V1. {{Title}}
- (same fields)

### Deferrable / nice-to-have

- Short bullets; not required for this build.

## 4. Doc drift to fix

Docs that no longer match reality (record only — do not edit docs during a
review).

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| pre-build-checklist.md | "game/ is almost entirely .gitkeep" | {{what's actually there now}} |

## 5. Risks & open questions

Anything needing an owner decision before it can be built. Link
`docs/p0-open-questions.md`-style items.

## 6. Suggested next-week focus

The top 3–5 items to pull first, given dependencies and size.

---

## Related

- [[roadmap]]
- [[pre-build-checklist]]
- Previous review: {{link}}
