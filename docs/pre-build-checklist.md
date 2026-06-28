---
title: "Pre-Build Checklist — First Playable (P0)"
date: 2026-06-28
tags: [build, planning]
status: active
---

## Purpose

A consolidated punch list of everything that must be completed, every blocker,
and every doc inconsistency standing between the current repo and an **initial
shippable build**. "Initial build" here means the **first playable**, which the
docs define as P0 = [roadmap](roadmap.md) Phases 1–2 (core simulation + overpass
validation, then location selection + sub-areas).

State of play: the design is essentially complete. All 17 pre-implementation
questions in [p0-open-questions.md](p0-open-questions.md) (A1–A10, B1–B7) are
resolved with logged ADRs (0006–0015), and the simulation model is validated
against the Bow Valley fixture. The gap is **implementation** — `game/` is still
almost entirely `.gitkeep` placeholders; there is no Godot project to build yet.

---

## A. Blockers — nothing can be built until these exist

1. **No `project.godot`.** There is no Godot project at all, so nothing can open
   or export. Blocker zero.
2. **No engine/test toolchain.** [ADR 0012](adr/0012-godot-and-gut-version-pin.md)
   pins Godot 4.6 + GUT 9.6.0 vendored at `game/addons/gut/` — not yet installed.
3. **No CI.** `.github/workflows/` holds only `.gitkeep`; the roadmap and ADR 0012
   require a pinned `godot 4.6-stable` headless build + test job.
4. **Zero game code.** None of the 13 systems, nor `world_data` / `hex_grid` /
   `pathfinding`, nor any scene or test exists. The three constants files
   (`habitat_constants.gd`, `economy_constants.gd`, `simulation_constants.gd`)
   that every formula references are also unwritten.
5. **Most data files are missing.** Only `sub_areas.json` and `biome_groups.json`
   exist (both valid JSON). Still absent and required by schema/tests:
   `tiles.json`, `species_stats.json`, `entities.json`, `segments.json`,
   `infrastructure.json`, `milestones.json`. `data_validation_test.gd` cannot run
   without them.
6. **No real world map.** [ADR 0006](adr/0006-world-map-authoring.md) settled the
   authoring format (`data/world/<sub_area>.json`), but only the tiny
   `game/tests/fixtures/bow_valley_slice.json` test fixture exists. Phase 2 needs
   at least a full sub-area 7 (Bow Valley) map authored as data.
7. **No placeholder art/audio.** `game/assets/` is all `.gitkeep`. Phase 1's exit
   criteria require a visible + audible crossing cue; there is nothing to render
   or play.

---

## B. Tasks — the work to reach a shippable first playable

### B0. Scaffolding (the queued "next session")

- [ ] `project.godot` pinned to Godot 4.6, with the four autoloads (`GameState`,
      `EventBus`, `Debug`, `SpeciesRegistry`).
- [ ] Directory skeleton: `scenes/{ui,world}`, `scripts/{systems,ui}`.
- [ ] Vendor GUT 9.6.0 at `game/addons/gut/`.
- [ ] CI workflow on a pinned `godot 4.6-stable` headless binary (build + GUT run).
- [ ] Author the six remaining data files (`tiles.json`, `species_stats.json`,
      `entities.json`, `segments.json`, `infrastructure.json`, `milestones.json`).
- [ ] `data_validation_test.gd` covering schema §§3–14 (incl. world-map, biome
      groups, GameState).

### B1. Phase 1 — core simulation + overpass validation

- [ ] Systems: `world_data`, `hex_grid`, `pathfinding`, `connectivity_graph`,
      `habitat_manager`, `population_model`, `species_manager`,
      `infrastructure_manager`, the simulation tick loop.
- [ ] The three constants files (`habitat_constants.gd`, `economy_constants.gd`,
      `simulation_constants.gd`).
- [ ] Scenes: `scenes/world/WorldMap.tscn`; physics-free `Animal.tscn`
      (`Node2D → Sprite2D, [AnimationPlayer]`, per
      [ADR 0015](adr/0015-ecosystem-overpass-fallback-animal-scene.md)); crossing
      feedback cue (placeholder sprite + audio).
- [ ] Green tests: `pathfinding_test.gd`, `infrastructure_manager_test.gd`,
      `connectivity_graph_test.gd`, `habitat_manager_test.gd`,
      `population_model_test.gd`.

### B2. Phase 2 — location selection + sub-areas

- [ ] `world_select_controller`, `connectivity_overlay`, `confirm_panel`.
- [ ] `scenes/ui/WorldSelectMap.tscn` (the selection screen; not the simulated
      `WorldMap`, per [ADR 0013](adr/0013-scaffolding-conventions.md)).
- [ ] Author the real sub-area maps as `data/world/<sub_area>.json`.
- [ ] Green tests: `world_select_controller_test.gd`,
      `connectivity_overlay_test.gd`, `confirm_panel_test.gd`,
      `data_validation_test.gd`.

---

## C. Inconsistencies — doc contradictions to clean before coding

Low severity (the canonical source is unambiguous) and deliberately deferred in
the daily logs, but they point a builder at a retired file. **Resolved 2026-06-28**
in the same pass that produced this checklist:

- [x] `game/CLAUDE.md` data table listed `biome_definitions.json` — replaced with
      the full canonical file set + a retirement note pointing at
      [ADR 0007](adr/0007-patch-derivation-biome-compatibility.md).
- [x] `game-design-overview` and `fable-wildlife-crossing` PRDs said "one JSON
      file per species in `game/data/species/`" — corrected to the single
      `species_stats.json` array per
      [ADR 0013](adr/0013-scaffolding-conventions.md).
- [x] `docs/CLAUDE.md` `design-biome.md` command referenced
      `biome_definitions.json` — repointed to `biome_groups.json`.

---

## D. Gates that don't block the initial build but block content-complete v1

- **Liaison-NPC design question** ([liaison-npc-abstraction-memo](../obsidian-vault/design/liaison-npc-abstraction-memo.md))
  still awaits a product-owner decision. Phase 5 only — does not block Phases 1–2.
- **Mandatory cultural-advisor review** gates all First Nations narrative content
  ([cultural-narrative-design](../obsidian-vault/prd/cultural-narrative-design.md)).
  Phase 5 only — fine to defer, flagged so it is not a surprise.

---

## Scope note

If "initial build" means the full v1 (Phases 1–6) rather than first playable, the
task list above roughly quadruples — adding economy + information (Phase 3),
seasons (Phase 4), permissions + narrative (Phase 5, behind the cultural gate),
and milestones + polish (Phase 6).

## Cross-references

- [roadmap](roadmap.md) — phase definitions and per-phase exit criteria
- [p0-open-questions.md](p0-open-questions.md) — the 17 resolved blockers
- [architecture](architecture.md), [simulation-design](simulation-design.md),
  [data-schemas](data-schemas.md), [test-plan](test-plan.md)
