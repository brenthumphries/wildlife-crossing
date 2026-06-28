---
title: "0008 — Habitat-Quality Sub-Formulae"
date: 2026-06-27
status: accepted
---

## Context

The habitat-quality score is a 0–100 value with four terms and a flat partnership
bonus ([`game-design-overview`](../../obsidian-vault/prd/game-design-overview.md)):

```
quality = clamp(0, 100, terrain_base + size_factor + connectivity_bonus
                        + PARTNERSHIP_QUALITY_BONUS(if co-stewarded) − edge_penalty)
```

`habitat_constants.gd` ([`data-schemas` §10](../data-schemas.md)) gives only the
**caps** — `TERRAIN_BASE_MAX 40`, `SIZE_FACTOR_MAX 30`, `CONNECTIVITY_BONUS_MAX
20`, `EDGE_PENALTY_MAX 25` — and the band bounds (`BAND_POOR_MAX 25`,
`BAND_FAIR_MAX 50`, `BAND_GOOD_MAX 75`). No term has an actual expression, so
`habitat_manager` and its tests `test_quality_formula_clamped_0_100` and
`test_four_bands_mapping` ([`test-plan` §4](../test-plan.md)) cannot be written.
This is blocker **A6**.

[ADR 0007](0007-patch-derivation-biome-compatibility.md) supplied the
prerequisite: a patch is now a deterministic, biome-grouped set of tiles with a
well-defined biome and a set of safe links — exactly what these formulae read.

## Decision

Specify each term as follows. All thresholds are named constants in
`habitat_constants.gd` (new ones added in [`data-schemas` §10](../data-schemas.md));
no magic numbers. `terrain_base`, `size_factor`, and `edge_penalty` depend only on
the patch's own tiles, so they have no inter-patch dependencies;
`connectivity_bonus` reads neighbours' `size_factor` only (which is itself
link-independent), so there is no circular dependency.

### `patch_biome`

The patch's biome is the **most frequent tile biome** among its tiles (ties broken
by the biome's order in `biome_groups.json`). All the patch's tiles belong to one
compatible-biome group (ADR 0007), so this is well-defined.

### `terrain_base` ∈ [0, 40]

Mean suitability of the patch's tiles for `patch_biome`, read from each tile's
`terrain_suitability` map ([`data-schemas` §2](../data-schemas.md)):

```
terrain_base = clamp(0, TERRAIN_BASE_MAX,
                     mean over patch tiles t of t.terrain_suitability.get(patch_biome, 0))
```

Suitability values are already authored on the 0–40 scale, so the clamp is a
safety net.

### `size_factor` ∈ [0, 30]

Log-scaled in the **patch's own tile count** `n` (per the A6 decision: keeps the
term orthogonal to `connectivity_bonus`), between two tunable biome-agnostic
references:

```
if n <= SIZE_FACTOR_MIN_TILES:   size_factor = 0
elif n >= SIZE_FACTOR_FULL_TILES: size_factor = SIZE_FACTOR_MAX
else: size_factor = SIZE_FACTOR_MAX * (ln(n) - ln(SIZE_FACTOR_MIN_TILES))
                                    / (ln(SIZE_FACTOR_FULL_TILES) - ln(SIZE_FACTOR_MIN_TILES))
```

Defaults: `SIZE_FACTOR_MIN_TILES = 50`, `SIZE_FACTOR_FULL_TILES = 500`. The log
base is irrelevant (it cancels in the ratio).

### `connectivity_bonus` ∈ [0, 20]

Sum over the patch's safe links (contiguity or completed crossing, per ADR 0007)
of a base weight plus a quality term scaled by the linked patch's size — "count
**and** quality":

```
for each safe link L to neighbour patch P:
    neighbour_size_norm = size_factor(P) / SIZE_FACTOR_MAX        # ∈ [0, 1]
    w_L = CONNECTIVITY_LINK_BASE + CONNECTIVITY_LINK_QUALITY * neighbour_size_norm
connectivity_bonus = clamp(0, CONNECTIVITY_BONUS_MAX, Σ w_L)
```

Defaults: `CONNECTIVITY_LINK_BASE = 4`, `CONNECTIVITY_LINK_QUALITY = 4` (each link
worth 4–8; saturates at the cap after ~3–5 links). Monotonic in link count, so a
completed crossing always raises the score — satisfying
`test_quality_recompute_on_crossing`.

### `edge_penalty` ∈ [0, 25]

Linear in the fraction of the patch's perimeter that is hostile. Using
`HEX_EDGES_PER_TILE = 6`:

```
perimeter = Σ over patch tiles t of (HEX_EDGES_PER_TILE − same_patch_neighbours(t))
hostile   = number of those exposed edges whose neighbour tile is is_hazardous or is_impassable
edge_penalty = (perimeter == 0) ? 0 : EDGE_PENALTY_MAX * (hostile / perimeter)
```

### Partnership bonus and bands

`PARTNERSHIP_QUALITY_BONUS = 8` is added (pre-clamp) on co-stewarded patches after
`partnership_formed`. The final score maps to bands by the existing constants:
`Poor [0, 25]`, `Fair (25, 50]`, `Good (50, 75]`, `Excellent (75, 100]`.

## Consequences

### Positive

- `habitat_manager`, `test_quality_formula_clamped_0_100`, and
  `test_four_bands_mapping` are now fully specified and codeable.
- The four terms are orthogonal: building a crossing raises quality through
  `connectivity_bonus` alone, giving a clean, testable cause-and-effect.
- Everything is data/constant-tunable; difficulty and feel are balanced in Phase 1
  by editing constants, not code.
- Worked example on the Bow Valley fixture
  (`game/tests/fixtures/bow_valley_slice.json`): the 120-tile west forest patch
  scores **Fair** in isolation and rises a band when a crossing adds a safe link —
  exercised as a regression test.

### Negative / Trade-offs

- `connectivity_bonus`'s quality term reads neighbours' `size_factor`, so quality
  recompute must process a patch and its direct neighbours together; bounded by
  the ADR 0004 per-event budget (O(patches + links)).
- The size references are biome-agnostic first-pass defaults; a biome with
  naturally small patches may need per-group references later (a follow-on, not a
  blocker).

### Neutral / Follow-on work

- New constants (`SIZE_FACTOR_MIN_TILES`, `SIZE_FACTOR_FULL_TILES`,
  `CONNECTIVITY_LINK_BASE`, `CONNECTIVITY_LINK_QUALITY`) are added to
  `habitat_constants.gd` (§10).
- A5 (carrying capacity, recovery rate, `DECLINE_STEP`) remains open; it is
  independent of these quality formulae.
