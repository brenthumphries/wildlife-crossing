---
title: "0006 — World-Map Authoring and the Data↔Tilemap Bridge"
date: 2026-06-27
status: accepted
---

## Context

The data set ([`data-schemas`](../data-schemas.md)) defines a tile *registry*
(`tiles.json` — what a "forest" tile **is**), plus species, sub-area metadata,
and segments. But nothing defined **which tile sits at each `[q, r]`
coordinate.** `segments.json` lists only the dangerous tiles; `sub_areas.json`
carries only a `playable_tile_count`. There was no source for a sub-area's actual
terrain map, so the world could be data-validated but not rendered from data
alone — the blocker recorded as **A1** in
[`p0-open-questions`](../p0-open-questions.md), which blocks `world_data`,
`hex_grid`, `pathfinding`, `connectivity_graph`, `habitat_manager`, every Phase 1
test, and every Phase 2 sub-area.

There was also a latent contradiction between two parts of
[`architecture`](../architecture.md): §1 describes the world as "static, loaded
from `data/`", while §3 shows `WorldMap` as a `TileMapLayer` set
(`TerrainLayer` / `HazardLayer` / `CrossingLayer`). Read literally these are two
different authoring pipelines. They must reconcile into one pipeline with a
defined tilemap↔data bridge.

Two authoring models were considered:

1. **Data as the source of truth.** A per-sub-area data file holds the
   per-coordinate tile-id grid; the `TileMapLayer` is generated from it at load.
2. **`TileMapLayer` as the source of truth.** Maps are painted in the Godot
   editor; a reverse lookup resolves painted atlas cells back to registry tile
   ids (terrain id, biome, danger flags) so the simulation can derive patches and
   run mortality.

Model 2 requires maintaining an atlas-coordinate → registry-id mapping by hand,
keeps a second source of truth that can drift from `tiles.json`, and prevents
tests from constructing worlds without loading a scene (tests must "instantiate
classes directly without scene-tree/autoload deps", per `game/CLAUDE.md`).

## Decision

**Author sub-area maps as data, and generate the `TileMapLayer` from that data at
load. The bridge is one-way: `data/` → tilemap.**

- Each sub-area's terrain is authored as
  `game/data/world/<sub_area>.json` (e.g. `sub_area_7.json`), `data_version: 1`,
  holding the per-coordinate tile-id grid in axial `[q, r]` coordinates plus a
  per-sub-area `origin`. Each cell references a `tiles.json` `id`, so the tile
  **registry remains the single source of truth** for what each cell *is*
  (terrain id, biome, suitability, danger flags). The full schema is specified in
  [`data-schemas` §12](../data-schemas.md).
- At load, `world_data.gd` reads the grid and **populates** `WorldMap.tscn`'s
  `TileMapLayer`s programmatically, routing each cell to `TerrainLayer`,
  `HazardLayer`, or `CrossingLayer` by the referenced tile's `category`. Layer
  assignment is connections-in-code, consistent with the architecture's
  no-editor-wiring convention.
- **Nothing reads terrain back out of the painted tilemap.** The `TileMapLayer`
  is pure render output; all simulation logic (patch derivation, mortality,
  pathfinding) reads the data grid and the registry, never the atlas. This makes
  architecture §1's "static world loaded from `data/`" literally true and the
  `TileMapLayer` merely how that data is drawn.
- Tests build small worlds in code or load tiny fixture files of the same schema,
  with no scene-tree dependency — this is the chosen answer to **A9**
  (Phase-1 test-fixture strategy). The first such fixture is a small Bow Valley
  slice (`game/data/world/sub_area_7.json`) carrying at least one sub-viable
  patch that a crossing can rescue, so the core loop is demonstrable on the
  tutorial map.

## Consequences

### Positive

- One source of truth. The `tiles.json` registry defines every cell's
  properties; the world file only references ids. No atlas↔id table to keep in
  sync, no drift.
- Resolves the architecture §1/§3 contradiction: a single load-time pipeline
  (`data/` → `TileMapLayer`), not two competing authoring surfaces.
- Unblocks A2, A6, A7, A9, and B4, which all depend on a concrete map existing
  (the resolution order in `p0-open-questions`).
- Tests are scene-free: worlds are built from code or fixture data, satisfying
  the unit-test isolation rule and giving deterministic patches for graph tests.
- Coordinates already standardised as axial `[q, r]` ([ADR 0002](0002-hex-grid-topology.md))
  carry straight into the world file with no new convention.

### Negative / Trade-offs

- No visual in-editor painting initially; maps are authored as data, which is
  less ergonomic for large hand-built terrain. Mitigated by keeping Phase 1
  fixtures small and revisiting an editor-paint-then-bake tool (a future ADR) if
  authoring volume justifies it — the bake target would be this same schema, so
  the decision is forward-compatible.
- A grid stored as explicit per-cell entries is verbose for a ~4000-tile
  sub-area; the schema therefore supports a compact run/region form alongside
  explicit cells (see §12) so large maps stay authorable and diff-friendly.

### Neutral / Follow-on work

- `data/world/` is a new directory under `game/data/`; the `WorldDataRegistry`
  loader pattern ([architecture §2](../architecture.md)) gains a world-map
  loader.
- A `data_validation_test.gd` case is added to validate world files against §12
  (every cell id resolves to `tiles.json`; coordinates unique; counts within the
  sub-area's `playable_tile_count` tolerance).
- A2 (patch compatibility) and A6 (habitat-quality sub-formulae) can now be
  decided against a real authored map.
