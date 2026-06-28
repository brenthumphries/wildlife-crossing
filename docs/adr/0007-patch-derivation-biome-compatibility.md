---
title: "0007 — Patch Derivation and Biome Compatibility"
date: 2026-06-27
status: accepted
---

## Context

Patches are defined throughout the design set as "maximal contiguous zones of
**ecologically compatible terrain**" ([ADR 0004](0004-connectivity-patch-adjacency-graph.md),
[`game-design-overview`](../../obsidian-vault/prd/game-design-overview.md)), but
"compatible" is never defined. Without it `connectivity_graph` cannot derive
patches deterministically, and `habitat_manager` and `population_model` cannot
run. This is blocker **A2** in [`p0-open-questions`](../p0-open-questions.md).

Two readings collide in the documents:

1. **Biome-based** (species-agnostic): a patch is a contiguous zone of compatible
   biomes. `game-design-overview` reads this way — habitat quality is computed
   "per patch (a contiguous zone of ecologically compatible terrain)",
   `terrain_base` is "mean suitability for the **patch biome**", and ADR 0004's
   cheap one-node-per-patch graph depends on a patch being species-independent.
2. **Species-relative**: a patch is contiguous tiles within one species'
   `habitat_terrains`. The `population_model` monthly-step sketch
   ([`simulation-design` §5](../simulation-design.md)) reads this way — it calls
   `patch.resident_species()` and compares `species.min_viable_patch_size`.

They cannot both define patch identity: the species-relative reading multiplies
graph nodes per species and breaks ADR 0004's performance model, while the
biome-based reading alone would let a species count tiles it cannot live on.

A related gap: the eight canonical biomes in the tile schema
([`data-schemas` §2](../data-schemas.md)) are `forest, grassland, alpine,
wetland, sagebrush, boreal, old_growth, cliff`, but several species
`habitat_terrains` use finer terrain names not in that set (`alpine_meadow`,
`forest_edge`, `subalpine`, `alpine_grassland`). And blocker **B4** notes
`biome_definitions.json` is referenced by `game/CLAUDE.md` but never schematised.

## Decision

Separate **patch identity** from **viability**; they answer different questions.

### 1. Patch identity is biome-based (species-agnostic)

A patch is a maximal set of edge-contiguous tiles whose biomes belong to the same
**compatible-biome group**. One patch is one node in the patch-adjacency graph,
independent of any species — ADR 0004's model is preserved unchanged. Hazard and
barrier tiles (`is_hazardous` / `is_impassable`) belong to no patch; they are what
splits otherwise-contiguous habitat into separate patches.

Compatible-biome groups are **tight** and authored in data
(`game/data/biome_groups.json`, schema in [`data-schemas` §13](../data-schemas.md)).
This file is the canonical biome registry and **supersedes the unschematised
`biome_definitions.json`, resolving B4.** The launch grouping:

| Group | Biomes |
|---|---|
| `forest_complex` | `forest`, `old_growth` |
| `open_range` | `grassland`, `sagebrush` |
| `alpine` | `alpine` |
| `boreal` | `boreal` |
| `wetland` | `wetland` |
| `cliff` | `cliff` |

Only near-identical types merge; distinct ecosystems stay separate so patches stay
small and connectivity does the work, rather than one giant patch trivialising the
`min_viable_patch_size` thresholds.

### 2. Patch edges (safe links) — two kinds

- **Contiguity link:** two patches whose tiles are edge-adjacent with no hazard or
  barrier between them are safe-linked for free (an animal walks across the biome
  transition). A `forest_complex` patch touching an `alpine` patch is linked.
- **Crossing link:** two patches separated by a hazard/barrier band are linked
  only by a completed same-type crossing chain (the existing ADR 0004 rule).

Both kinds put patches in the same **network** (connected component).

### 3. Viability is species-relative, computed over the network

Viability does **not** redefine the patch. For a species, the effective size is
the connected network's tile count **restricted to the biomes the species
inhabits**:

```gdscript
# population_model.gd — replaces network.total_tile_count()
var effective_size := network.habitat_tile_count(species)   # Σ tiles whose biome ∈ species habitat biomes
var viable := effective_size >= species.min_viable_patch_size
```

A species' habitat biomes are resolved from `habitat_terrains` through the
canonical biome set and the **terrain alias map** in `biome_groups.json`
(`alpine_meadow`→`alpine`, `forest_edge`→`forest`, `subalpine`→`alpine`,
`alpine_grassland`→`alpine`). Each network tile's biome comes from its
`tiles.json` entry (§2). So `habitat_terrains` may carry either a canonical biome
or an aliased terrain id; both resolve deterministically and the species stub
tables need no rewrite.

This makes the grizzly case correct without merging biomes: grizzly inhabits
`forest` and `alpine`, which stay separate patches; grizzly is viable when its
forest-tiles + alpine-tiles across one connected network reach 220 — so a crossing
that joins a forest patch to an alpine (or another forest) patch is what tips it
viable. Connectivity is mechanical, not cosmetic.

## Consequences

### Positive

- ADR 0004's one-node-per-patch graph and performance budget are unchanged.
- The biome→viability rule is ecologically honest: a species only ever counts
  habitat it can occupy, while patches stay species-agnostic and cheap.
- Resolves B4: `biome_groups.json` is the single biome registry; the orphaned
  `biome_definitions.json` reference is retired.
- Deterministic patch derivation unblocks A6 (habitat-quality sub-formulae — a
  patch now has one well-defined biome group for `terrain_base`) and the Phase 1
  `connectivity_graph` / `habitat_manager` / `population_model` tests.
- Tunable in data: difficulty is adjusted by editing groups, not code.

### Negative / Trade-offs

- Two link kinds (contiguity vs crossing) mean patch derivation must classify
  every inter-patch boundary; this is O(perimeter) per sub-area at load, within
  the ADR 0004 budget but more than a naïve flood fill.
- The terrain alias map is a small indirection that must be kept in step with any
  new biome or species terrain; it is centralised in `biome_groups.json` to keep
  that cost in one place.

### Neutral / Follow-on work

- A5 (carrying capacity, recovery rate, `DECLINE_STEP`) still owns the numbers the
  monthly step consumes; this ADR fixes only the *size* term it compares against.
- `network.habitat_tile_count(species)` and the contiguity/crossing edge
  classification are added to `connectivity_graph.gd`; a GUT test asserts the
  grizzly rescue case on the Bow Valley fixture
  (`game/tests/fixtures/bow_valley_slice.json`).
- If finer within-biome suitability is later wanted, `terrain_suitability` on
  tiles (§2) already carries it for `terrain_base`; it does not affect patch
  identity.
