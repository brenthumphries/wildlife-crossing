---
title: "Build Review — Next Build (2026-07-07)"
date: 2026-07-07
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **first working build** (P0 first playable =
> roadmap [[roadmap|Phases 1–2]]). One question: what work is needed to get
> there?

## 1. Summary

- **Build case:** **FIRST working build** (none exists yet). There is no
  `builds/` binary and no `game/export_presets.cfg`, so there is no repo→binary
  path today — the criterion that decides first-vs-next build.
- **Target milestone & exit criteria:** roadmap [Phase 1](../../docs/roadmap.md)
  (core simulation + overpass validation) and [Phase 2](../../docs/roadmap.md)
  (location selection + sub-areas). Phase 1 is engine-complete; Phase 2 is
  unstarted.
- **Headline:** **7 blockers, 0 new code this week.** Phase 1 remains
  functionally complete and green — 10 scripts / 57 tests / 844 asserts passing
  on Godot 4.6.3 headless — but every blocker from last week still stands. The
  gap to the first build is unchanged.
- **Change since last review:** [[2026-07-06-next-build]] — **no game-code or
  doc commits landed.** Git `HEAD` is still `5d0b5b9` (2026-06-28); the working
  tree differs only in `.obsidian/workspace.json` and the `2026-06-28` daily log
  (both already noted last week). The one real change is **procedural**: the
  `weekly-build-review` harness (SKILL.md + `references/note-template.md` +
  `references/inspection-checklist.md`) is now present under `harness/`, so last
  week's "SKILL.md missing" caveat is resolved and this note uses the canonical
  template. All seven blockers below carry forward verbatim.

## 2. Current state (evidence)

Grounded in this week's inspection and a fresh headless test run.

- **Systems (complete, non-stub):** all nine Phase 1 simulation systems +
  `simulation.gd` coordinator in `game/scripts/systems/` (`world_data`,
  `hex_grid`, `pathfinding`, `connectivity_graph`, `habitat_manager`,
  `population_model`, `infrastructure_manager`, `species_manager`, `env_config`,
  `simulation`), the four autoloads (`game_state`, `event_bus`, `debug`,
  `species_registry`), and three constants files. No new systems since last
  review.
- **Data:** all 8 canonical files valid in `game/data/`
  (`tiles`, `species_stats`, `entities`, `segments`, `infrastructure`,
  `milestones`, `sub_areas`, `biome_groups`). World maps **1/12** — only
  `game/data/world/sub_area_7.json` (Bow Valley tutorial).
- **Scenes & wiring:** `game/scenes/Main.tscn` is `run/main_scene` in
  `project.godot`; the four autoloads are registered. `scenes/world/Animal.tscn`
  exists. `scenes/ui/` is still `.gitkeep` only. Headless boot of `Main.tscn` is
  clean — logs *"Tutorial loaded. Press B to build the Bow Valley overpass."*
  with no script errors.
- **Tests:** GUT suite (vendored `tools/godot/Godot_v4.6.3-stable_linux.arm64`,
  `game/.gutconfig.json`) — **10 scripts / 57 tests / 844 asserts, all passing**
  (1.01s). Identical to last week; nothing added or regressed. No system is
  untested.
- **CI:** `.github/workflows/ci.yml` — real workflow (import → GUT headless on
  pinned Godot 4.6-stable). **Test-only; it never exports a binary.** Still no
  guard for the zero-tests-collected silent-pass gap.
- **Build/export:** **no `game/export_presets.cfg`; `builds/` is empty**
  (`.gitkeep`/`.gitignore` only); no GitHub Release; `docs/release-notes/` is
  empty. → decides **first build**.

## 3. Work needed for the first build

Ordered the way you'd actually do it. Unchanged from [[2026-07-06-next-build]]
since no code landed. Each item is buildable.

### Blockers (nothing ships until these exist)

#### B1. World-select controller + `scenes/ui/WorldSelectMap.tscn`
- **Why it blocks:** Phase 2 exit criteria — continuous world→segment zoom with
  ≥16px/12px hysteresis, no loading screens; locked sub-areas desaturated with
  lock indicator and zoom blocked at boundary. None of it exists
  (`scripts/ui/` and `scenes/ui/` are `.gitkeep`).
- **Files/areas:** `game/scripts/ui/world_select_controller.gd`,
  `game/scenes/ui/WorldSelectMap.tscn`.
- **Acceptance:** `world_select_controller_test.gd` green; zoom hysteresis and
  locked-area treatment observable per spec.
- **Depends on:** none.
- **Size:** L
- **Refs:** roadmap Phase 2;
  [crossing-location-selection](../prd/crossing-location-selection.md) (P0);
  ADRs [0013](../../docs/adr/0013-scaffolding-conventions.md),
  [0002](../../docs/adr/0002-hex-grid-topology.md).

#### B2. Connectivity overlay (`connectivity_overlay.gd`)
- **Why it blocks:** Phase 2 exit criterion — orange→teal ~40% opacity overlay,
  pulse on the worst three, segment-mode only, clears on
  confirm/cancel/Escape.
- **Files/areas:** `game/scripts/ui/connectivity_overlay.gd`.
- **Acceptance:** `connectivity_overlay_test.gd` green; overlay reads cached
  ADR 0004 patch-adjacency values and behaves per spec.
- **Depends on:** B1.
- **Size:** M
- **Refs:** roadmap Phase 2;
  [0004 connectivity](../../docs/adr/0004-connectivity-patch-adjacency-graph.md).

#### B3. Confirmation panel (`confirm_panel.gd`)
- **Why it blocks:** Phase 2 exit criterion — budget-gate display; confirm
  passes the correct `(segment, sub_area)` into the construction step;
  click-outside and Escape behave per spec.
- **Files/areas:** `game/scripts/ui/confirm_panel.gd`.
- **Acceptance:** `confirm_panel_test.gd` green; construction step receives the
  right `(segment, sub_area)`.
- **Depends on:** B1.
- **Size:** M
- **Refs:** roadmap Phase 2;
  [crossing-location-selection](../prd/crossing-location-selection.md).

#### B4. Author the remaining 11 sub-area world maps
- **Why it blocks:** Phase 2 needs the 12 sub-areas so locked areas can render
  terrain-only per the map-fog rule; only sub-area 7 exists today.
- **Files/areas:** `game/data/world/<sub_area>.json` (11 more, §12 schema).
- **Acceptance:** `data_validation_test.gd` resolves all 12 world maps; each
  loads via `WorldData.parse_file`.
- **Depends on:** none (data authoring; parallelizable with B1–B3).
- **Size:** L
- **Refs:** roadmap Phase 2; [sub-areas](../prd/sub-areas.md);
  [data-schemas §12](../../docs/data-schemas.md).

#### B5. Phase 2 test suites green
- **Why it blocks:** Phase 2 exit criteria name these suites explicitly.
- **Files/areas:** `game/tests/world_select_controller_test.gd`,
  `connectivity_overlay_test.gd`, `confirm_panel_test.gd`
  (+ `data_validation_test.gd` staying green).
- **Acceptance:** all four collected and passing. Remember GUT only discovers a
  new `*_test.gd` after a re-`--import`.
- **Depends on:** B1, B2, B3, B4.
- **Size:** M
- **Refs:** roadmap Phase 2 exit criteria; [test-plan](../../docs/test-plan.md).

#### B6. Audio placeholder for the crossing cue
- **Why it blocks:** the one open **Phase 1** exit criterion — the cue must be
  *visual + audio* coalesced in a 2s window. The coalesced "+N crossed" visual
  exists; there is no audio asset or playback
  (`game/assets/audio/` is `.gitkeep`), so Phase 1 is not strictly closed.
- **Files/areas:** one asset under `game/assets/audio/`; playback wired into the
  existing coalesced feedback window in `scripts/main.gd`.
- **Acceptance:** cue plays once per coalesced crossing window in a non-headless
  run.
- **Depends on:** none.
- **Size:** S
- **Refs:** roadmap Phase 1 exit criteria;
  [wildlife-overpass-crossing](../prd/wildlife-overpass-crossing.md).

#### B7. Export pipeline (`export_presets.cfg` + build step)
- **Why it blocks:** without an export path there is **no build at all**, even
  once Phases 1–2 are code-complete. No `export_presets.cfg`, no templates, no
  export job.
- **Files/areas:** `game/export_presets.cfg` (Mac/Windows/Linux desktop),
  export templates, a CI export job or a documented local export procedure,
  output into `builds/` / a GitHub Release.
- **Acceptance:** a headless export produces a runnable desktop binary that
  launches to `Main.tscn`.
- **Depends on:** none for the preset; a shippable build depends on B1–B6.
- **Size:** M
- **Refs:** roadmap Phases 1–2; CI `.github/workflows/ci.yml`.

### Core build work (the exit-criteria tasks)

Captured above as B1–B6 (Phase 2 UI trio + map authoring + Phase 1 audio
residue). No separate non-blocking core work this week.

### Verification (tests, CI, export)

#### V1. CI: fail on zero collected tests
- **Why:** GUT exits `0` on "Nothing was run", so CI was previously green while
  running zero tests. A discovery regression could silently reappear.
- **Files/areas:** `.github/workflows/ci.yml`.
- **Acceptance:** CI fails if the GUT summary reports 0 scripts/tests (grep the
  totals or "Nothing was run").
- **Depends on:** none.
- **Size:** S
- **Refs:** [testing-setup](../../docs/testing-setup.md).

### Deferrable / nice-to-have

- Reconcile `HAZARD_AVOIDANCE_MULT` into [data-schemas §10](../../docs/data-schemas.md)
  (flagged in-code, cosmetic).
- Push the three local commits to the GitHub remote; tidy the inert
  `.git/*.lock.*` rename-asides left by the host-shell mount workaround.
- Triage `obsidian-vault/prd/minigame-ideas.md` (still untracked/unassigned to a
  phase) — commit or park. Note it self-flags that "Crossing Architect" overlaps
  the core loop.
- Non-headless display QA of the placeholder renderer + `Animal.tscn`.
- Phase 5 gates (liaison-NPC decision, cultural-advisor review) remain open but
  do not block P0.

## 4. Doc drift to fix

Record only — docs not edited during a review.

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | Written when `game/` was "almost entirely `.gitkeep`" | `game/` now holds a complete Phase 1: 10 systems, 8 data files, 10 test scripts (57 tests green), CI, a runnable placeholder scene. Only Phase 2 UI, 11 maps, audio, and export remain. |
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | Lists "GUT not vendored" as an open B0 blocker | GUT 9.6.0 is vendored at `game/addons/gut/`; suite runs green in-engine. |
| [roadmap.md](../../docs/roadmap.md) Phase 1 exit criteria | Implies Phase 1 fully closed once suites are green | Suites are green, but the *audio* half of the "visual + audio placeholder cue" criterion is unmet (B6) — Phase 1 is not strictly closed. |
| CI note in [testing-setup.md](../../docs/testing-setup.md) | Documents the zero-tests silent-pass gap but no guard exists | The gutconfig fix is in; a CI guard (V1) is still not implemented. |

## 5. Risks & open questions

- **No owner-blocking questions remain in P0.**
  [p0-open-questions.md](../../docs/p0-open-questions.md) is fully resolved
  (A1–A10, B1–B7) per the 2026-06-28 log.
- **Art dependency.** The real `WorldMap` TileSet, sprites, and the audio cue
  (B6) need assets; `game/assets/*` is empty. Headless can't QA rendering — a
  display pass is required before the first build is truly "playable".
- **Zero code movement for ~9 days.** Last commit is 2026-06-28; the past two
  review windows show notes-only activity. Not a technical risk, but at the
  current cadence the first build depends on Phase 2 work starting.
- **Export templates / signing** for three desktop platforms may need
  owner-provided templates or a network-allowed CI step (the sandbox is
  network-locked), mirroring how GUT had to be dropped in by hand.

## 6. Suggested next-week focus

Given dependencies and size, pull these first:

1. **B1 — world-select controller + `WorldSelectMap.tscn`** (L). Unblocks B2,
   B3, B5; it is the spine of Phase 2.
2. **B6 — audio placeholder cue** (S). Cheapest close; finishes the last Phase 1
   exit criterion.
3. **B7 — `export_presets.cfg`** (M). Independent; stand up the export path
   early so "build" exists the moment Phases 1–2 are code-complete.
4. **B4 — author sub-area maps** (L). Parallelizable data work; start alongside
   B1.
5. **V1 — CI zero-tests guard** (S). Small hardening so a discovery regression
   can't silently pass.

---

## Related

- [[roadmap]]
- [[pre-build-checklist]]
- [[testing-setup]]
- Previous review: [[2026-07-06-next-build]]
