---
title: "PRD — Wildlife Overpass Crossing"
date: 2026-05-09
tags: [prd, system, infrastructure, pathfinding]
status: draft
---

## Problem statement

Animals in the simulation must navigate a landscape that contains two kinds of
dangerous terrain. Hard barriers — fences, walls, buildings, and urban zones —
are completely impassable without a crossing structure. Hazardous tiles — roads
and rivers — are passable, but every tile an animal enters carries a per-step
probability of death. Over time this causes population decline and fragmentation.
The player's job is to build overpass crossings that span these dangerous tiles
and give animals a safe, zero-mortality route across. Without this feature, the
player has no meaningful tool to counteract habitat fragmentation, which is both
ecologically central to the game's premise and essential to the core gameplay
loop of managing a healthy, connected ecosystem.

---

## Goals

1. **Animals navigate barriers via crossings.** When an overpass is placed over a
   barrier, animals in the simulation pathfind through it to reach the other side,
   making habitat connectivity a mechanical reality.
2. **Hazardous terrain carries real risk.** Animals that traverse road or river
   tiles without an overpass face a per-step probability of death, making the
   crossing a meaningful player tool rather than decoration.
3. **Species-crossing preference is modelled.** Each species has a preferred
   crossing type. Animals are statistically more likely to use a crossing that
   matches their preference, creating a foundation for deeper species-specific
   design in future releases.
4. **Crossing success is legible and rewarding.** The player receives a clear
   visual and audible signal when an animal successfully uses a crossing, making
   the moment feel earned.
5. **The system is composable.** The overpass is the first of multiple crossing
   types (underpass, corridor). The data model and pathfinding hooks must support
   future types without a structural rewrite.

---

## Non-goals

- **No species-specific crossing structures in v1.** Every species can use any
  overpass; preference affects probability, not hard eligibility. Species-specific
  variants are a v2 concern.
- ~~**No economy or resource cost.** Overpasses can be placed freely. An in-game
  cost system is a separate feature and would introduce complexity that is not
  central to validating the core mechanic.~~
  *Superseded (2026-06-14): the no-cost rule existed to validate the core mechanic
  in isolation. In the full game, crossings cost budget — **5,000 per overpass
  tile** (a three-tile road span costs 15,000). Constants live in
  `economy_constants.gd` and are tunable without code changes. See the economy
  section of [[game-design-overview]].*
- **No upgrades or tiers.** A single overpass tile is the only crossing object.
  Upgrades, sizing variants, and cosmetic skins are out of scope.
- **No underpass or corridor types.** This PRD covers overpasses only. Underpasses
  and corridors will be specced separately once the overpass system is validated.
- **No multiplayer or async crossing events.** All simulation runs locally in a
  single-player session.

---

## Proposed solution

The player selects an overpass tile from the build palette and places it over a
dangerous tile (road, river, or hard barrier), choosing where along the hazard
the crossing goes. When tiled continuously across the full width of the
dangerous terrain at that point — not along its length — the overpass creates a
safe, traversable route with zero mortality risk. During simulation, the pathfinding system prefers
overpass routes over direct traversal of hazardous tiles. Animals that cross via
an overpass are guaranteed to survive; those that cross road or river tiles
directly face a per-step mortality probability loaded from an environment variable.
Hard barrier tiles (fences, walls, buildings, urban zones) remain completely
impassable without an overpass. When an animal successfully crosses via an
overpass, a visual indicator (e.g. a brief particle effect or animation on the
crossing tile) and a short audio cue fire to reward the player.

---

## Key mechanics / rules

1. **Two categories of dangerous terrain exist.**

   - **Hard barriers** (fences, walls, buildings, urban zones): flagged
     `is_impassable = true`. Animals cannot enter these tiles at all; they are
     completely blocked in the pathfinding graph.
   - **Hazardous tiles** (roads, rivers): passable, but each tile step carries a
     per-step mortality probability. Animals can and will pathfind across them
     if no safer route exists, but risk dying on every step.

2. **An overpass must span the full width of the dangerous terrain at the point
   it crosses.** The player tiles overpass tiles across each cell of that width
   individually (e.g. a three-tile-wide river requires three overpass tiles). A
   partial span — where one or more cells of the width remain uncovered — does
   not create a safe route. When the span is complete, the pathfinding graph
   gains a zero-mortality connection through the full overpass chain. Hard
   barrier tiles covered by an overpass become traversable.

   **A span is not a segment.** *(Clarified 2026-07-19 — see
   [[segment-vs-span-defect]].)* A **segment** is an entire hazardous corridor,
   authored in `segments.json`; it is the unit the player *selects* on the world
   map, and may run for many tiles along its length (the Bow Valley tutorial
   highway is 2 wide × 10 long = 20 tiles). A **span** is the structure the
   player *builds* across that corridor's width at one chosen point along it —
   for Bow Valley, 2 tiles. Completing a crossing requires covering the width,
   never the corridor's length. The road remains visible and hazardous
   everywhere the player did not build.

3. **Each hazardous tile type has its own mortality probability and environment
   variable.** Each step an animal takes onto an uncovered hazardous tile triggers
   a mortality check against a probability specific to that tile type:

   | Tile type | Environment variable       | Default |
   |-----------|----------------------------|---------|
   | Road      | `ROAD_HAZARD_MORTALITY`    | `0.20`  |
   | River     | `RIVER_HAZARD_MORTALITY`   | `0.20`  |

   Each variable is read independently at simulation start and falls back to
   `0.20` if absent. This allows per-terrain tuning without a code change.
   Animals that die during a hazardous crossing are removed from the simulation
   immediately.

4. **Species have a preferred crossing type.** Each species definition includes a
   `preferred_crossing_type` field (values: `overpass`, `underpass`, `corridor`).
   When evaluating available crossings, the pathfinding weight for a crossing
   matching the species' preference is lower (more attractive) than for a
   non-preferred type. For v1, all crossings are overpasses, so species that
   prefer overpasses will cross more frequently than species that prefer other
   types — making some species harder to support until those crossing types exist.

5. **No crossing placement on non-barrier tiles.** The player cannot place an
   overpass on a tile that does not contain a barrier. Attempting to do so shows
   an error indicator.

6. **Crossing success fires a feedback event.** When an animal completes a
   crossing traversal, an `animal_crossed` signal is emitted. The UI layer
   subscribes to this signal to play the visual and audio feedback.

---

## User stories

**As a player**, I want to place an overpass over a road that divides two habitat
zones so that animals can safely travel between them and my ecosystem stays
connected.

**As a player**, I want to see an animal visibly path through the overpass with a
celebratory cue so that I feel rewarded for building the crossing and can confirm
it is working.

**As a player**, I want animals that walk across roads or rivers without an
overpass to sometimes die so that the stakes of building infrastructure feel real
and meaningful.

**As a player**, I want some species to preferentially use overpasses over other
crossing types so that I understand each species has distinct needs I can learn
and cater to.

**As a player**, I want the game to prevent me from placing an overpass on a
non-barrier tile so that I cannot accidentally misplace it and waste a build
action.

---

## Requirements

### Must-have (P0)

- **Tile danger properties.** Tile types expose two danger properties used by the
  pathfinding system: `is_impassable` (hard barriers: fences, walls, buildings,
  urban zones) and `is_hazardous` (roads, rivers). These are mutually exclusive.
  *Acceptance: Pathfinding tests confirm `is_impassable` tiles block movement
  entirely, and `is_hazardous` tiles are traversable but trigger mortality checks.*

- **Overpass tile type.** A new placeable tile type `overpass` exists in the tile
  registry. It can be placed by the player via the build palette.
  *Acceptance: Player can select and place an overpass tile; it appears correctly
  on the map.*

- **Overpass placement validation.** Overpass placement is only valid when the
  target tile is flagged `is_impassable` or `is_hazardous`. Invalid placement
  shows a red preview state.
  *Acceptance: Placing on a plain terrain tile is rejected and shows an error
  state; placing on a dangerous tile succeeds.*

- **Pathfinding graph update.** When overpass tiles span every cell of the
  dangerous terrain's width at the crossing point, the navigation graph adds
  zero-mortality traversable edges through the full overpass chain. A partial
  span does not unlock the route.
  *Acceptance: Animals cannot safely path through a partially-spanned width;
  once every cell of that width is covered, animals route through the overpass
  and survive. Tiles of the same corridor away from the span stay hazardous —
  building one crossing must not make the whole corridor safe.*

- **Per-terrain hazardous mortality via environment variables.** Each step onto
  an uncovered `is_hazardous` tile triggers a mortality check using a probability
  specific to that tile type: `ROAD_HAZARD_MORTALITY` for roads and
  `RIVER_HAZARD_MORTALITY` for rivers. Both default to `0.20` if absent.
  *Acceptance: Setting `ROAD_HAZARD_MORTALITY=0.5` causes road deaths at ~50%
  per step while river mortality remains at its own configured rate. Each
  variable can be set, overridden, or unset independently.*

- **`animal_crossed` signal.** The animal or crossing system emits a signal when
  an animal successfully completes a crossing traversal.
  *Acceptance: Signal fires exactly once per successful overpass traversal in
  automated tests.*

- **Crossing success feedback.** A visual effect (particle or animation) and audio
  cue play on the overpass tile when the `animal_crossed` signal fires.
  *Acceptance: Playing the simulation with a functioning crossing triggers both
  visual and audio feedback visible to the player.*

### Nice-to-have (P1)

- **Species preference weighting.** Each species definition includes a
  `preferred_crossing_type` field. The pathfinding cost for a crossing that
  matches the species' preference is lower than for non-preferred types, making
  preferred crossings statistically more attractive.
  *Acceptance: In a test with multiple crossing types available, a species
  configured to prefer overpasses uses them at a measurably higher rate.*

- **Crossing usage counter.** Each overpass tile tracks how many animals have
  successfully crossed it. This data is visible in a tile-inspect UI.
  *Acceptance: Clicking an overpass tile shows a usage count that increments with
  each crossing event.*

### Future considerations (P2)

- **Underpass and corridor crossing types.** Once the overpass is validated,
  additional crossing types (underpass, corridor) will be specced and implemented.
  The tile data model and pathfinding hooks should be designed to accommodate new
  crossing types by adding new tile type entries rather than requiring structural
  changes.
- **Economy and build cost.** Crossings may eventually cost in-game resources to
  place, tying the feature into a resource management system.
- **Crossing upgrades.** A tiered upgrade system that expands crossing capacity,
  adds habitat plantings on the overpass, or increases species preference
  attraction.
- **Seasonal crossing behaviour.** Some species prefer certain crossing types
  during specific seasons (e.g. migration corridors in autumn). This would extend
  the species preference system to be season-aware.

---

## Open questions

- ~~**What is the right default mortality rate for unassisted crossings?**~~
  *Resolved: **20%** per hazardous tile step for all terrain types. Each type has
  its own environment variable — `ROAD_HAZARD_MORTALITY` and
  `RIVER_HAZARD_MORTALITY` — both defaulting to `0.20` if absent.*

- ~~**How should crossing placement work across multi-tile barriers?**~~
  *Resolved: the player must tile an overpass across **each cell** of the barrier.
  A three-tile-wide river requires three overpass tiles placed end-to-end. A
  partial overpass (not spanning the full barrier width) does not create a
  traversable connection.*

- ~~**How does the pathfinding system handle diagonal crossing attempts?**~~
  *Resolved: the map uses a hex grid, where every tile has exactly six direct
  neighbours and no diagonal relationships exist. Pathfinding is 6-directional
  across these six edges; because every edge is a direct connection, crossing
  choice is always unambiguous — an animal must pass through one of its six
  neighbouring tiles.*

- ~~**Is the `animal_crossed` signal per-animal, per-crossing, or global?**~~
  *Resolved: the signal is per-animal, per-completed-traversal. The feedback layer
  coalesces signals per crossing within a 2-second window into a single
  visual/audio cue with a small "+N" counter, so simultaneous crossings never
  stack into noise.*

- ~~**What tile does the overpass render as?**~~
  *Resolved: a vegetated pixel-art overpass with earthen ramps and native
  plantings, in the warm Stardew-register palette; three visual variants keyed to
  surrounding biome (forest, grassland, alpine). A placeholder sprite is
  acceptable through prototype; the art direction document finalizes the spec.*

---

## Success criteria

**The feature is working when:**

- Animals on one side of a barrier visibly navigate to and through a player-placed
  overpass to reach the other side during simulation.
- Animals that walk across road tiles without overpass coverage die at
  approximately the rate set by `ROAD_HAZARD_MORTALITY`, and those crossing
  river tiles die at the rate set by `RIVER_HAZARD_MORTALITY`, each observable
  independently over repeated simulation runs.
- Placing an overpass and watching the first animal cross triggers both a visual
  cue (particle / animation) and audio feedback.
- The GUT test suite includes at least one test for pathfinding through a crossing,
  one for unassisted barrier mortality, and one for the `animal_crossed` signal.

**Stretch indicators:**

- A player unfamiliar with the game, after observing an animal die at a barrier,
  discovers and places an overpass without prompting, then reacts positively when
  the first animal crosses.

---

## Related

- [[game-design-overview]] *(to be written)*
- ADR reference: none yet — crossing tile architecture may warrant one once the
  multi-type crossing system is designed.
