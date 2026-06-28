---
title: "0010 — Pre-Season Animal Goal Selection"
date: 2026-06-27
status: accepted
---

## Context

[`simulation-design` §2](../simulation-design.md) says an animal paths toward "a
habitat patch within range, biased by seasonal motivation" — but seasons are
Phase 4. In Phases 1–2 there is no motivation layer, so an idle animal has **no
defined goal**, and nothing specifies how often it re-paths, idles, or wanders, or
what makes it attempt a hazardous crossing rather than stay put. The Phase 1
success criterion — watch an animal die on the road, build a crossing, watch one
cross — depends entirely on that drive existing without seasons. Until it is
defined, `species_manager` and `pathfinding` cannot be wired and the core mechanic
is not observable. This is blocker **A4**.

The pieces it builds on already exist: the §2 edge cost model (uncovered hazard =
`base_cost × HAZARD_AVOIDANCE_MULT`, default 4.0; covered crossing = zero
mortality, discounted), A* with cube-distance heuristic and cached paths,
`species.range_tiles`, patch residency and habitat quality (ADRs 0007–0009).

## Decision

A **season-independent forage/wander drive**, layered on the existing cost model so
Phase 4 seasons only *scale a parameter* rather than introduce new behaviour.

### Goal selection

When an animal becomes idle (spawned, or having reached its previous goal and
dwelled for `IDLE_DWELL_TICKS`), it picks its next goal:

```
with probability WANDERLUST_PROB:           # travel to another patch
    candidates = compatible patches (biome ∈ species habitat set, ADR 0007/0009),
                 other than the current patch, within
                 range = species.range_tiles * MOTIVATION_DISTANCE_MULT  (hex distance)
    if candidates not empty:
        pick patch P with weight  w(P) = (quality(P) + GOAL_QUALITY_FLOOR) / (1 + dist(P))
        goal = the nearest tile of P             # drawn from the shared seeded RNG
    else:
        forage locally
otherwise:                                   # forage locally
    goal = a random compatible tile within FORAGE_RADIUS_TILES of the current tile
```

Selection is **quality- and distance-weighted and stochastic** (the A4 decision):
higher-quality, nearer patches are likelier, so crossing attempts arrive as a
lifelike trickle rather than all-or-nothing, and `GOAL_QUALITY_FLOOR` keeps even
poor patches reachable. All draws use the single shared seeded RNG
([`simulation-design` §7](../simulation-design.md)), so behaviour is reproducible.

### Re-path / idle / forage cadence

A path is recomputed when the animal picks a new goal, on `crossing_completed` and
`season_changed` for the sub-area (already specified in §2), and on a soft cadence
of `REPATH_INTERVAL_TICKS` so animals react to a newly built crossing without
waiting to finish a long route. On reaching a goal the animal dwells
`IDLE_DWELL_TICKS` (a forage beat) before selecting again.

### Hazard attempts are emergent, not flagged

Nothing marks an animal as "willing to cross." A* already prices an uncovered
hazard at `base_cost × HAZARD_AVOIDANCE_MULT` and routes around it **whenever a
safe detour exists**. An animal therefore attempts a hazard precisely when its
chosen goal has **no safe route** — the sole cause of unassisted death is
fragmentation, which is exactly the lesson the game teaches. The tutorial map is
authored so the road fully separates the two forest patches (no safe detour), so
the loop is guaranteed there: a west animal that selects the east patch must path
through the road and faces the mortality check; once the overpass covers the band,
the zero-mortality covered edge is the cheaper route and A* sends animals across
it.

### Seasons later scale one existing parameter

Phase 4 seasonal motivation multiplies `MOTIVATION_DISTANCE_MULT` (default 1.0),
raising willingness to target distant patches during migration — the
"season-scaled multiplier on goal-distance willingness" §6 already references. No
new goal machinery is introduced in Phase 4.

## Consequences

### Positive

- `species_manager` / `pathfinding` goal logic is fully specified; the Phase 1
  loop is observable end-to-end with no special-cased "suicide" behaviour.
- Death has exactly one cause — no safe route to a wanted patch — so the mechanic
  is legible and the educational message is clean.
- Forward-compatible with seasons: Phase 4 scales `MOTIVATION_DISTANCE_MULT` only.
- Reproducible: every stochastic choice draws from the shared seeded RNG.

### Negative / Trade-offs

- On a map with any safe detour, animals will not die there; observable mortality
  depends on authored fragmentation (accepted — it is the design intent, and the
  tutorial map guarantees it).
- Stochastic, quality-weighted selection is less trivially predictable than
  nearest-only; tests pin the RNG seed to assert exact choices.

### Neutral / Follow-on work

- New constants `WANDERLUST_PROB`, `GOAL_QUALITY_FLOOR`, `REPATH_INTERVAL_TICKS`,
  `IDLE_DWELL_TICKS`, `FORAGE_RADIUS_TILES`, `MOTIVATION_DISTANCE_MULT` are added to
  `simulation_constants.gd` ([`data-schemas` §10](../data-schemas.md)).
- A GUT test asserts the emergent loop on the Bow Valley fixture: a west→east goal
  routes through the road (mortality > 0) before the crossing and through the
  zero-mortality chain at lower cost after.
- `_carrying_capacity`, `_recovery_rate`, `DECLINE_STEP` (A5) remain the open
  numeric piece; goal selection is independent of them.
