---
title: "0015 — ecosystem_manager Disposition, Overpass Biome Fallback, Animal Scene Structure"
date: 2026-06-28
status: accepted
---

## Context

Three remaining cross-document inconsistencies from
[`p0-open-questions`](../p0-open-questions.md) — **B5**, **B6**, **B7** — each
"settleable alongside the system it touches." They are grouped here as the last of
the P0 inconsistency cleanup.

- **B5 — `ecosystem_manager.gd` is orphaned.** `game/CLAUDE.md`'s systems table
  lists it (food web, resource flows, biodiversity score), but it appears in no
  `architecture` system map, signal catalogue, test plan, or roadmap phase.
- **B6 — overpass biome variants don't cover all biomes.** `art-direction` §4 and
  the `infrastructure.json` schema define exactly three overpass sprite variants
  (`forest`, `grassland`, `alpine`), but the eight canonical biomes
  ([`biome_groups.json`](../../game/data/biome_groups.json)) also include `wetland`,
  `sagebrush`, `boreal`, `old_growth`, `cliff`. Placement (Phase 2) needs a defined
  biome→variant mapping for every biome.
- **B7 — animal scene structure.** `game/CLAUDE.md` says world entities use
  `EntityRoot → Sprite2D, CollisionShape2D, [AnimationPlayer]`, but movement is
  tick-based A* on the hex grid with render interpolation ([`architecture` §4](../architecture.md))
  — there is no physics, so a `CollisionShape2D` has nothing to do.

## Decision

### B5 — `ecosystem_manager` deferred post-v1

`ecosystem_manager` is **removed from the active systems table** and recorded as a
**deferred post-v1 ambition**, not cut. The v1 design already covers per-patch
viability and recovery through `population_model` + `habitat_manager`; a dedicated
food-web / resource-flow / biodiversity-score layer is out of P0/P1/P2 scope and is
absent from the architecture by design. It is kept on record here as a possible
future system so a later effort has a defined starting point. No code, tests, or
signals exist for it in v1; its `game/CLAUDE.md` row is removed.

### B6 — overpass biome→variant fallback map

Every biome resolves to one of the three v1 overpass variants by structural-
vegetation analogy, aligned with the compatible-biome groups (ADR 0007):

| Biome | Overpass variant | Rationale |
|---|---|---|
| `forest` | `overpass_forest` | direct |
| `old_growth` | `overpass_forest` | `forest_complex` group |
| `boreal` | `overpass_forest` | coniferous woodland reads as forest |
| `grassland` | `overpass_grassland` | direct |
| `sagebrush` | `overpass_grassland` | `open_range` group |
| `wetland` | `overpass_grassland` | low open vegetation, not coniferous |
| `alpine` | `overpass_alpine` | direct |
| `cliff` | `overpass_alpine` | rock/scree, hardy alpine plantings |
| `subalpine` *(alias → alpine)* | `overpass_alpine` | per `terrain_aliases` |

The **default fallback is `overpass_forest`** for any biome not listed. The mapping
is data-driven: placement resolves the surrounding patch biome, applies any
`terrain_aliases` (§13), then reads this fallback table. It is recorded in
`data-schemas` §8 next to `biome_sprite_variants`. Dedicated `wetland`/`boreal`
variants can be added later by extending `biome_sprite_variants` without changing
placement logic.

### B7 — animals are physics-free `Node2D`

Animals are **`Node2D` (`EntityRoot`) → `Sprite2D`, `[AnimationPlayer]`** — **no
`CollisionShape2D`, no physics body**. Movement is tick-based A* with render
interpolation between sim steps; there is no collision system, so animals carry no
physics node. `game/CLAUDE.md`'s generic `EntityRoot → Sprite2D, CollisionShape2D,
[AnimationPlayer]` convention is annotated: `CollisionShape2D` is **only** for
entities that need pointer-picking/area hit-testing (e.g. selectable static props),
not for simulated animals. `Animal.tscn` follows the physics-free structure.

## Consequences

### Positive

- The systems table now matches the architecture exactly — no orphan implying
  unbuilt work (B5).
- Crossing placement has a total biome→sprite function for Phase 2, with no
  undefined biomes (B6).
- `Animal.tscn` is specified and minimal; no inert physics nodes, consistent with
  the deterministic tick model and its tests (B7).

### Negative / Trade-offs

- `wetland` and `boreal` overpasses reuse an analogous variant until dedicated art
  ships — a cosmetic approximation, not a simulation effect (crossings are
  data-driven; the variant is sprite-only).
- Deferring rather than cutting `ecosystem_manager` leaves a backlog note that must
  be revisited intentionally rather than forgotten.

### Neutral / Follow-on work

- Edit `game/CLAUDE.md`: remove the `ecosystem_manager` row (B5) and annotate the
  entity-scene convention (B7) — done alongside this ADR.
- Add the overpass fallback table to `data-schemas` §8 (B6) — done alongside this
  ADR.
- A future post-v1 ecosystem/biodiversity ADR, if pursued, supersedes the B5 note
  here.
