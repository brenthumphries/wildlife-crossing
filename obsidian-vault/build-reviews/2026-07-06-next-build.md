---
title: "Build Review — 2026-07-06 — Next Build"
date: 2026-07-06
tags: [build, review]
status: active
---

# Build review — 2026-07-06

> **Procedural note.** The `weekly-build-review` SKILL.md was found in neither
> `.claude/skills/weekly-build-review/` nor `harness/weekly-build-review/` (the
> `harness/` folder contains only `.DS_Store` — the skill file appears never to
> have been copied in). This review follows the 6-step procedure described in
> the scheduled task (orient → inventory via subagent → run tests → gap
> analysis → write → verify) with a reconstructed note template. Restore the
> SKILL.md before next week's run so the canonical template is used.

## Headline

**Build case: FIRST working build (none exists yet).** Phase 1 (core simulation
+ overpass validation) is functionally complete, committed (`5d0b5b9`), and
green — 10 scripts / 57 tests / 844 asserts passing on Godot 4.6.3 headless.
The first working build is defined as the **first playable = P0 = roadmap
Phases 1–2** ([pre-build-checklist](../../docs/pre-build-checklist.md)). Phase 2
(location selection + sub-areas) is entirely unstarted, and there is no export
pipeline. **7 blockers** stand between the current repo and the first build.

## Changes since last review

This is the first build review (index was empty). Baseline state:

- Git: 3 commits on `main`; latest `5d0b5b9 feat(game): Phase 1 simulation
  systems + runnable tutorial` (2026-06-28). Nothing pushed to a remote.
- Working tree since that commit: only notes — untracked
  `obsidian-vault/prd/minigame-ideas.md` (draft, 2026-07-06, minigame concepts;
  not assigned to any roadmap phase) and a modified daily log. No game-code
  changes in over a week.

## Test suite (run this review, 2026-07-06)

Command per [testing-setup](../../docs/testing-setup.md), on the vendored
`tools/godot/Godot_v4.6.3-stable_linux.arm64`: `--headless --import`, then
`--headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.

- **10 scripts / 57 tests / 844 asserts — all passing** (0.975s).
- Matches the Phase 1 commit exactly: no tests added or regressed since.
- All five roadmap-named Phase 1 exit-criteria suites green (`pathfinding`,
  `infrastructure_manager`, `connectivity_graph`, `habitat_manager`,
  `population_model`), plus `hex_grid`, `world_data`, `species_manager`,
  `simulation`, `data_validation`.

## Repo state (inventory)

- **Systems (complete):** all nine Phase 1 simulation systems + `simulation.gd`
  coordinator, four autoloads, three constants files. No TODO/FIXME stubs.
- **Scenes (placeholder):** `Main.tscn` + `world_renderer.gd` colored-shape
  renderer, `world/Animal.tscn`. Game boots headless and the core loop runs.
- **Phase 2 (absent):** no `world_select_controller.gd`,
  `connectivity_overlay.gd`, `confirm_panel.gd`; `scripts/ui/` and `scenes/ui/`
  hold only `.gitkeep`; no `WorldSelectMap.tscn`; none of the three Phase 2
  test files exist.
- **Data:** all 8 canonical data files valid; **world maps 1/12** — only
  `data/world/sub_area_7.json` (Bow Valley tutorial).
- **Assets:** `game/assets/{audio,fonts,sprites,tilesets}` all empty
  (`.gitkeep` only). No audio file exists for the crossing cue.
- **Export:** no `export_presets.cfg`; `builds/` empty; CI
  (`.github/workflows/ci.yml`) is test-only — it never exports a binary.

## Gap analysis vs roadmap exit criteria

Phase 1 ([roadmap](../../docs/roadmap.md)) exit criteria: routing/mortality,
full-vs-partial span, `animal_crossed` semantics, and the five named suites are
all met and engine-verified. One residue: the criterion requires a **visual +
audio** placeholder cue — the coalesced "+N crossed" visual exists, but there
is no audio asset or playback, so Phase 1 is not strictly closed.

Phase 2 exit criteria (zoom + hysteresis, locked-area treatment, overlay
behaviour, confirm flow, four suites green): **0 of 4 met** — nothing
implemented.

## Blockers — work required for the first working build

1. **World-select controller + `scenes/ui/WorldSelectMap.tscn`** — Y2Y world
   map, toolbar tool, continuous zoom with ≥16px/12px hysteresis, locked
   sub-area treatment (desaturate + lock, zoom blocked). All P0 in
   [crossing-location-selection](../prd/crossing-location-selection.md);
   conventions per ADR 0013.
2. **Connectivity overlay** (`connectivity_overlay.gd`) — orange→teal ~40%
   opacity, pulse on worst three, segment-zoom only, clears on
   confirm/cancel/Escape; reads cached ADR 0004 values.
3. **Confirmation panel** (`confirm_panel.gd`) — budget-gate display, passes
   `(segment, sub_area)` into construction, cancel / Escape / click-outside
   per the resolved decisions.
4. **Author the remaining 11 sub-area world maps** as
   `data/world/<sub_area>.json` (only sub-area 7 exists; 12 required so locked
   areas can render terrain-only per the Phase 2 map-fog rule).
5. **Phase 2 test suites** — `world_select_controller_test.gd`,
   `connectivity_overlay_test.gd`, `confirm_panel_test.gd` written and green
   (plus `data_validation_test.gd` staying green). Remember GUT collects new
   test files only after a re-`--import`.
6. **Audio placeholder for the crossing cue** — one sound asset + playback
   wired into the existing coalesced feedback window, closing the last Phase 1
   exit criterion.
7. **Export pipeline** — `export_presets.cfg` for the three desktop platforms,
   export templates, and a build step (CI job or documented local procedure)
   that actually produces a binary into GitHub Releases. Without this there is
   no "build" at all, even once Phases 1–2 are code-complete.

## Non-blocking follow-ups (carry-forwards)

- CI hardening: fail on zero collected tests ("Nothing was run" grep) so a
  discovery regression can't go green again.
- Reconcile `HAZARD_AVOIDANCE_MULT` into data-schemas §10 (flagged in-code).
- Push the three local commits to the GitHub remote; tidy the inert
  `.git/*.lock.*` rename-asides from a host shell.
- Triage the new `minigame-ideas.md` PRD (untracked, unassigned to any phase)
  and commit or park it.
- Visual/display QA of the placeholder renderer needs a non-headless pass.
- The two Phase 5 gates (liaison-NPC decision, cultural-advisor review) remain
  open but do not block P0.

## Verification

- Test run performed fresh this review (not taken from logs): 57/57 green.
- Inventory cross-checked by subagent against roadmap §Phase 2 and the
  pre-build checklist; blocker list matches checklist §B2 plus the audio
  residue (§A7) and the export gap (implied by "shippable", not previously
  itemised).
- No game code or docs modified — this note and the index line are the only
  writes.

## Next review

Expect progress on blockers 1–3 (the Phase 2 UI trio) or 4 (map authoring).
Re-run the suite; the pass count should rise above 57 when Phase 2 tests land.
