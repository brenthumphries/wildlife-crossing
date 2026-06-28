---
title: "0014 — GameState Serialization Shape"
date: 2026-06-28
status: accepted
---

## Context

[ADR 0005](0005-save-file-format.md) chose **versioned JSON**, reference-by-`id`,
atomic writes — but explicitly deferred "the exact `GameState` JSON shape" to "be
defined alongside the data schemas," and [`data-schemas`](../data-schemas.md) does
not yet contain it. This is blocker **A10**: `save_manager`'s round-trip and
`save_manager_test` need a fixed contract, and even though full save/load is Phase
4, every system that writes into `GameState` from Phase 1 onward should serialize
into a **stable shape** from the start rather than being retrofitted later.

[`architecture` §7](../architecture.md) already enumerates *what* is saved (budget,
day/season/year, time speed, per-patch population records, per-entity trust,
purchased-information flags, built crossings, milestone progress, partnerships) and
fixes two rules: nothing static from `data/` is duplicated (reference by stable
`id`), and derived state — the connectivity graph — is **rebuilt on load from saved
crossings, not stored**. This ADR turns that list into a concrete shape.

## Decision

`GameState` serializes to a single JSON object with a top-level `save_version`
integer (the migration-chain key, [ADR 0005](0005-save-file-format.md)) and the
shape below. It is added to `data-schemas` as **§14**. The save stores **only
mutable runtime state**; all references into static `data/` are by stable `id`.
Derived state (connectivity graph, habitat-quality scores, patch derivation) is
**not** serialized — it is recomputed on `game_loaded`.

```json
{
  "save_version": 1,
  "meta": {
    "active_sub_area_id": 7,
    "saved_at_unix": 1750000000,
    "playtime_seconds": 12840
  },
  "clock": { "year": 1, "season": "summer", "day_of_season": 34, "time_speed": 1 },
  "economy": { "budget": 45000, "last_donation": 1200 },
  "patches": [
    { "patch_id": "7:forest:w", "sub_area_id": 7, "species": [
        { "species_id": "grizzly_bear", "count": 18, "trend": "declining",
          "connectivity_status": "sub_viable" }
    ] }
  ],
  "entities": [
    { "entity_id": "parks_canada", "trust": 42, "stage": "cooperative",
      "partnership": false }
  ],
  "information": {
    "areas_revealed": ["7"],
    "entities_revealed": ["parks_canada"]
  },
  "crossings": [
    { "crossing_id": "c1", "segment_id": "7:seg:14", "sub_area_id": 7,
      "crossing_type": "overpass", "covered_tiles": [[3,1],[4,1]],
      "built_on_day": 120 }
  ],
  "milestones": {
    "reached": ["first_crossing", "bow_valley_reconnected"],
    "capstone_reached": false
  }
}
```

Shape rules:

- **`save_version`** is the only field `save_manager`'s migration chain switches on;
  a format change bumps it (and the project **MAJOR** version) and adds a migration
  step.
- **Reference-by-id everywhere:** `species_id`, `entity_id`, `sub_area_id`,
  `segment_id`, `crossing_type` are stable ids into `data/`; no static fields
  (names, costs, stats) are copied in.
- **Enumerated strings** (`season`, `trend`, `connectivity_status`, `stage`) use the
  exact tokens already defined in `data-schemas`/the population & permissions
  models, so load needs no remapping.
- **`patch_id`** is the deterministic patch key (sub-area + patch-biome + locator)
  produced by patch derivation ([ADR 0007](0007-patch-derivation-biome-compatibility.md));
  because derivation is deterministic from the static map, a saved `patch_id`
  re-resolves to the same patch on load.
- **Omit-means-default:** absent optional keys take system defaults on load
  (forward-compatible reads within a `save_version`).
- **Not stored (rebuilt on load):** connectivity graph, habitat-quality scores,
  rendered agent pool, current per-month crossing tallies — all derived from the
  static map + `crossings` + `patches` when `game_loaded` fires.

## Consequences

### Positive

- `save_manager` and `save_manager_test` have a concrete round-trip contract;
  Phase-1 systems can serialize into the final shape immediately, so no migration is
  needed just to reach the stable layout.
- Keeping derived state out of the save makes load robust to rebalanced constants
  and formula changes (ADRs 0008/0011): a save reflects *state*, not *derived
  numbers*, which are recomputed.
- Human-readable and diffable, preserving ADR 0005's debugging benefit.

### Negative / Trade-offs

- The save depends on patch-derivation determinism: if the static map for a
  sub-area changes between versions, saved `patch_id`s may not resolve — handled
  the same way as any id removal, via a migration step (ADR 0005's noted risk).
- A few redundant-looking fields (`sub_area_id` on both patches and crossings) are
  kept for load-time locality rather than normalized away; the size cost is trivial
  at this state scale.

### Neutral / Follow-on work

- Added to `data-schemas` as **§14 (GameState save schema)**; the §11 validation
  checklist gains a save round-trip row when `save_manager` is implemented.
- `game_loaded` (architecture §7) is the single rebuild trigger; the list of
  derived state to rebuild is recorded above.
- `save_version` starts at **1**; the migration chain is empty until the first
  format change.
