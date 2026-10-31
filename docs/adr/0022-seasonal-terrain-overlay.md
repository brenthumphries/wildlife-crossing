---
title: "0022 — Seasonal Terrain as a Hazard Overlay"
date: 2026-10-30
status: accepted
---

## Context

[`simulation-design`](../simulation-design.md) §6 asks for two terrain shifts:
winter freezes rivers (a frozen river tile clears `is_hazardous`) and spring
floods widen river hazard zones by one tile. It goes further and says the shifts
**re-derive the affected patches**, so `connectivity_graph` re-derives patch
identity for the active sub-area on every `season_changed`
([architecture](../architecture.md) §6, [ADR 0004](0004-connectivity-patch-adjacency-graph.md)).

Q9 (roadmap Phase 4, decision logged 2026-10-16) fixed the rules: winter clears
the hazard on river tiles, spring widens river hazard zones by one tile, summer
and fall use the base terrain. The v0.2.0 scope block in roadmap Phase 3 narrows
C39 to hazard changes for pathing and mortality, because the release has one
feature freeze and no fallback build.

Full re-derivation is the riskiest recompute in the design, for reasons the
code makes concrete:

- Patches are derived from the base `is_hazardous` / `is_impassable` flags
  ([ADR 0007](0007-patch-derivation-biome-compatibility.md)). A frozen river
  merges the patches on its two banks; a spring flood can shrink a patch or
  split it.
- `PopulationModel` keys counts, trends and connectivity status by patch
  index, and saves key them by `ConnectivityGraph.patch_key` (ADR 0014). A
  merge or split has no defined mapping for those records: which count does a
  merged patch get, and how does it divide again in spring?
- `HabitatManager` quality, the agent pool (keyed by patch and species), the
  milestone and information layers, and crossing links (ADR 0016's two-sided
  core reads the base hazard flags) all read the graph.
- `InfrastructureManager.can_place` and ADR 0016's span rule read
  `is_hazardous`. A frozen river would stop being a placeable hazard in winter,
  so build mode would refuse the river segment for a quarter of the year.

## Decision

Seasonal terrain is a **derived, unsaved overlay on `WorldData`** read only by
pathing, mortality and the renderer. The base flags never change with the
season, so the graph, patches, population records and crossings stay as built.

- `WorldData.apply_season(season)` rebuilds two sets from the static grid:
  `_frozen` (every `river` tile, in winter) and `_flooded` (every in-bounds
  neighbour of a `river` tile that is neither hazardous nor impassable, in
  spring). Summer, fall and any other value leave both empty. Roads and other
  hazards keep their own flag; barriers never flood.
- `is_effective_hazard(c)` is the flag pathing and mortality read: false on
  ice, true on a flood, otherwise the base `is_hazardous`. `hazard_tile_at(c)`
  returns `river` for a flooded bank so its mortality comes from
  `RIVER_HAZARD_MORTALITY` and its death cause reads as a river.
- `Pathfinding` edge costs and `path_crosses_hazard`, `SpeciesManager`
  mortality and `walk`, and the simulation's per-step mortality and
  corridor-study attempt records use the effective flag. `is_hazardous` stays
  the base flag for `ConnectivityGraph`, `HabitatManager`,
  `InfrastructureManager`, build mode and the segment picker.
- `Simulation` applies the season on `load_world`, after `restore_state` sets
  the clock, and in `_on_season_changed`. On a season change it re-paths every
  living agent from where it stands to the goal it already had, so no cached
  path outlives the terrain it was planned on. Keeping the goal keeps the seeded
  RNG untouched.
- The overlay is never saved. It is a pure function of the static grid and the
  saved season, so ADR 0014's "derive, don't store" rule covers it.
- `WorldRenderer.tile_color` draws a frozen river in pale ice and a flooded bank
  in brown floodwater, distinct from the base river's hazard red.

This deliberately **narrows `simulation-design` §6**: there is no seasonal
patch re-derivation, and a frozen river does not merge patches. It is a free
route that pathing and mortality see. Connectivity, habitat quality and the
overlay show the base, year-round picture.

## Consequences

### Positive

- `season_changed` costs `O(tiles)` for the overlay plus one A* per living
  agent, well inside architecture §6's 16 ms budget, and touches no
  demographic state.
- Patch ids, population records, saves, crossing links and milestones are
  untouched by the season, so nothing can be lost or misassigned across a
  boundary, and existing saves load unchanged.
- Build mode and completed crossings work in every season. A crossing over a
  river stays a placeable, valid span in winter, and covered tiles stay
  zero-mortality in spring.
- The season is visible where it matters: winter crossings over ice cost
  nothing and kill nothing, spring floods raise attempts and deaths, and the
  map shows both.

### Negative / Trade-offs

- The connectivity overlay and habitat-quality `connectivity_bonus` do not
  reflect a frozen river. Two banks joined by ice still read as separate
  patches, and the monthly step does not reward the winter link. This is a
  stated gap against §6, not a bug.
- A spring flood makes the banks beside a completed crossing hazardous, so an
  animal leaving the covered tiles onto a flooded bank takes a mortality roll.
  This is ecologically plausible, but it means a crossing is safe across the
  river and not across the floodplain.
- Two hazard predicates exist (`is_hazardous` and `is_effective_hazard`). A
  future caller has to choose the right one. The docstrings and this ADR say
  which systems read which.
- Bow Valley (sub-area 7), the only playable sub-area in v0.2.0, has no river
  tiles, so players will not see the effect until a river sub-area is
  playable. It is exercised in tests on sub-area 1.

### What full re-derivation would require

Superseding this ADR with §6 as written needs, at minimum:

1. **Seasonal patch derivation.** `ConnectivityGraph.build` reads the effective
   flags, and the graph is rebuilt for the active sub-area on `season_changed`,
   with inactive sub-areas rebuilt lazily.
2. **A population remap.** A rule mapping records across merges and splits
   (sum on merge; split by tile share or by habitat capacity on split), with
   trend and connectivity status recomputed, plus a test that a full year
   round-trips counts exactly.
3. **Stable patch keys across seasons.** Saves key patches by
   `patch_key`, so a save made in winter must restore into a summer graph or
   the reverse. The likely answer is to always save against the base-terrain
   patches and remap on load.
4. **Agent pool reassignment.** Agents carry a `patch` index, so the pool must
   be re-keyed or rebuilt without visibly resetting the world.
5. **Crossing placement in a frozen season.** A decision on whether a frozen
   river is still a placeable hazard, and whether ADR 0016's span rule reads
   base or effective flags.
6. **Habitat-quality and milestone recompute** on every boundary, and a check
   that a milestone reached through a winter-only link does not un-reach in
   spring.

### Neutral / Follow-on work

- `simulation-design` §6 and architecture §6 still describe re-derivation. A
  follow-on docs item amends both to point here.
- The flood width is fixed at one tile by Q9 and implemented as the river's
  hex neighbours. A wider flood would need a ring search rather than a
  neighbour pass.

### Rejected alternative

**Mutate the base flags in place.** Writing the seasonal flags into `WorldData`'s
tile lookup (or swapping tile ids, for example `river` to a `river_frozen`
tile) would make every system see the season with no new predicate. It was
rejected because every system would then see it: `ConnectivityGraph` and
`HabitatManager` would derive different patches if anything rebuilt them,
build mode would refuse a frozen river segment, and ADR 0016's span validation
of saved crossings on load would change with the season. That is full
re-derivation without the remap, the worst of both.
