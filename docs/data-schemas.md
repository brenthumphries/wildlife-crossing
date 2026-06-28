---
title: "Data Schema Specification"
date: 2026-06-17
status: active
---

## Purpose

This document specifies the machine-readable data formats Wildlife Crossing
loads at runtime: JSON schemas for species, sub-areas, segments, tiles,
governmental entities, and milestones; the environment-variable registry; and
the GDScript constants files. It gives a validating sample entry for each schema
and stub entries for all eight launch species and all twelve sub-areas, so the
`data/` files can be authored directly against this spec.

Static data lives in `game/data/` and is served by read-only registries at
startup; mutable runtime state is saved separately
([architecture §2](architecture.md), [ADR 0005](adr/0005-save-file-format.md)).
Every data file carries a `data_version` integer; bumping it is required when a
schema changes, and the relevant loader is updated in the same change
(per `game/CLAUDE.md`).

> Decision logged: schemas are expressed below as field tables plus a JSON
> sample rather than as formal JSON Schema files, to stay human-editable in the
> vault. A formal `*.schema.json` per type can be generated from these tables
> when validation tooling is added; field names, types, and required/optional
> status are normative as written here.

---

## 1. Conventions

- All ids are stable `snake_case` strings, unique within their type, and are the
  reference keys used by saves and cross-references.
- Coordinates use **axial hex coordinates** `[q, r]` ([ADR 0002](adr/0002-hex-grid-topology.md)).
- Enumerated fields list their full legal value set in the field table.
- Files are arrays of objects under a top-level `{ "data_version": N, "<plural>": [...] }`
  wrapper, except single-object config files.

---

## 2. Tile schema (`data/tiles.json`)

Defines the terrain/tile registry, including the two mutually exclusive danger
flags from [`wildlife-overpass-crossing`](../obsidian-vault/prd/wildlife-overpass-crossing.md).

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | e.g. `forest`, `road`, `river`, `fence`, `urban` |
| `display_name` | string | yes | |
| `category` | enum | yes | `terrain` \| `hazard` \| `barrier` \| `crossing` |
| `is_impassable` | bool | yes | hard barriers (fences, walls, buildings, urban). Mutually exclusive with `is_hazardous` |
| `is_hazardous` | bool | yes | roads, rivers — passable but trigger a mortality check |
| `hazard_mortality_env` | string\|null | no | name of the env var supplying per-step mortality (e.g. `ROAD_HAZARD_MORTALITY`); null for non-hazards |
| `biome` | string\|null | no | for terrain tiles, the biome this terrain belongs to (forest, grassland, alpine, wetland, sagebrush, boreal, old_growth, cliff) |
| `terrain_suitability` | object\|null | no | map of `biome → 0–40 base suitability` feeding habitat `terrain_base` |
| `sprite_set` | string | yes | art key; seasonal variants resolved by the art layer |

**Invariant:** `is_impassable` and `is_hazardous` are never both true.

```json
{
  "data_version": 1,
  "tiles": [
    { "id": "forest", "display_name": "Forest", "category": "terrain",
      "is_impassable": false, "is_hazardous": false, "hazard_mortality_env": null,
      "biome": "forest", "terrain_suitability": { "forest": 38, "grassland": 12 },
      "sprite_set": "terrain_forest" },
    { "id": "road", "display_name": "Highway", "category": "hazard",
      "is_impassable": false, "is_hazardous": true,
      "hazard_mortality_env": "ROAD_HAZARD_MORTALITY",
      "biome": null, "terrain_suitability": null, "sprite_set": "hazard_road" },
    { "id": "river", "display_name": "River", "category": "hazard",
      "is_impassable": false, "is_hazardous": true,
      "hazard_mortality_env": "RIVER_HAZARD_MORTALITY",
      "biome": null, "terrain_suitability": null, "sprite_set": "hazard_river" },
    { "id": "fence", "display_name": "Fence line", "category": "barrier",
      "is_impassable": true, "is_hazardous": false, "hazard_mortality_env": null,
      "biome": null, "terrain_suitability": null, "sprite_set": "barrier_fence" }
  ]
}
```

---

## 3. Species schema (`data/species_stats.json`)

Fields are exactly those named in
[`game-design-overview`](../obsidian-vault/prd/game-design-overview.md) §Species.

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | stable key (e.g. `grizzly_bear`) |
| `display_name` | string | yes | |
| `habitat_terrains` | string[] | yes | biome/terrain ids the species inhabits |
| `min_viable_patch_size` | int | yes | tiles; below this a patch cannot sustain a population |
| `range_tiles` | int | yes | how far an individual ranges |
| `preferred_crossing_type` | enum | yes | `overpass` \| `underpass` \| `corridor` |
| `seasonal_pattern` | enum | yes | `resident` \| `seasonal_migration` \| `elevational_migration` \| `hibernates` |
| `status_weight` | int | yes | donation weight: `1` common, `2` vulnerable, `3` endangered |
| `sprite_set` | string | yes | art key |

```json
{
  "data_version": 1,
  "species": [
    { "id": "grizzly_bear", "display_name": "Grizzly bear",
      "habitat_terrains": ["forest", "alpine_meadow"], "min_viable_patch_size": 220,
      "range_tiles": 60, "preferred_crossing_type": "overpass",
      "seasonal_pattern": "hibernates", "status_weight": 2, "sprite_set": "grizzly_bear" }
  ]
}
```

### All eight launch species (stub entries)

| id | habitat_terrains | min_viable_patch_size | range_tiles | preferred_crossing_type | seasonal_pattern | status_weight |
|---|---|---|---|---|---|---|
| `grizzly_bear` | forest, alpine_meadow | 220 | 60 | overpass | hibernates | 2 |
| `elk` | grassland, forest_edge | 120 | 45 | overpass | seasonal_migration | 1 |
| `pronghorn` | grassland, sagebrush | 140 | 50 | overpass | seasonal_migration | 1 |
| `mountain_caribou` | old_growth, alpine | 260 | 65 | corridor | elevational_migration | 3 |
| `wolverine` | alpine, subalpine | 240 | 70 | corridor | resident | 2 |
| `gray_wolf` | forest, grassland | 200 | 70 | underpass | resident | 1 |
| `canada_lynx` | boreal | 90 | 30 | underpass | resident | 2 |
| `bighorn_sheep` | cliff, alpine_grassland | 80 | 25 | overpass | elevational_migration | 2 |

> Decision logged: numeric `min_viable_patch_size` and `range_tiles` values are
> first-pass tuning stubs translating the PRD's qualitative range labels
> (Medium / Large / Very large) into tile counts; final values are balanced in
> Phase 1 against the habitat-quality and population models. Pronghorn's "will
> not use underpasses" note is encoded later as a per-type eligibility override
> when underpasses ship; in v1 (overpass only) it has no effect.

---

## 4. Sub-area schema (`data/sub_areas.json`)

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | int | yes | 1–12, south-to-north |
| `name` | string | yes | established geographic name |
| `anchor_geography` | string | yes | real landmarks the region is built around |
| `jurisdiction_real` | string | yes | real states/provinces/territories (informational) |
| `controlling_entity_id` | string | yes | references an entity in `entities.json` |
| `boundary_basis` | string | yes | the natural feature(s) the boundary follows |
| `playable_tile_count` | int | yes | target equal within ±15% across sub-areas |
| `size_deviation_note` | string\|null | no | justification where size deviates (e.g. narrow geography) |
| `trust_threshold` | int | yes | trust needed to unlock (default 100; lower for early unlocks) |
| `starts_unlocked` | bool | yes | true only for sub-area 7 |
| `indigenous_name_note` | string\|null | no | acknowledgment text when the name is of Indigenous origin |

```json
{
  "data_version": 1,
  "sub_areas": [
    { "id": 7, "name": "Central Canadian Rockies",
      "anchor_geography": "Banff, Jasper, Yoho, Kootenay NPs; Bow Valley",
      "jurisdiction_real": "AB/BC", "controlling_entity_id": "ca_federal_parks",
      "boundary_basis": "Continental Divide and Bow/Athabasca watersheds",
      "playable_tile_count": 4000, "size_deviation_note": null,
      "trust_threshold": 0, "starts_unlocked": true, "indigenous_name_note": null }
  ]
}
```

### All twelve sub-areas (stub entries)

| id | name | controlling_entity_id | trust_threshold | starts_unlocked | boundary_basis |
|---|---|---|---|---|---|
| 1 | Greater Yellowstone | `us_federal_lands` | 60 | false | Yellowstone Plateau, Wind River Range watersheds |
| 2 | High Divide | `ranching_coalition` | 45 | false | Centennial Mtns / Big Hole Valley divide |
| 3 | Salmon–Selway–Bitterroot | `us_federal_lands` | 55 | false | Bitterroot Range / Frank Church wilderness |
| 4 | Cabinet–Purcell | `transport_authorities` | 50 | false | Cabinet Mtns / Purcell Trench (Hwy 95) |
| 5 | Inland Temperate Rainforest | `bc_provincial` | 65 | false | Columbia Mtns / Selkirks / Kootenay Lake |
| 6 | Crown of the Continent | `ksanka_confederacy` | 25 | false | Glacier–Waterton / Flathead watershed |
| 7 | Central Canadian Rockies | `ca_federal_parks` | 0 | true | Continental Divide / Bow watershed |
| 8 | Peace River Break | `bc_provincial` | 70 | false | Hart Ranges / Peace River canyon (Hwy 97) |
| 9 | Muskwa–Kechika | `taltse_dena_council` | 75 | false | Muskwa Ranges / Kechika Basin |
| 10 | Upper Liard Basin | `territorial_gov` | 80 | false | Liard Plateau / Cassiar Mountains |
| 11 | Stikine–Nass–Skeena Headwaters | `three_rivers_nations` | 85 | false | Sacred Headwaters / Spatsizi Plateau |
| 12 | Greater Mackenzie Mountains | `territorial_gov` | 90 | false | Mackenzie & Selwyn Mountains |

`indigenous_name_note` is populated for names of Indigenous origin (e.g.
Muskwa–Kechika, Stikine, Nass, Skeena) and the final pass goes through
cultural-advisor review per [`sub-areas`](../obsidian-vault/prd/sub-areas.md).

> Decision logged: `trust_threshold` values implement the PRD's "scale
> northward/southward from the start" pacing — Crown of the Continent (6) is the
> deliberately low first unlock (25); thresholds rise with distance from the Bow
> Valley start. `playable_tile_count` targets ~4000 tiles/sub-area (±15%);
> Peace River Break carries a `size_deviation_note` for its denser, narrower map.
> Two territorial sub-areas (10, 12) share the `territorial_gov` entity, and two
> BC sub-areas (5, 8) share `bc_provincial`, yielding nine distinct entities
> across twelve sub-areas.

---

## 5. Segment schema (`data/segments.json`)

A segment is the smallest selectable unit of road/barrier
([`crossing-location-selection`](../obsidian-vault/prd/crossing-location-selection.md) mechanic 6).
Boundaries are fixed in world data; the player never edits them.

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | e.g. `s4_hwy95_sector3` |
| `sub_area_id` | int | yes | owning sub-area |
| `label` | string | yes | human-readable (e.g. "Highway 95, sector 3") |
| `tiles` | array<[q,r]> | yes | the dangerous tiles in the segment (all `is_hazardous`/`is_impassable`) |
| `surround_tiles` | array<[q,r]> | no | buffer tiles for fencing/guidance constructs |
| `hazard_type` | enum | yes | dominant hazard: `road` \| `river` \| `barrier` |
| `connectivity_note` | string | no | one-line note shown in the confirm panel |

```json
{
  "data_version": 1,
  "segments": [
    { "id": "s7_trans_canada_bow_a", "sub_area_id": 7,
      "label": "Trans-Canada Hwy, Bow Valley sector A",
      "tiles": [[12,4],[13,4],[14,4]], "surround_tiles": [[12,3],[14,5]],
      "hazard_type": "road",
      "connectivity_note": "Connects two fragmented forest patches" }
  ]
}
```

---

## 6. Governmental entity schema (`data/entities.json`)

Nine entities; metric weights differ by type
([`governmental-permissions`](../obsidian-vault/prd/governmental-permissions.md)).
Exact weights are hidden until the player buys a community liaison briefing, but
they live in data and are read by `permissions_manager`.

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | stable key |
| `display_name` | string | yes | |
| `type` | enum | yes | `federal` \| `provincial_state` \| `territorial` \| `ranching_coalition` \| `first_nations` |
| `governs_sub_areas` | int[] | yes | sub-area ids this entity controls |
| `trust_threshold` | int | yes | default 100 (overridden per sub-area unlock where lower) |
| `metric_weights` | object | yes | metric id → weight; weights sum to 1.0 |
| `top_conditions` | string[3] | yes | the three conditions shown in the entity checklist |
| `is_first_nations` | bool | yes | gates partnership benefits and cultural-review content |

Metric ids (the measurable inputs to trust): `crossing_usage`,
`road_mortality_reduction`, `crossings_completed`, `active_crossings`,
`population_stability`, `population_recovery`, `species_diversity`,
`adjacent_stewardship`, `joint_stewardship_accept`.

```json
{
  "data_version": 1,
  "entities": [
    { "id": "us_federal_lands", "display_name": "U.S. Federal Lands Agency (parks & forests)",
      "type": "federal", "governs_sub_areas": [1, 3], "trust_threshold": 60,
      "metric_weights": { "crossing_usage": 0.5, "road_mortality_reduction": 0.5 },
      "top_conditions": ["Crossing usage counts", "Reduced road mortality",
                         "Visitor-safe outcomes"], "is_first_nations": false },
    { "id": "ksanka_confederacy", "display_name": "Ksanka Confederacy (fictional)",
      "type": "first_nations", "governs_sub_areas": [6], "trust_threshold": 25,
      "metric_weights": { "population_recovery": 0.35, "species_diversity": 0.25,
                          "adjacent_stewardship": 0.25, "joint_stewardship_accept": 0.15 },
      "top_conditions": ["Population recovery events", "Species diversity",
                         "Stewardship in adjacent lands"], "is_first_nations": true }
  ]
}
```

### Entity roster (nine)

| id | type | governs | is_first_nations |
|---|---|---|---|
| `us_federal_lands` | federal | 1, 3 | false |
| `ca_federal_parks` | federal | 7 | false |
| `transport_authorities` | provincial_state | 4 | false |
| `bc_provincial` | provincial_state | 5, 8 | false |
| `ranching_coalition` | ranching_coalition | 2 | false |
| `territorial_gov` | territorial | 10, 12 | false |
| `ksanka_confederacy` | first_nations | 6 | true |
| `taltse_dena_council` | first_nations | 9 | true |
| `three_rivers_nations` | first_nations | 11 | true |

Count: nine entities (2 federal, 2 provincial/state, 1 ranching coalition,
1 territorial, 3 First Nations) governing all twelve sub-areas.

> Decision logged: the source PRDs carry a latent inconsistency — the
> `governmental-permissions` roster states "nine entities" (2 federal, 2
> provincial/state, 2 territorial, 3 First Nations), but the `sub-areas` table
> implies more distinct controlling bodies (US parks for area 1, US forests for
> area 3, a Canadian parks agency for area 7, a ranching coalition for area 2,
> two territorial governments, etc.), which would total more than nine. To land
> on exactly nine while covering all twelve sub-areas, two consolidations are
> made: (a) the U.S. parks agency (area 1) and U.S. forests agency (area 3) are
> unified into one `us_federal_lands` body — matching the roster's "2 federal
> (US, Canada)" framing; and (b) the Yukon and NWT territorial governments are
> unified into one `territorial_gov` (areas 10, 12). The High Divide
> `ranching_coalition` is retained as its own entity because the sub-area table
> names it explicitly and it has distinct values. Net: 2 federal, 2
> provincial/state, 1 ranching coalition, 1 territorial, 3 First Nations = nine.
> If the design later wants distinct Yukon vs. NWT bodies or separate US
> parks/forests agencies, split the consolidated entity and bump the count; the
> schema and saves reference entities by `id`, so the change is localised.

---

## 7. Milestone schema (`data/milestones.json`)

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | stable key |
| `display_name` | string | yes | |
| `scope` | enum | yes | `sub_area` \| `capstone` |
| `sub_area_id` | int\|null | no | required when scope = `sub_area` |
| `condition` | object | yes | `{ metric, comparator, value }` or a composite `all_of[]` |
| `reward_bonus` | int | yes | one-time donation bonus on completion |
| `is_capstone` | bool | yes | true only for Continental Connection |

```json
{
  "data_version": 1,
  "milestones": [
    { "id": "first_crossing_sub7", "display_name": "First crossing — Bow Valley",
      "scope": "sub_area", "sub_area_id": 7,
      "condition": { "metric": "crossings_completed_in_sub_area", "comparator": ">=", "value": 1 },
      "reward_bonus": 2000, "is_capstone": false },
    { "id": "continental_connection", "display_name": "Continental Connection",
      "scope": "capstone", "sub_area_id": null,
      "condition": { "metric": "connected_chain_yellowstone_to_mackenzie", "comparator": "==", "value": true },
      "reward_bonus": 0, "is_capstone": true }
  ]
}
```

---

## 8. Infrastructure / crossing-type schema (`data/infrastructure.json`)

Data-driven crossing types ([ADR 0003](adr/0003-crossing-tile-architecture.md)).

| Field | Type | Required | Notes |
|---|---|---|---|
| `crossing_type` | enum | yes | `overpass` \| `underpass` \| `corridor` |
| `display_name` | string | yes | |
| `cost_per_tile` | int | yes | overpass = 5000 |
| `coverable_flags` | string[] | yes | which tile danger flags this type may span (`is_hazardous`, `is_impassable`) |
| `preference_cost_modifier` | float | yes | multiplier (<1.0) applied to pathfinding cost for species that prefer this type |
| `biome_sprite_variants` | object | yes | biome → sprite key (forest, grassland, alpine) |
| `available_in_v1` | bool | yes | only overpass is true at launch |

```json
{
  "data_version": 1,
  "infrastructure": [
    { "crossing_type": "overpass", "display_name": "Wildlife overpass",
      "cost_per_tile": 5000, "coverable_flags": ["is_hazardous", "is_impassable"],
      "preference_cost_modifier": 0.6,
      "biome_sprite_variants": { "forest": "overpass_forest",
        "grassland": "overpass_grassland", "alpine": "overpass_alpine" },
      "available_in_v1": true }
  ]
}
```

### Biome → variant fallback (B6, [ADR 0015](adr/0015-ecosystem-overpass-fallback-animal-scene.md))

`biome_sprite_variants` ships three keys (`forest`, `grassland`, `alpine`), but
all eight canonical biomes (§13) must resolve to one. Placement applies any §13
`terrain_aliases`, then this total fallback (default `overpass_forest`):

| Biome | Variant |
|---|---|
| `forest`, `old_growth`, `boreal` | `overpass_forest` |
| `grassland`, `sagebrush`, `wetland` | `overpass_grassland` |
| `alpine`, `cliff` (`subalpine`→`alpine`) | `overpass_alpine` |

Adding a dedicated `wetland`/`boreal` variant later is just a new
`biome_sprite_variants` key; placement logic is unchanged.

---

## 9. Environment-variable registry

Read once at simulation start; each falls back to its default if absent; each is
settable independently ([`wildlife-overpass-crossing`](../obsidian-vault/prd/wildlife-overpass-crossing.md) P0).

| Variable | Default | Effect |
|---|---|---|
| `ROAD_HAZARD_MORTALITY` | `0.20` | per-step death probability on an uncovered road tile |
| `RIVER_HAZARD_MORTALITY` | `0.20` | per-step death probability on an uncovered river tile |

Adding a new hazardous terrain type adds a row here and a `hazard_mortality_env`
reference on the tile (§2). The simulation reads these via an `env_config.gd`
loader and exposes them as read-only values; tests set them per-case (see
[`test-plan`](test-plan.md)).

---

## 10. Constants files (GDScript)

Designer-tunable constants are named constants in dedicated files — no magic
numbers inline (root convention). Values shown are first-pass defaults.

### `game/scripts/systems/habitat_constants.gd`

| Constant | Value | Meaning |
|---|---|---|
| `TERRAIN_BASE_MAX` | 40 | cap on terrain-suitability term |
| `SIZE_FACTOR_MAX` | 30 | cap on log-scaled size term |
| `CONNECTIVITY_BONUS_MAX` | 20 | cap on connectivity term |
| `EDGE_PENALTY_MAX` | 25 | cap on edge-adjacency penalty |
| `SIZE_FACTOR_MIN_TILES` | 50 | patch tile count at/below which `size_factor` is 0 ([ADR 0008](adr/0008-habitat-quality-subformulae.md)) |
| `SIZE_FACTOR_FULL_TILES` | 500 | patch tile count at/above which `size_factor` saturates to `SIZE_FACTOR_MAX` |
| `CONNECTIVITY_LINK_BASE` | 4 | base quality per safe link |
| `CONNECTIVITY_LINK_QUALITY` | 4 | additional per-link quality scaled by the linked patch's `size_factor` |
| `HEX_EDGES_PER_TILE` | 6 | edges per hex tile (perimeter math) |
| `BAND_POOR_MAX` | 25 | upper bound of Poor band |
| `BAND_FAIR_MAX` | 50 | upper bound of Fair band |
| `BAND_GOOD_MAX` | 75 | upper bound of Good band (above = Excellent) |
| `PARTNERSHIP_QUALITY_BONUS` | 8 | flat quality bonus on co-stewarded patches |

The exact expression for each quality term (`terrain_base`, `size_factor`,
`connectivity_bonus`, `edge_penalty`) is specified in
[ADR 0008](adr/0008-habitat-quality-subformulae.md).

### `game/scripts/systems/economy_constants.gd`

| Constant | Value | Meaning |
|---|---|---|
| `STARTING_BUDGET` | 50000 | initial funds |
| `OVERPASS_COST_PER_TILE` | 5000 | crossing cost per tile |
| `BASE_GRANT` | 1000 | unconditional monthly income |
| `FUNDRAISING_TRICKLE` | 500 | monthly anti-deadlock income when below cheapest action |
| `FRAGMENTATION_MULT_MIN` | 1.0 | low end of fragmentation multiplier |
| `FRAGMENTATION_MULT_MAX` | 2.0 | high end of fragmentation multiplier |
| `INFO_HABITAT_ASSESSMENT` | 1000 | habitat assessment cost / area |
| `INFO_POPULATION_SURVEY` | 2000 | population survey cost / area |
| `INFO_CORRIDOR_STUDY` | 3000 | movement corridor study cost / area |
| `INFO_LIAISON_BRIEFING` | 1500 | community liaison briefing cost / entity |
| `STATUS_WEIGHT_COMMON` | 1 | donation status weight |
| `STATUS_WEIGHT_VULNERABLE` | 2 | donation status weight |
| `STATUS_WEIGHT_ENDANGERED` | 3 | donation status weight |

### `game/scripts/systems/simulation_constants.gd`

| Constant | Value | Meaning |
|---|---|---|
| `SIM_TICK_SECONDS` | 0.1 | real seconds per sim tick at 1× |
| `SEASON_REAL_MINUTES` | 15 | real minutes per season at 1× |
| `DAYS_PER_SEASON` | 90 | in-game days per season |
| `SEGMENT_ZOOM_ACTIVATE_PX` | 16 | tile flat-to-flat px to enter segment mode |
| `SEGMENT_ZOOM_DEACTIVATE_PX` | 12 | hysteresis: tile px to leave segment mode |
| `CROSSING_FEEDBACK_COALESCE_SECONDS` | 2.0 | window for "+N" coalescing of `animal_crossed` |
| `TRUST_THRESHOLD_DEFAULT` | 100 | default unlock threshold |
| `MAX_AGENTS_PER_VISIBLE_PATCH` | 8 | hard cap on rendered agents per species per visible patch ([ADR 0009](adr/0009-population-seeding-and-agent-rendering.md)) |
| `AGENT_REPRESENTATION` | 25 | `count` units represented by each rendered agent |
| `INITIAL_SEED_FRACTION` | 0.6 | fraction of carrying capacity used to seed starting `count` |
| `SEED_FLOOR_IF_HABITABLE` | 1 | minimum starting `count` for a resident species in a habitable patch |
| `WANDERLUST_PROB` | 0.5 | chance an idle animal targets another patch vs foraging locally ([ADR 0010](adr/0010-pre-season-goal-selection.md)) |
| `GOAL_QUALITY_FLOOR` | 10 | floor added to patch quality in goal weighting so poor patches stay reachable |
| `REPATH_INTERVAL_TICKS` | 200 | soft re-path cadence so animals react to new crossings |
| `IDLE_DWELL_TICKS` | 50 | forage dwell at a reached goal before selecting again |
| `FORAGE_RADIUS_TILES` | 3 | local-forage wander radius when no other patch is in range |
| `MOTIVATION_DISTANCE_MULT` | 1.0 | goal-distance willingness; Phase 4 seasons scale this |
| `CAPACITY_PER_HABITAT_TILE` | 0.5 | animals per habitat tile, the base carrying-capacity density ([ADR 0011](adr/0011-carrying-capacity-recovery-decline.md)) |
| `QUALITY_CAPACITY_FLOOR_FRAC` | 0.5 | floor on the habitat-quality factor scaling capacity |
| `RECOVERY_APPROACH_FRAC` | 0.2 | fraction of the gap to capacity closed per month |
| `RECOVERY_MIN_STEP` | 1 | minimum monthly recovery so re-establishment isn't glacial |
| `DECLINE_STEP` | 2 | gentle monthly count loss in a sub-viable patch |
| `RE_ESTABLISH_SEED` | 2 | immigration seed when a locally-extinct species returns to a viable, connected patch |

---

## 11. Validation checklist (schema acceptance)

- A sample object for every schema above parses as valid JSON and satisfies its
  field table — verified in [`test-plan`](test-plan.md) (`data_validation_test.gd`).
- All eight launch species have stub entries (§3).
- All twelve sub-areas have stub entries (§4).
- All nine entities are enumerated (§6) and every sub-area's
  `controlling_entity_id` resolves to one of them.
- The two mortality env vars are registered with defaults (§9).
- Both constants files named in the PRD (`habitat_constants.gd`,
  `economy_constants.gd`) are specified (§10), plus `simulation_constants.gd`.
- Every world-map file (§12) parses, every cell `tile` resolves to a `tiles.json`
  `id`, no `[q, r]` is occupied twice, and the resolved playable-tile count is
  within ±15% of the matching sub-area's `playable_tile_count` (§4).
- `biome_groups.json` (§13) parses; every biome in a group and every alias target
  is one of the eight canonical `biomes`; every biome appears in exactly one
  group; and every distinct biome referenced by a tile (§2) or resolvable from a
  species `habitat_terrains` (§3, via alias) is covered.

## 12. World-map schema (`data/world/<sub_area>.json`)

The per-coordinate terrain map for one sub-area: which tile sits at each
`[q, r]`. This is the source of truth for terrain; the `TileMapLayer` is
generated from it at load and never read back ([ADR 0006](adr/0006-world-map-authoring.md)).
Each cell references a `tiles.json` `id` (§2), so this file carries placement
only — never tile properties. One file per sub-area, named `sub_area_<n>.json`.

| Field | Type | Required | Notes |
|---|---|---|---|
| `data_version` | int | yes | bumped on schema change |
| `sub_area_id` | int | yes | the sub-area this map belongs to (§4) |
| `origin` | [q,r] | yes | axial coordinate of this sub-area's local origin in world space |
| `cells` | array<cell> | yes | explicit per-coordinate tile placements (see below) |
| `regions` | array<region> | no | compact fill form for large uniform areas; expanded before `cells` are applied |

**Cell object** (explicit placement):

| Field | Type | Required | Notes |
|---|---|---|---|
| `q` | int | yes | axial column ([ADR 0002](adr/0002-hex-grid-topology.md)) |
| `r` | int | yes | axial row |
| `tile` | string | yes | a `tiles.json` `id`; resolves to terrain/hazard/barrier/crossing |

**Region object** (compact fill, optional — for large maps):

| Field | Type | Required | Notes |
|---|---|---|---|
| `tile` | string | yes | a `tiles.json` `id` filling the region |
| `rect` | [q_min, r_min, q_max, r_max] | yes | inclusive axial bounding box filled with `tile` |

**Resolution order:** `regions` are expanded into cells first (in array order),
then `cells` are applied on top, so an explicit `cells` entry overrides any
region fill at the same `[q, r]`. A coordinate may appear at most once in the
final resolved grid. Cells whose `tile` has `category: "crossing"` are not
authored here in Phase 1 (crossings are placed at runtime); the terrain beneath a
crossing is the authored terrain/hazard cell.

```json
{
  "data_version": 1,
  "sub_area_id": 7,
  "origin": [0, 0],
  "regions": [
    { "tile": "forest", "rect": [0, 0, 9, 9] }
  ],
  "cells": [
    { "q": 4, "r": 0, "tile": "road" },
    { "q": 4, "r": 1, "tile": "road" },
    { "q": 0, "r": 5, "tile": "alpine_meadow" }
  ]
}
```

The `TileMapLayer` set is populated from the resolved grid at load: each cell is
routed to `TerrainLayer`, `HazardLayer`, or `CrossingLayer` by its tile's
`category` (§2). Patch derivation, mortality, and pathfinding read this grid and
the registry — never the painted tilemap.

## 13. Biome-compatibility schema (`data/biome_groups.json`)

The canonical biome registry and the patch-compatibility rules
([ADR 0007](adr/0007-patch-derivation-biome-compatibility.md)). Two adjacent
tiles join the same patch iff their biomes share a **group**; species viability
reads network tiles whose biome is in the species' habitat set, resolved through
the **terrain aliases**. This file is the single biome registry and supersedes the
unschematised `biome_definitions.json` referenced by `game/CLAUDE.md` (resolves
P0 inconsistency **B4**).

| Field | Type | Required | Notes |
|---|---|---|---|
| `data_version` | int | yes | bumped on schema change |
| `biomes` | string[] | yes | the canonical biome set; must match the `biome` values used by tiles (§2) |
| `groups` | object | yes | map of `group_id → biome[]`; the group key is the patch biome used by habitat `terrain_base`. Every canonical biome appears in exactly one group |
| `terrain_aliases` | object | no | map of finer `terrain_id → canonical biome`, so a species' `habitat_terrains` (§3) can use either a canonical biome or an aliased terrain id |

**Invariants:** every biome listed under `groups` and every value in
`terrain_aliases` is a member of `biomes`; each canonical biome belongs to exactly
one group; alias keys are disjoint from `biomes` (an alias never shadows a
canonical id).

```json
{
  "data_version": 1,
  "biomes": ["forest", "grassland", "alpine", "wetland", "sagebrush", "boreal", "old_growth", "cliff"],
  "groups": {
    "forest_complex": ["forest", "old_growth"],
    "open_range": ["grassland", "sagebrush"],
    "alpine": ["alpine"],
    "boreal": ["boreal"],
    "wetland": ["wetland"],
    "cliff": ["cliff"]
  },
  "terrain_aliases": {
    "forest_edge": "forest",
    "alpine_meadow": "alpine",
    "subalpine": "alpine",
    "alpine_grassland": "alpine"
  }
}
```

## 14. GameState save schema (save file)

The serialized save shape (A10), defined in
[ADR 0014](adr/0014-gamestate-serialization-shape.md). Versioned JSON,
reference-by-`id`, atomic write ([ADR 0005](adr/0005-save-file-format.md)). Stores
only **mutable runtime state**; static `data/` is referenced by id and never
duplicated, and derived state (connectivity graph, habitat-quality scores, agent
pool) is **rebuilt on `game_loaded`**, not stored.

| Top-level key | Type | Notes |
|---|---|---|
| `save_version` | int | migration-chain key; starts at `1`; bump = MAJOR |
| `meta` | object | `active_sub_area_id`, `saved_at_unix`, `playtime_seconds` |
| `clock` | object | `year`, `season`, `day_of_season`, `time_speed` |
| `economy` | object | `budget`, `last_donation` |
| `patches` | object[] | per patch: `patch_id`, `sub_area_id`, `species[]` of `{species_id, count, trend, connectivity_status}` |
| `entities` | object[] | per entity: `entity_id`, `trust`, `stage`, `partnership` |
| `information` | object | `areas_revealed[]`, `entities_revealed[]` (ids) |
| `crossings` | object[] | per crossing: `crossing_id`, `segment_id`, `sub_area_id`, `crossing_type`, `covered_tiles` (`[q,r]`[]), `built_on_day` |
| `milestones` | object | `reached[]` (ids), `capstone_reached` |

Enumerated strings (`season`, `trend`, `connectivity_status`, `stage`) use the
exact tokens from the population/permissions models. Absent optional keys take
system defaults on load. Full worked example and shape rules in ADR 0014.

---

## Cross-references

- What loads and saves this data: [`architecture`](architecture.md)
- How the values are used at runtime: [`simulation-design`](simulation-design.md)
- Save format and reference-by-id: [ADR 0005](adr/0005-save-file-format.md)
