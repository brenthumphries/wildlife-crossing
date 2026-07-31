---
title: "Build Reviews"
date: 2026-07-06
tags: [build, review, index]
status: active
---

# Build Reviews

Weekly build-review notes produced by the `weekly-build-review` harness. Each
note answers one question: **what work is needed to reach the next working build
(or the first working build, if none exists yet)?**

Notes are named `YYYY-MM-DD-next-build.md`. Newest first.

## Index

<!-- Add one line per review, newest at top: -->
<!-- - [[YYYY-MM-DD-next-build]] — one-line headline (N blockers) -->

- [[2026-07-28-next-build]] — First build; the first binaries in project history exist. **Its B1 headline ("the pck ships zero game data") was later disproved** — see [[../daily-logs/2026-07-28]]; the pack was always complete and boots clean. **B2, B3, B4, B5, and B6 have since closed** (2026-07-28/29/30 logs) — a macOS `.app` has been launched and confirmed playable, the overpass follows ADR 0016's span geometry instead of paving whole segments, and the player now places spans directly (build mode, ghost preview, running cost) instead of a hardcoded default. **No build-review blockers remain open**; only C1 (visual cue + minimal HUD) stands before v0.1.0 (V7)
- [[2026-07-21-next-build]] — First build; last review's 7 blockers all closed and the suite doubled to 116/116 green, but the span defect, the missing visual cue, unimplemented hover highlight, 11 unreachable sub-areas, and zero binaries ever exported open 5 new ones
- [[2026-07-07-next-build]] — First build; no code change this week (HEAD still `5d0b5b9`, 57/57 green), harness now installed, same 7 blockers
- [[2026-07-06-next-build]] — First build; Phase 1 complete & 57/57 green, Phase 2 unstarted, no export pipeline (7 blockers)

## How to run

Invoke the `weekly-build-review` skill (Opus model) in this repo, or ask:
"Run the weekly-build-review for Wildlife Crossing." See
`harness/weekly-build-review/SKILL.md`.
