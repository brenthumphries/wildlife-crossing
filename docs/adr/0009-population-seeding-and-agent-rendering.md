---
title: "0009 — Population Seeding and Agent Rendering"
date: 2026-06-27
status: accepted
---

## Context

The design set carries two population layers that are never connected:

- **Authoritative demographics** — `population_model` tracks an integer `count`
  per patch per species, advanced on a **monthly** step (decline when sub-viable,
  recovery when connected) ([`simulation-design` §5](../simulation-design.md),
  [ADR 0007](0007-patch-derivation-biome-compatibility.md)).
- **Rendered agents** — `Animal` instances path on the movement graph, run
  per-step mortality checks, and emit `animal_died` / `animal_crossed`
  ([`simulation-design` §2, §4](../simulation-design.md)).

Nothing specifies how many animals exist at game start or where, what causes new
ones to appear, or whether a rendered `Animal` *is* one unit of `count` or merely
represents it. Without this, `species_manager` cannot be built and the Phase 1
exit criterion — animals must route and die, then cross after a crossing — has no
mechanism. This is blocker **A3**. A binding constraint: the simulation is
deterministic from `(seed, tick_count)` with a single shared RNG
([`simulation-design` §7](../simulation-design.md)), so the design must not make
demographics depend on per-agent event bookkeeping.

## Decision

**Decouple authoritative demographics (`count`) from rendered agents.** They
answer different questions: `count` is the truth of how many animals a patch
sustains; agents are a bounded, representative visualisation that also enacts the
observable journeys the player watches.

### Resident species of a patch

A species is **resident** in a patch iff the patch's biome (ADR 0008
`patch_biome`) is in that species' habitat set — i.e. the patch biome, or a
`terrain_aliases` resolution of it, appears in `species.habitat_terrains` (ADR
0007). `patch.resident_species()` returns those species; seasonal absence
(hibernation/migration) hides them for a season without removing residency.

### Initial population — habitat-derived

At new-game load, for each patch and each resident species, the authoritative
count is seeded from the habitat, not hand-authored:

```
count0 = max(SEED_FLOOR_IF_HABITABLE, round(INITIAL_SEED_FRACTION * potential_capacity(patch, species)))
```

Seeding uses the **ungated** `_potential_capacity` defined by **A5**
([ADR 0011](0011-carrying-capacity-recovery-decline.md)) — capacity *before* the
viability gate — so a fragmented (sub-viable) patch starts populated-but-declining
rather than empty, which is what gives the player animals to watch die and then
rescue. Seeding is derived, so `sub_areas.json` carries no per-species count tables.
The `SEED_FLOOR_IF_HABITABLE` of 1 guarantees animals are present even in patches
whose potential capacity rounds low.

### Cadence — demographics change only monthly or seasonally

There is **no free or per-tick spawning.** `count` changes in exactly two places:

- the **monthly step** — gentle decline below viability, recovery toward capacity
  when connected (§5);
- **seasonal presence** — `seasonal_pattern` removes/returns a species for a
  season (§6); this is not decline.

"A new animal appears in a patch it had been absent from" is the existing
`population_recovered` event firing after a crossing links the network —
immigration is modelled as recovery, then dramatised by spawning agents.

### Rendered agents — a capped representative pool

`species_manager` renders agents only for the **active/visible sub-area**. Per
species per visible patch it shows:

```
rendered_agents = clamp(0, MAX_AGENTS_PER_VISIBLE_PATCH, ceil(count / AGENT_REPRESENTATION))
```

so a larger `count` shows more animals up to a hard cap (the perf bound), and a
patch with `count == 0` shows none. Off-screen patches render zero agents yet
still advance demographically each month. Agents are spawned/despawned to track
`count`, seasonal presence, and view changes; their goals come from the
movement/goal layer (§2, and **A4**).

### Rendered death is observable, not demographic

When a rendered agent dies on a hazard, it emits `animal_died` and feeds feedback,
economy, and trust — and it **dramatises** the monthly model's decline of an
unconnected patch — but it does **not** mutate `count`. Authoritative demographics
remain the monthly model's alone. This keeps the loop legible and reproducible:
the crossing both stops the visible deaths (a zero-mortality route) and flips the
patch's monthly trend from decline to recovery.

## Consequences

### Positive

- `species_manager` is now specified: seed, render a capped pool, spawn/despawn on
  count/season/view, emit events on traversal and death.
- The Phase 1 loop is mechanised end-to-end without per-agent demographic
  bookkeeping, so determinism from `(seed, tick_count)` is preserved.
- Perf is bounded by `MAX_AGENTS_PER_VISIBLE_PATCH` and active-sub-area-only
  rendering, independent of population magnitude.
- `sub_areas.json` stays lean; the opening board follows from the habitat model,
  so it can never silently contradict viability.

### Negative / Trade-offs

- A watched road-death does not tick the number down in that instant; the
  demographic consequence surfaces at the monthly boundary. Accepted as the
  cozy/non-punitive reading of the core loop.
- Seeding depends on A5's `carrying_capacity`; until A5 lands, seeding runs
  against the stubbed capacity and the magnitudes are provisional.

### Neutral / Follow-on work

- New constants `MAX_AGENTS_PER_VISIBLE_PATCH`, `AGENT_REPRESENTATION`,
  `INITIAL_SEED_FRACTION` (and `SEED_FLOOR_IF_HABITABLE`) are added to
  `simulation_constants.gd` ([`data-schemas` §10](../data-schemas.md)).
- **A4** still owns *how* an agent picks a goal and decides to attempt a hazard;
  this ADR only governs how many agents exist and persist.
- A later phase may add a bounded road-mortality term to the monthly step if
  playtests want watched deaths to nudge demographics; deliberately out of scope
  for Phase 1.
