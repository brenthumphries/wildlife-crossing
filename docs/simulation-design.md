---
title: "Simulation and Pathfinding Design"
date: 2026-06-17
status: active
---

## Purpose

This document specifies the runtime behaviour of the simulation: how the
hex-grid pathfinding graph is built and updated, how crossing-preference cost
weighting and mortality checks work, the population model (per-patch counts,
viability, recovery events), seasonal modifiers, and the determinism and
tick-rate decisions. It includes GDScript-flavoured pseudocode for the two steps
the design plan requires sketches of: the graph update on crossing completion,
and the monthly population step.

It builds on [`architecture`](architecture.md) (tick model, signal map) and the
data shapes in [`data-schemas`](data-schemas.md), and realises the mechanics in
[`wildlife-overpass-crossing`](../obsidian-vault/prd/wildlife-overpass-crossing.md)
and [`game-design-overview`](../obsidian-vault/prd/game-design-overview.md).

---

## 1. The two graphs

The simulation maintains two distinct graphs, deliberately separated by purpose
and update frequency:

1. **Movement graph** (`pathfinding.gd`) — fine-grained, one node per hex tile,
   edges to the six neighbours. Used to route individual animals. Edge
   *traversability* and *cost* depend on tile flags and crossings. Queried often
   (per animal, per step) but only *read*; it is mutated only when a crossing
   completes or terrain shifts seasonally.

2. **Patch-adjacency graph** (`connectivity_graph.gd`) — coarse, one node per
   habitat patch, edges = safe links. Used for the connectivity overlay, the
   habitat-quality `connectivity_bonus`, trust metrics, and the capstone check.
   Recomputed only on graph-changing events ([ADR 0004](adr/0004-connectivity-patch-adjacency-graph.md)).

Keeping them separate means the expensive coarse analytics never run per frame,
and the per-animal routing never has to reason about whole-patch connectivity.

---

## 2. Hex movement graph

Topology is hexagonal with 6-directional connectivity
([ADR 0002](adr/0002-hex-grid-topology.md)). For a tile at axial `[q, r]`, the
six neighbours are the standard axial offsets `(+1,0) (+1,-1) (0,-1) (-1,0)
(-1,+1) (0,+1)`. There are no diagonals, so every move crosses exactly one edge
and crossing choice is always unambiguous.

### Edge eligibility and cost

For a step from tile `a` into neighbour `b`:

- If `b.is_impassable` **and** `b` is not covered by a completed crossing chain →
  the edge does not exist (blocked).
- If `b` is covered by a completed crossing chain → edge exists, **zero mortality**,
  cost = `base_cost × crossing_pref_modifier(species, crossing_type)`.
- If `b.is_hazardous` and uncovered → edge exists, cost = `base_cost × HAZARD_AVOIDANCE_MULT`,
  and stepping in triggers a mortality check (§4).
- Otherwise (plain terrain) → edge exists, cost = `base_cost`.

`crossing_pref_modifier` returns `infrastructure.preference_cost_modifier`
(`< 1.0`, more attractive) when `crossing_type == species.preferred_crossing_type`,
else `1.0`. Preference therefore changes *probability of use*, never *eligibility*
— exactly as the PRD requires. Because v1 ships only overpasses, species that
prefer underpasses/corridors get no discount and cross less often by design.

> Decision logged: `HAZARD_AVOIDANCE_MULT` (a `simulation_constants.gd` value,
> default 4.0) makes uncovered hazardous tiles costly but not forbidden, so
> animals prefer a crossing when one exists yet will still risk a road when no
> safe route is reachable — producing the unassisted-mortality the game needs.

### Pathfinding algorithm

A* over the hex movement graph, hex distance (cube-coordinate) as the heuristic.
Animals path toward a goal tile chosen by the species/season layer (a habitat
patch within range, biased by seasonal motivation, §6). Paths are cached per
animal and invalidated on `crossing_completed` and `season_changed` for the
affected sub-area.

### Goal selection (pre-season, Phases 1–2)

With no seasonal layer yet, an idle animal runs a season-independent forage/wander
drive ([ADR 0010](adr/0010-pre-season-goal-selection.md)). When it becomes idle
(spawned, or having reached its goal and dwelled `IDLE_DWELL_TICKS`): with
`WANDERLUST_PROB` it **travels** to another compatible patch (biome ∈ its habitat
set, ADR 0007/0009) within `range_tiles × MOTIVATION_DISTANCE_MULT`, chosen by
weighted random draw `w(P) = (quality(P) + GOAL_QUALITY_FLOOR) / (1 + dist(P))`;
otherwise it **forages** within `FORAGE_RADIUS_TILES`. Paths also re-evaluate on a
soft `REPATH_INTERVAL_TICKS` cadence so animals react to a new crossing. All draws
use the shared seeded RNG (§7).

Hazardous crossing attempts are **emergent, not flagged**: A* already prices an
uncovered hazard at `base_cost × HAZARD_AVOIDANCE_MULT` and detours around it when
a safe route exists, so an animal risks a hazard only when its goal has no safe
route — fragmentation is the sole cause of unassisted death. Once an overpass
covers the band, the zero-mortality covered edge is cheaper and A* routes animals
through it. Phase 4 seasons scale `MOTIVATION_DISTANCE_MULT` only; no new goal
machinery is added.

---

## 3. Crossing span validation and the graph update

An overpass creates a safe route only when it spans **every** dangerous cell of
the segment with a connected, single-type chain
([`wildlife-overpass-crossing`](../obsidian-vault/prd/wildlife-overpass-crossing.md) mechanic 2;
[ADR 0003](adr/0003-crossing-tile-architecture.md)). Partial spans connect
nothing.

### Sketch — graph update on crossing completion

```gdscript
## infrastructure_manager.gd — fires when the last tile of a span is placed.
func try_complete_crossing(segment: Segment, crossing_type: String) -> void:
    # 1. Span completeness: every dangerous cell in the segment must be covered
    #    by a crossing tile of the SAME type, forming one connected chain.
    var dangerous := segment.tiles.filter(func(t): return t.is_hazardous or t.is_impassable)
    var covered := dangerous.filter(func(t): return _has_crossing_of_type(t, crossing_type))
    if covered.size() != dangerous.size():
        return                      # partial span: no route, no signal
    if not _chain_is_connected(covered):
        return                      # gaps in the chain: not traversable

    # 2. Mutate the MOVEMENT graph: add zero-mortality edges through the chain,
    #    and make covered impassable tiles traversable.
    for tile in covered:
        movement_graph.set_zero_mortality(tile)         # crossing edge cost, no death
        if tile.is_impassable:
            movement_graph.set_traversable(tile)        # barrier now passable
    _link_chain_endpoints_into_neighbours(covered)      # connect both sides

    # 3. Update the PATCH-ADJACENCY graph: the two patches the span bridges
    #    gain a safe link. This is the only place a crossing adds a patch edge.
    var endpoints := _patches_adjacent_to_chain(covered) # the two sides
    connectivity_graph.add_safe_link(endpoints[0], endpoints[1], crossing_type)

    # 4. Localised recompute (O(P + L)); never a full rebuild.
    connectivity_graph.recompute_reachability(segment.sub_area_id)  # cached
    habitat_manager.recompute_affected_patches(endpoints)           # quality bands

    # 5. Announce. Downstream: economy (income), milestones, overlay refresh.
    var crossing := Crossing.new(segment, crossing_type, covered)
    EventBus.crossing_completed.emit(segment.id, crossing_type, segment.sub_area_id)
```

The movement-graph mutation is local to the span; the patch-graph update adds one
edge and re-derives reachability for the sub-area only — the `O(P + L)` budget in
[architecture §6](architecture.md). No per-frame work is introduced.

---

## 4. Mortality

Each step onto an **uncovered** `is_hazardous` tile triggers one mortality check
against the tile-type's configured probability (per-terrain env vars, §
[data-schemas §9](data-schemas.md)). Crossing via constructed infrastructure is
always zero-mortality.

```gdscript
## pathfinding.gd / species_manager.gd — runs as the animal enters a tile on the sim tick.
func on_enter_tile(animal: Animal, tile: Tile) -> void:
    if tile.is_covered_by_crossing:
        return                                  # zero mortality, guaranteed survival
    if tile.is_hazardous:
        var p := env_config.mortality_for(tile) # ROAD_/RIVER_HAZARD_MORTALITY, default 0.20
        if rng.randf() < p:
            animal.die()
            EventBus.animal_died.emit(animal.species_id, tile.coord, tile.id)
```

The check is **per step**, so a wider hazard is proportionally deadlier, and each
terrain type's rate is independent and independently settable (a test sets road
to 0.5 while river stays at its own rate — see [`test-plan`](test-plan.md)).

When an animal completes a crossing traversal (exits the far side of a chain),
`species_manager` emits `animal_crossed` once per animal per traversal; the
feedback layer coalesces these per crossing within
`CROSSING_FEEDBACK_COALESCE_SECONDS` into one cue with a "+N" counter.

---

## 5. Population model

Population health is tracked **per patch per species**: `count`, `trend`
(rising / stable / falling), and `connectivity_status`. The model advances on a
**monthly** boundary (every 30 in-game days), not per tick — the per-tick layer
only accumulates the month's crossing tallies and presence data.

Key rules:

- A patch **below** its species' `min_viable_patch_size` cannot sustain a
  population: its count drifts slowly downward until the patch is linked into a
  larger connected network (via a crossing or contiguous habitat), at which point
  the network's combined size — counting only tiles whose biome is in that
  species' habitat set ([ADR 0007](adr/0007-patch-derivation-biome-compatibility.md)) —
  is used for viability. This makes connectivity mechanical, not cosmetic.
- A patch newly connected to a healthy network **recovers**: counts rise toward
  the network's carrying capacity, range expands, and a `population_recovered`
  event fires at defined thresholds (e.g. count doubled, species returned to a
  patch it was absent from). Recovery events feed donations and trust.
- Seasonal absence (hibernation, migration) removes/returns animals but does
  **not** count as population decline.

### Sketch — monthly population step

```gdscript
## population_model.gd — invoked on each in-game month boundary.
func monthly_step() -> void:
    for patch in habitat_manager.patches():
        var network := connectivity_graph.network_of(patch)   # patch + safe-linked patches
        for species_id in patch.resident_species():
            var rec := patch.population(species_id)
            var species := SpeciesRegistry.get(species_id)
            if season_manager.is_absent(species, season_manager.current):
                continue                                       # migrated/hibernating: skip

            # Viability is species-relative: count only network tiles whose biome
            # is in this species' habitat set (resolved via biome_groups.json),
            # not the network's whole tile count ([ADR 0007]).
            var effective_size := network.habitat_tile_count(species)
            var viable := effective_size >= species.min_viable_patch_size
            # Capacity is per-patch (own habitat tiles × quality), gated by network
            # viability ([ADR 0011]).
            var capacity := _carrying_capacity(patch, network, species)

            if not viable:
                rec.count = max(0, rec.count - DECLINE_STEP)   # slow decline, never punitive
                rec.trend = Trend.FALLING
            elif rec.count == 0 and network.has_species_elsewhere(species_id, patch):
                rec.count = RE_ESTABLISH_SEED                  # immigration re-seeds a locally-extinct species
                rec.trend = Trend.RISING
                _check_recovery_milestones(patch, species_id, 0, rec.count)
            elif rec.count < capacity:
                var before := rec.count
                rec.count = min(capacity, rec.count + _recovery_rate(patch, network, species))
                rec.trend = Trend.RISING
                _check_recovery_milestones(patch, species_id, before, rec.count)
            else:
                rec.trend = Trend.STABLE

            rec.connectivity_status = network.connectivity_label()

    economy_manager.run_monthly_income()   # consumes this month's crossing tallies
```

`_check_recovery_milestones` emits `population_recovered` when a threshold is
crossed (count doubled, or a locally-extinct species re-establishes), which
`economy_manager`, `permissions_manager`, and `milestone_tracker` consume.
Decline is gentle (`DECLINE_STEP` small) so an unconnected patch is an
interesting problem, never a sudden loss — the cozy pillar.

### Residency, seeding, and animal rendering

The authoritative `count` above and the rendered `Animal` instances are **two
decoupled layers** ([ADR 0009](adr/0009-population-seeding-and-agent-rendering.md)):
`count` is the truth of what a patch sustains; agents are a bounded, representative
visualisation that also enacts the journeys the player watches.

- **Residency.** A species is resident in a patch iff the patch biome (ADR 0008
  `patch_biome`) is in that species' habitat set — the patch biome, or its
  `terrain_aliases` resolution, appears in `species.habitat_terrains` (ADR 0007).
  `patch.resident_species()` returns those species.
- **Initial seeding (habitat-derived).** At new-game load each resident species'
  count is `max(SEED_FLOOR_IF_HABITABLE, round(INITIAL_SEED_FRACTION *
  _potential_capacity(patch, species)))`. Seeding uses the **ungated** potential
  capacity ([ADR 0011](adr/0011-carrying-capacity-recovery-decline.md)) so a
  fragmented patch starts populated-but-declining rather than empty. No per-species
  counts are authored in `sub_areas.json`.
- **Cadence.** `count` changes only at the monthly step (decline/recovery) or on
  seasonal presence (§6). There is no per-tick or free spawning; immigration after
  a crossing is recovery, surfaced as a `population_recovered` "species returned"
  spawn.
- **Rendered pool.** `species_manager` renders agents only for the active sub-area:
  `rendered_agents = clamp(0, MAX_AGENTS_PER_VISIBLE_PATCH, ceil(count /
  AGENT_REPRESENTATION))` per species per visible patch. Off-screen patches render
  none but still advance demographically.
- **Death is observable, not demographic.** A rendered hazard death emits
  `animal_died` and feeds feedback/economy/trust and dramatises an unconnected
  patch's monthly decline, but does **not** mutate `count` — keeping the loop
  legible and reproducible from `(seed, tick_count)` (§7).

---

## 6. Seasonal modifiers

`season_manager` emits `season_changed` at each 15-minute boundary; consumers
apply modifiers:

- **Presence.** Hibernating species (grizzly) leave simulation in winter;
  migratory species (elk, pronghorn) appear in a patch only in their season;
  elevational migrators (caribou, bighorn, lynx-stable) shift range up/down.
  Encoded by `seasonal_pattern` (data-schemas §3).
- **Motivation.** During a species' migration season, its goal-selection bias
  toward distant patches increases, raising barrier-crossing attempts — so a
  crossing built *before* a migration season sees a usage spike. Implemented as a
  season-scaled multiplier on goal-distance willingness in goal selection.
- **Terrain shifts.** Winter freezes rivers (a frozen river tile temporarily
  clears `is_hazardous`, opening a free crossing option); spring floods widen
  river hazard zones by one tile. Terrain shifts re-derive the affected patches,
  so `season_changed` is the heaviest recompute event (architecture §6).

Because terrain can split or merge patches seasonally, `connectivity_graph`
re-derives patch identity for the active sub-area on `season_changed`; inactive
sub-areas recompute lazily on next view.

---

## 7. Determinism and tick rate

- **Fixed logical tick.** Simulation advances on `SIM_TICK_SECONDS` steps
  ([architecture §4](architecture.md)), decoupled from frame rate. Rendering
  interpolates between ticks. The same sequence of ticks always produces the same
  result regardless of FPS.
- **Seeded RNG.** All stochastic decisions (mortality checks, preference-weighted
  route choice, donation rounding) draw from a single seeded
  `RandomNumberGenerator` owned by the simulation and saved in `GameState`. A
  saved game resumes the same stream, and tests run with a fixed seed for
  reproducibility.
- **Per-tick probabilities.** Mortality and motivation are expressed per tick /
  per step, so changing `SIM_TICK_SECONDS` for performance does not change the
  *expected* outcome of a traversal (a longer hazard is more steps, hence
  proportionally deadlier) — tuning tick rate stays behaviourally neutral.
- **Deterministic system order.** The per-tick system order (architecture §4) is
  fixed so cause precedes effect identically every run.

> Decision logged: a single shared seeded RNG (not per-animal RNGs) is used so
> the entire simulation is reproducible from `(seed, tick_count)`. Tests inject a
> fixed seed; production seeds from the OS at new-game and persists the seed +
> stream position in the save.

---

## 8. Cross-references

- Tick model, signal names, performance budget: [`architecture`](architecture.md)
- Field definitions for species/tiles/infrastructure/env vars:
  [`data-schemas`](data-schemas.md)
- Tests for each algorithm here: [`test-plan`](test-plan.md)
- Topology, crossing-type, connectivity decisions:
  [ADR 0002](adr/0002-hex-grid-topology.md),
  [ADR 0003](adr/0003-crossing-tile-architecture.md),
  [ADR 0004](adr/0004-connectivity-patch-adjacency-graph.md)
