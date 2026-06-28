---
title: "P0 Open Questions — Pre-Implementation Review"
date: 2026-06-21
status: active
---

## Purpose

Before writing the first line of P0 ("through first playable" = roadmap Phases 1
and 2: core simulation + overpass validation, then location selection +
sub-areas), this document lists every question that must be answered to write
*correct* code, plus the cross-document inconsistencies that need resolving so
two systems don't get built against contradictory specs.

The design set is unusually complete — most PRD "open questions" are already
resolved with logged decisions. What remains falls into two buckets:

1. **Blockers** — things the code provably needs that no document specifies. You
   cannot finish Phase 1 without an answer.
2. **Inconsistencies** — two documents disagree; one must win before either
   dependent system is built.

Where I have a recommended default (acting as the senior builder per the root
`CLAUDE.md`), it's marked **Suggested:**. Each item notes the system(s) it blocks.

---

## A. Blockers

### A1. How is the world's terrain laid out? (the single biggest gap)

> **Resolved 2026-06-27 → [ADR 0006](adr/0006-world-map-authoring.md).** Maps are
> authored as data (`data/world/<sub_area>.json`: a per-coordinate tile-id grid in
> axial `[q, r]` + per-sub-area `origin`, schema in
> [`data-schemas` §12](data-schemas.md)); the `TileMapLayer` is generated from it
> at load and never read back (one-way `data/` → tilemap), so the `tiles.json`
> registry stays the single source of truth. The architecture §1/§3 static-vs-
> tilemap language was reconciled to this one pipeline. The Phase-1 test fixture
> (`game/tests/fixtures/bow_valley_slice.json`, also the **A9** answer) is a small
> Bow Valley slice with two 120-tile forest patches split by a road band — each
> below grizzly's 220-tile `min_viable_patch_size`, the connected network (240)
> above it, so a crossing demonstrably rescues a sub-viable patch (also satisfies
> the **A7** tutorial-map intent). Unblocks A2, A6, A7, A9, B4.

*Blocks: `world_data`, `hex_grid`, `pathfinding`, `connectivity_graph`,
`habitat_manager`, every Phase 1 test, every Phase 2 sub-area.*

`data-schemas` defines a tile **registry** (`tiles.json` — what a "forest" tile
*is*), plus species, sub-area metadata, and segments. But **nothing defines which
tile sits at each `[q, r]` coordinate.** `segments.json` lists only the dangerous
tiles; `sub_areas.json` carries only a `playable_tile_count`. There is no source
for the actual terrain map.

- How is a sub-area's hex map authored — a Godot `TileMapLayer` scene authored in
  the editor, or a data file (e.g. `data/world/sub_area_7.json`) holding the per-
  coordinate tile grid?
- If it's a `TileMapLayer`, how do painted cells resolve back to the data
  registries (terrain id, biome, danger flags) so the simulation can derive
  patches and run mortality? `architecture` §1 says "static world loaded from
  `data/`" *and* shows `TileMapLayer` nodes — these two need reconciling into one
  authoring pipeline with a defined tilemap↔data bridge.
- What world is Phase 1 validated against? The roadmap repeatedly says "on a test
  map" but no fixture is defined (see A9).

**Suggested:** author maps as data (`data/world/<sub_area>.json`: a tile-id grid
in axial coords + per-sub-area origin), and generate the `TileMapLayer` from that
data at load so the registry stays the single source of truth and tests can build
small worlds in code. Decide and document before A2–A7, which all depend on it.

### A2. What makes terrain "ecologically compatible" for patch derivation?

> **Resolved 2026-06-27 → [ADR 0007](adr/0007-patch-derivation-biome-compatibility.md).**
> Patch identity is **biome-based and species-agnostic** (one node per patch, so
> ADR 0004's cheap graph is unchanged): contiguous tiles join one patch iff their
> biomes share a **compatible-biome group**, authored as tight groups in
> `data/biome_groups.json` (schema [`data-schemas` §13](data-schemas.md)).
> Viability is **species-relative, over the network**: a species is viable when
> `min_viable_patch_size` is met by the connected network's tiles whose biome is
> in that species' habitat set — the sketch's `network.total_tile_count()` is
> fixed to `network.habitat_tile_count(species)`. Patches link by free contiguity
> (touching, no hazard) or by a completed crossing. Verified on the Bow Valley
> fixture: grizzly is sub-viable on each forest patch (128 / 120 tiles) and
> becomes viable (248) once a crossing joins them — the rescue loop. This also
> resolves **B4** (see below). Unblocks A6 and the Phase 1 simulation tests.

*Blocks: `connectivity_graph`, `habitat_manager`, `population_model`.*

Patches are "maximal contiguous zones of ecologically compatible terrain," but
"compatible" is never defined. Is a patch:

- **biome-based** (all contiguous forest tiles = one patch, species-agnostic), as
  `game-design-overview` implies; or
- **species-relative** (a patch is contiguous tiles within one species'
  `habitat_terrains`), as `population_model`'s `patch.resident_species()` /
  `species.min_viable_patch_size` usage implies?

And which biomes merge into one patch? Do `forest` + `forest_edge` join? `alpine`
+ `alpine_meadow`? `forest` + `alpine_meadow` (grizzly inhabits both)? A concrete
adjacency/compatibility table is needed to build the graph deterministically.

**Suggested:** biome-based patches with an explicit "compatible-biome groups"
table in data; species viability then reads the *network* size restricted to the
biomes in its `habitat_terrains`. Pick one model — the two read very differently
in code.

### A3. How do animals come into existence and persist?

> **Resolved 2026-06-27 → [ADR 0009](adr/0009-population-seeding-and-agent-rendering.md).**
> Authoritative `count` and rendered agents are **decoupled**. Initial population is
> **habitat-derived** — each resident species (patch biome ∈ its habitat set) is
> seeded at `max(SEED_FLOOR_IF_HABITABLE, round(INITIAL_SEED_FRACTION ×
> carrying_capacity))`, so `sub_areas.json` needs no count tables (magnitudes follow
> A5). **Cadence:** `count` changes only at the monthly step (decline/recovery) or
> on seasonal presence — no per-tick or free spawning; immigration after a crossing
> is recovery surfaced as a spawn. **Rendering:** `species_manager` shows a capped
> representative pool, `clamp(0, MAX_AGENTS_PER_VISIBLE_PATCH, ceil(count /
> AGENT_REPRESENTATION))` per species per visible patch, active sub-area only.
> **Watched deaths are observable, not demographic** — they feed feedback/economy/
> trust and dramatise decline but don't mutate `count`, preserving determinism.
> New constants in `simulation_constants.gd` ([`data-schemas` §10](data-schemas.md));
> verified on the Bow Valley fixture. Goal selection (how an agent picks a target /
> attempts a hazard) is **A4**. Unblocks `species_manager` and the Phase 1 loop.

*Blocks: `species_manager`, Phase 1 exit criteria (animals must route and die).*

`species_manager` "spawns" animals, but nothing specifies:

- Initial population: how many animals exist at game start, and where (seeded from
  per-patch `count`)?
- Spawn/respawn cadence: do new animals appear over time, on birth, on
  immigration across a crossing? Or is the rendered set fixed?
- Relationship between the abstract population `count` (per patch per species in
  `population_model`) and the **rendered `Animal` instances**: 1:1, or is `count`
  a statistical number with only a few representative agents drawn? This decision
  shapes the whole sim and the perf budget.

**Suggested:** decouple them — `population_model` owns the authoritative `count`;
`species_manager` renders a capped pool of representative agents (e.g. ≤ N per
visible patch) sampled from that count. Confirm before building either.

### A4. What is the animal goal-selection rule in Phases 1–2 (pre-seasons)?

> **Resolved 2026-06-27 → [ADR 0010](adr/0010-pre-season-goal-selection.md).**
> A season-independent forage/wander drive: an idle animal, with `WANDERLUST_PROB`,
> **travels** to another compatible patch within `range_tiles × MOTIVATION_DISTANCE_MULT`
> chosen by a quality/distance weighted random draw `w(P) = (quality(P) +
> GOAL_QUALITY_FLOOR) / (1 + dist(P))`; otherwise it **forages** within
> `FORAGE_RADIUS_TILES`. Re-paths on new goal, on `crossing_completed` /
> `season_changed`, and on a soft `REPATH_INTERVAL_TICKS` cadence; all draws use the
> shared seeded RNG. **Hazard attempts are emergent, not flagged** — A* risks an
> uncovered hazard only when the goal has no safe route (`HAZARD_AVOIDANCE_MULT`
> detours otherwise), so fragmentation is the sole cause of unassisted death.
> Phase 4 seasons scale `MOTIVATION_DISTANCE_MULT` only. New constants in
> `simulation_constants.gd` ([`data-schemas` §10](data-schemas.md)). Verified on the
> Bow Valley fixture: a west→east goal crosses 2 road tiles (~64% survival) before
> the overpass and routes through the zero-mortality chain at lower cost (24→17)
> after. Unblocks `species_manager`, `pathfinding`, and observability of the loop.

*Blocks: `species_manager`, `pathfinding`, observability of the core mechanic.*

`simulation-design` §2 says animals path toward "a habitat patch within range,
biased by seasonal motivation" — but seasons are Phase 4. In Phases 1–2 there is
no seasonal layer. Undefined:

- With no seasonal motivation, how does an animal pick a goal, and how often does
  it re-path / idle / wander?
- What makes an animal *attempt a hazardous crossing* rather than stay put? The
  whole "watch one die, then build a crossing, then watch one cross" loop (the
  Phase 1 success criterion) depends on this drive existing without seasons.

**Suggested:** a season-independent base wander/forage drive toward the
nearest in-range compatible patch, with `HAZARD_AVOIDANCE_MULT` (already defined)
making animals route around hazards unless the goal is only reachable through one.
Seasonal motivation in Phase 4 then scales an existing parameter rather than
introducing the behavior.

### A5. Carrying capacity, recovery rate, and decline step are undefined.

> **Resolved 2026-06-27 → [ADR 0011](adr/0011-carrying-capacity-recovery-decline.md).**
> One base capacity `round(CAPACITY_PER_HABITAT_TILE × patch_habitat_tiles × qnorm)`,
> used **ungated** for A3 seeding (`_potential_capacity`) and **viability-gated** for
> the monthly ceiling (`_carrying_capacity`, 0 when sub-viable) — capacity scales
> with habitat **size × quality**, so a crossing both reconnects and raises the cap.
> **Recovery** is proportional: `max(RECOVERY_MIN_STEP, round(RECOVERY_APPROACH_FRAC
> × (capacity − count)))` — fast then decelerating. **Decline** is fixed/gentle
> (`DECLINE_STEP = 2`/month). **Re-establishment:** a count-0 patch that becomes
> viable and connected to a source is seeded `RE_ESTABLISH_SEED` and fires
> `population_recovered` (`returned`); other thresholds are `doubled` and
> `saturated`. New constants in `simulation_constants.gd`
> ([`data-schemas` §10](data-schemas.md)); the §5 sketch and ADR 0009 seeding are
> updated to match. Verified on the Bow Valley fixture: grizzly seeded 18/side,
> declines 18→6 while fragmented, then recovers 6→…→31 toward capacity 32 after the
> crossing, with the east patch re-establishing 0→2. Unblocks `population_model` and
> `population_model_test`; the A1–A6 simulation chain is now fully specified.

*Blocks: `population_model`, `population_model_test`.*

The monthly-step sketch calls `_carrying_capacity(network, species)`,
`_recovery_rate(network, species)`, and `DECLINE_STEP`, but none has a formula or
value. `DECLINE_STEP` isn't in any constants table. Needed:

- Carrying-capacity formula (e.g. function of network tile count and
  `min_viable_patch_size`).
- Recovery rate per month and the gentle `DECLINE_STEP` value.
- The exact `population_recovered` thresholds beyond the example "count doubled"
  (e.g. species re-establishment from zero — what re-seeds a locally extinct
  species?).

### A6. The habitat-quality sub-formulae are unspecified (only caps exist).

> **Resolved 2026-06-27 → [ADR 0008](adr/0008-habitat-quality-subformulae.md).**
> Each term now has an exact expression: `terrain_base` = mean tile suitability for
> the patch biome; `size_factor` = log-scaled in the patch's own tile count between
> `SIZE_FACTOR_MIN_TILES`/`SIZE_FACTOR_FULL_TILES`; `connectivity_bonus` = per-safe-
> link base + quality scaled by the linked patch's size (count **and** quality);
> `edge_penalty` = `EDGE_PENALTY_MAX ×` (hostile perimeter edges / total perimeter
> edges). The four terms are orthogonal (`size_factor` is patch-only, so a crossing
> raises quality purely via `connectivity_bonus`). New constants added to
> `habitat_constants.gd` ([`data-schemas` §10](data-schemas.md)). Verified on the
> Bow Valley fixture: the west forest patch scores Fair (47.9) isolated and Good
> (53.4) once a crossing adds a safe link — clamp [0,100] and the four-band mapping
> both hold, covering `test_quality_formula_clamped_0_100`, `test_four_bands_mapping`,
> and `test_quality_recompute_on_crossing`.

*Blocks: `habitat_manager`, `test_quality_formula_clamped_0_100`,
`test_four_bands_mapping`.*

`habitat_constants.gd` gives the *caps* (`TERRAIN_BASE_MAX 40`, `SIZE_FACTOR_MAX
30`, `CONNECTIVITY_BONUS_MAX 20`, `EDGE_PENALTY_MAX 25`) but not how each term is
actually computed:

- `size_factor`: "log-scaled patch tile count vs. minimum viable size" — log
  base? clamp behavior below/above viable? exact expression?
- `connectivity_bonus`: derived from "count and quality of safe links" — count of
  edges? network size? quality-weighted how?
- `edge_penalty`: "fraction of perimeter edges adjacent to roads/urban/barriers"
  mapped to 0–25 — linear in the fraction?

The caps alone don't let the formula (or its test) be written.

### A7. `min_viable_patch_size` values vs. actual map scale.

> **Resolved 2026-06-28 → [ADR 0006](adr/0006-world-map-authoring.md) (fixture).**
> Intent confirmed: the starting Bow Valley (sub-area 7) map **must** contain at
> least one sub-viable patch a crossing can rescue, so the core loop is demonstrable
> on the tutorial map. The `bow_valley_slice.json` fixture realises exactly this —
> two 120-tile forest patches, each below grizzly's 220-tile threshold, with the
> connected network (240) above it. The 80–260 `min_viable_patch_size` values remain
> first-pass stubs; **validation against full ~4000-tile sub-areas is deferred** to
> when real maps are authored (Phase 2), tuned via constants, not code. The Phase-1
> loop is unblocked now.

*Blocks: tuning of `population_model`, `habitat_manager`; risk of an unwinnable or
trivial first playable.*

Values are 80–260 tiles against sub-areas of ~4000 tiles. Whether a *single
contiguous patch* in a real authored sub-area ever reaches 220 (grizzly) or 260
(caribou) tiles depends entirely on A1's map layout. These are flagged as
first-pass stubs, but they can't be validated until at least one real map exists.
Confirm the intent: should the starting Bow Valley (sub-area 7) map contain at
least one sub-viable patch that a crossing can rescue (so the core loop is
demonstrable on the tutorial map)?

### A8. Godot minor version and GUT version pin.

> **Resolved 2026-06-28 → [ADR 0012](adr/0012-godot-and-gut-version-pin.md).**
> Pinned **Godot 4.6 (stable) + GUT 9.6.0**. The binding constraint is GUT, not
> engine recency: 4.7 is the newest stable (2026-06-18) but no GUT release targets
> it yet, while **GUT 9.6.0 explicitly targets 4.6** — so the project-mandated test
> framework runs against the pinned engine on day one. 4.6 satisfies the
> `TileMapLayer` ≥ 4.3 requirement, so [ADR 0006](adr/0006-world-map-authoring.md)
> needs no rework. Both engine and GUT are pinned by exact tag (GUT vendored at
> `game/addons/gut/`); CI uses a pinned `godot 4.6-stable` headless binary via a
> single recorded version so editor and CI never drift. The 4.7 upgrade is deferred
> to a later superseding ADR once a GUT release targets 4.7+. Unblocks the B1/B2/B3
> scaffolding cluster.

*Blocks: `project.godot`, scene-tree node choices, CI.*

ADR 0001 says "Godot 4" but not the minor. `architecture` §3 uses
`TileMapLayer`, which only exists in **Godot 4.3+** (it replaced `TileMap`). Pin
the exact engine version (4.3 / 4.4 / latest stable) and the GUT version before
scaffolding, since node names, the project file, and the CI runner all depend on
it.

**Suggested:** latest stable Godot 4.x and the matching GUT release; record it in
ADR 0001 or a new ADR.

### A9. Test-fixture strategy for Phase 1.

> **Resolved 2026-06-28 → [ADR 0006](adr/0006-world-map-authoring.md).** Tests load
> **tiny JSON fixtures** in the same `data/world/<sub_area>.json` schema as real maps
> (§12), with small in-code helpers to instantiate systems directly (no scene
> tree/autoloads, per `game/CLAUDE.md`). The canonical Phase-1 fixture is
> `game/tests/fixtures/bow_valley_slice.json`; all nine Phase-1 test files build on
> it (or sibling fixtures). Fixtures-over-programmatic-worlds keeps tests reading the
> exact production loader path.

*Blocks: every Phase 1 test file.*

Tests "instantiate classes directly without scene-tree/autoload deps," so they
need small worlds built in code or loaded from tiny fixtures. Decide: do tests
construct mini hex worlds programmatically (helpers in `game/tests/`), or load
fixture data files? Depends on A1's authoring decision. Without this, none of the
nine Phase 1 test files can be written.

### A10. The `GameState` serialization shape is an acknowledged TODO.

> **Resolved 2026-06-28 → [ADR 0014](adr/0014-gamestate-serialization-shape.md).**
> The exact `GameState` JSON shape is now defined and added as
> [`data-schemas` §14](data-schemas.md): top-level `save_version` + `meta`, `clock`,
> `economy`, `patches`, `entities`, `information`, `crossings`, `milestones`. Stores
> only mutable runtime state, references static `data/` by stable `id`, and rebuilds
> derived state (connectivity graph, quality scores, agent pool) on `game_loaded`
> rather than storing it. Phase-1 systems serialize into the final shape from the
> start, so reaching the stable layout needs no migration. `save_version` starts at 1.

*Blocks: `save_manager` round-trip (touched from Phase 1 as state grows),
`save_manager_test`.*

ADR 0005 and `architecture` §7 list *what* is saved, but the **exact JSON shape**
is explicitly deferred ("define the exact `GameState` JSON shape alongside the
data schemas") and `data-schemas` doesn't contain it. Even if full save/load is
Phase 4, the round-trip contract should be fixed early so systems serialize into
a stable shape from the start.

---

## B. Cross-document inconsistencies to resolve

### B1. Scene and script directory paths disagree.

> **Resolved 2026-06-28 → [ADR 0013](adr/0013-scaffolding-conventions.md).**
> `game/CLAUDE.md`'s explicit layout is canonical (`game/scenes/{ui,world}/`,
> `game/scripts/{systems,ui}/`); `architecture` §1's paths are **shorthand relative
> to those roots**, and §1 now carries a note saying so. The `WorldMap` collision is
> resolved by keeping `scenes/world/WorldMap.tscn` for the simulated map and
> renaming the selection screen to **`scenes/ui/WorldSelectMap.tscn`** (controller
> `scripts/ui/world_select_controller.gd`). `architecture` §1 updated.

`game/CLAUDE.md` puts scenes in `game/scenes/{ui,world}/` and scripts in
`game/scripts/{systems,ui}/`. `architecture` §1 refers to scenes/scripts as
`world/WorldMap.tscn`, `ui/WorldMap.tscn`, `systems/world_data.gd`,
`ui/world_map_controller.gd` — i.e. without the `scenes/`/`scripts/` prefix.
Also note **two different `WorldMap.tscn`** are listed (one under `world/` = the
simulated tilemap, one under `ui/` = selection mode) — a name collision. Pick one
canonical path scheme and rename one of the two WorldMap scenes.

### B2. Species data: one file per species vs. a single file.

> **Resolved 2026-06-28 → [ADR 0013](adr/0013-scaffolding-conventions.md).**
> A **single `game/data/species_stats.json`** array wins — it matches `data-schemas`,
> `game/CLAUDE.md`, the `SpeciesRegistry` loader pattern, and `data_validation_test`
> (which targets the single file). No `game/data/species/` directory is created;
> the `game-design-overview` per-species-file line is retired and corrected when
> that PRD is next edited.

`game-design-overview` says "each species definition is a JSON file in
`game/data/species/`" (one file each). `data-schemas` and `game/CLAUDE.md`
specify a single `data/species_stats.json` array, and `data_validation_test`
targets the single file. Pick one. **Suggested:** single `species_stats.json`
(matches the test and the registry-loader pattern).

### B3. Tile size: 16×16 vs. 32×32.

> **Resolved 2026-06-28 → [ADR 0013](adr/0013-scaffolding-conventions.md).**
> **32×32 px** hex bounding box at 1× is canonical, per `art-direction` §3, so the
> `SEGMENT_ZOOM_ACTIVATE_PX`/`DEACTIVATE_PX` thresholds stay valid as authored
> (24×24 remains the documented fallback). `game/CLAUDE.md`'s "16×16 px"
> asset-pipeline line is corrected to 32×32 in the same change.

`game/CLAUDE.md` says tiles are 16×16 at 1×. `art-direction` §3 sets a **32×32**
hex bounding box and the `SEGMENT_ZOOM_ACTIVATE_PX = 16` constant is tuned
against 32×32 (with a logged 24×24 fallback). The zoom thresholds break if this
isn't settled. **Suggested:** adopt 32×32 as canonical and update
`game/CLAUDE.md` so the scoped doc stops contradicting the art direction.

### B4. `biome_definitions.json` is referenced but never schematized.

> **Resolved 2026-06-27 → [ADR 0007](adr/0007-patch-derivation-biome-compatibility.md).**
> The biome registry is now `data/biome_groups.json` ([`data-schemas` §13](data-schemas.md)):
> the eight canonical biomes, the compatible-biome groups (the group key is the
> patch biome that habitat `terrain_base` reads), and a terrain-alias map so
> species `habitat_terrains` resolve to canonical biomes. The orphaned
> `biome_definitions.json` reference in `game/CLAUDE.md` is retired (update that
> doc's data table when next touched).


`game/CLAUDE.md`'s data table lists `biome_definitions.json` (habitat types,
climate params, valid species), but `data-schemas` defines no such file — biome
is instead a string field on tiles with inline `terrain_suitability`. Meanwhile
habitat quality's `terrain_base` is "mean suitability for the **patch biome**,"
yet how a patch's biome is decided and where biome definitions live is unspecified
(ties to A2/A6). Decide: is there a biomes file, or is biome fully derived from
tiles? Either way, one document must be corrected.

### B5. `ecosystem_manager.gd` is orphaned.

> **Resolved 2026-06-28 → [ADR 0015](adr/0015-ecosystem-overpass-fallback-animal-scene.md).**
> **Deferred post-v1** (product-owner call), not cut: removed from the active
> `game/CLAUDE.md` systems table and recorded as a possible future food-web /
> biodiversity layer with a defined starting point. v1 viability is covered by
> `population_model` + `habitat_manager`; no code/tests/signals for it in v1.

`game/CLAUDE.md`'s systems table lists `ecosystem_manager.gd` (food web, resource
flows, biodiversity score). It appears nowhere in `architecture`'s system map,
signal catalogue, test plan, or any roadmap phase. Is it cut, deferred post-v1,
or an omission from the architecture? Remove it or place it.

### B6. Overpass biome variants don't cover all habitat biomes.

> **Resolved 2026-06-28 → [ADR 0015](adr/0015-ecosystem-overpass-fallback-animal-scene.md).**
> A total biome→variant fallback (default `overpass_forest`), recorded in
> [`data-schemas` §8](data-schemas.md): `forest`/`old_growth`/`boreal` →
> `overpass_forest`; `grassland`/`sagebrush`/`wetland` → `overpass_grassland`;
> `alpine`/`cliff` (and `subalpine`→`alpine`) → `overpass_alpine`. Placement applies
> §13 `terrain_aliases` then reads the table; dedicated `wetland`/`boreal` variants
> can be added later as new `biome_sprite_variants` keys without touching placement.

`infrastructure.json` and `art-direction` define exactly three overpass sprite
variants — `forest`, `grassland`, `alpine`. But species/terrain biomes also
include `boreal`, `sagebrush`, `old_growth`, `wetland`, `subalpine`, `cliff`.
Which variant key is used when a segment sits in, say, a boreal or wetland biome?
Define the biome→variant fallback mapping (placement reads it in Phase 2).

### B7. Animal scene structure: physics body or not?

> **Resolved 2026-06-28 → [ADR 0015](adr/0015-ecosystem-overpass-fallback-animal-scene.md).**
> Animals are **physics-free**: `Animal.tscn` is `Node2D → Sprite2D,
> [AnimationPlayer]` with **no `CollisionShape2D`/physics body** — movement is
> tick-based A* with render interpolation, not physics. `game/CLAUDE.md`'s generic
> entity convention is annotated so `CollisionShape2D` is reserved for entities that
> need pointer-picking/area hit-testing, not simulated animals.

`game/CLAUDE.md` says world entities use `EntityRoot → Sprite2D,
CollisionShape2D, [AnimationPlayer]`. But movement is tick-based A* on a hex grid
with render-interpolation — there's no physics. Confirm animals are plain
`Node2D` + `Sprite2D` (no `CollisionShape2D`/physics), or specify what collision
is for. Affects `Animal.tscn` and the interpolation approach.

---

## Recommended resolution order

1. **A1** (world authoring) first — A2, A6, A7, A9, and B4 all depend on it.
2. **A8/B1/B2/B3** next — cheap scaffolding decisions that unblock the project
   skeleton (`project.godot`, directory layout, data-file shapes).
3. **A2 → A3 → A4 → A5 → A6** — the simulation-model decisions, in dependency
   order, needed for the Phase 1 systems and their tests.
4. **A10, B5, B6, B7** — can be settled alongside the systems they touch.

Once A1–A6 and B1–B4 are answered, Phase 1 is fully specified and codeable.

## Related

- [`roadmap`](roadmap.md) — phase definitions (P0 = Phases 1–2 here)
- [`architecture`](architecture.md), [`simulation-design`](simulation-design.md),
  [`data-schemas`](data-schemas.md), [`test-plan`](test-plan.md)
- [[wildlife-overpass-crossing]], [[crossing-location-selection]], [[sub-areas]]
