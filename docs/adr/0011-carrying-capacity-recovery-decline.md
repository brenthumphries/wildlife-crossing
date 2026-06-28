---
title: "0011 — Carrying Capacity, Recovery, and Decline"
date: 2026-06-27
status: accepted
---

## Context

The monthly population step ([`simulation-design` §5](../simulation-design.md))
calls `_carrying_capacity(network, species)`, `_recovery_rate(network, species)`,
and `DECLINE_STEP`, but none has a formula or value — and `DECLINE_STEP` is in no
constants table. The seeding rule from [ADR 0009](0009-population-seeding-and-agent-rendering.md)
also depends on a capacity value. Until these exist, `population_model` and
`population_model_test` cannot be written. This is blocker **A5**. Everything it
reads is now settled: network size and viability ([ADR 0007](0007-patch-derivation-biome-compatibility.md))
and habitat quality ([ADR 0008](0008-habitat-quality-subformulae.md)).

A subtlety drives the design: capacity serves two jobs that must not be conflated.
The **monthly sustaining ceiling** must be gated by viability (a sub-viable network
sustains nothing). The **seeding/occupancy** value (ADR 0009) must be *ungated*, or
a fragmented tutorial patch seeds to ~0 and there are no animals to watch decline
and die — fragmentation means animals are present but unsustainable, not absent.

## Decision

One base capacity formula, used ungated for seeding and viability-gated for the
monthly ceiling. Capacity is **per patch** (so patches sharing a network do not
each recover to the whole-network total and over-count). All thresholds are named
constants in `simulation_constants.gd` ([`data-schemas` §10](../data-schemas.md)).

### Capacity (size × quality)

```
qnorm   = clamp(QUALITY_CAPACITY_FLOOR_FRAC, 1.0, habitat_quality(patch) / 100)
base    = round(CAPACITY_PER_HABITAT_TILE * patch.habitat_tile_count(species) * qnorm)

_potential_capacity(patch, species)         = base                 # ungated — ADR 0009 seeding
_carrying_capacity(patch, network, species) = base if viable else 0  # monthly ceiling
```

`patch.habitat_tile_count(species)` counts this patch's tiles whose biome is in the
species' habitat set; `viable` is the network gate from ADR 0007
(`network.habitat_tile_count(species) >= species.min_viable_patch_size`). This is
the PRD's "function of network tile count and `min_viable_patch_size`": min-viable
is the gate, habitat size sets the magnitude, and quality (A6) scales the ceiling —
so a crossing pays off twice (more reconnection *and* a higher cap). Defaults:
`CAPACITY_PER_HABITAT_TILE = 0.5`, `QUALITY_CAPACITY_FLOOR_FRAC = 0.5`.

### Recovery (proportional approach)

When viable and below capacity, close a fraction of the gap per month, with a floor
so re-establishment is not glacial:

```
_recovery_rate(patch, network, species) = max(RECOVERY_MIN_STEP,
                                              round(RECOVERY_APPROACH_FRAC * (capacity - count)))
```

Defaults `RECOVERY_APPROACH_FRAC = 0.2`, `RECOVERY_MIN_STEP = 1`. Fast when far
below capacity, naturally decelerating as it fills — a satisfying rebound after a
crossing without overshoot.

### Decline (fixed and gentle)

Below viability, `count = max(0, count - DECLINE_STEP)`, `DECLINE_STEP = 2` per
month. A patch of ~18 empties over ~9 months — an interesting problem, never a
sudden loss (the cozy pillar).

### Re-establishment from zero

In the monthly step, if a patch's `count == 0`, the network is viable, **and** the
species is present elsewhere in the connected network, immigration seeds
`count = RE_ESTABLISH_SEED` (default 2) and fires `population_recovered` with a
`returned` reason. This is what re-seeds a locally-extinct species: a crossing
connecting it to a source.

### `population_recovered` thresholds

- **returned** — `count` crosses `0 → >0` (re-establishment above);
- **doubled** — `count` reaches ≥ 2× the baseline recorded at the last milestone
  (baseline reset on each fire);
- **saturated** — `count` first reaches `_carrying_capacity` (fully recovered).

These feed `economy_manager` (donations) and `permissions_manager` (trust).

## Consequences

### Positive

- `population_model` and `population_model_test` are fully specified; the whole
  Phase 1 demographic loop is now numeric.
- The cozy loop is realised end-to-end. Worked example on the Bow Valley fixture
  (grizzly): seeded at 18 per side; while fragmented, gentle decline (18→6 over six
  months, capacity 0); after the overpass the network is viable and quality rises
  Fair→Good, capacity 32/30 appears, recovery decelerates toward it
  (6→11→15→…→31), and a deliberately-extinct east patch re-establishes 0→2 then
  recovers. Counts stay within `[0, capacity]` throughout.
- Capacity rewards quality and connectivity, reinforcing the crossing mechanic.

### Negative / Trade-offs

- Tying capacity to habitat quality couples `population_model` to `habitat_manager`
  recompute ordering: the monthly step must read post-recompute quality. Acceptable
  — both run on the same monthly/event cadence.
- Proportional recovery needs two constants (`APPROACH_FRAC`, `MIN_STEP`) versus a
  single linear step; the floor prevents the long thin tail near capacity.

### Neutral / Follow-on work

- New constants added to `simulation_constants.gd`: `CAPACITY_PER_HABITAT_TILE`,
  `QUALITY_CAPACITY_FLOOR_FRAC`, `RECOVERY_APPROACH_FRAC`, `RECOVERY_MIN_STEP`,
  `DECLINE_STEP`, `RE_ESTABLISH_SEED`.
- ADR 0009 seeding now reads `_potential_capacity` (ungated); `simulation-design`
  §5 and the ADR 0009 wording are updated to match.
- All values are first-pass and balanced in Phase 1 against the authored maps;
  with A5 settled, the A1–A6 simulation chain is fully specified.
