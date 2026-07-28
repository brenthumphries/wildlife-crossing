---
title: "Defect — Overpass covers the whole segment instead of spanning it"
date: 2026-07-19
tags: [design, system, infrastructure, decision]
status: active
---

> Found during the first hands-on play session on macOS (2026-07-19). The
> player pressed **B** in the Bow Valley tutorial and the entire highway turned
> into crossing tiles. Expected: a narrow structure over the road, with the road
> still visible underneath.

## Summary

`InfrastructureManager.build_full()` covers **every dangerous tile in a
segment**. For the tutorial segment `s7_trans_canada_bow_a` that is all 20 road
tiles — the full ten-tile length of the highway, not a crossing over it. The
road stops existing rather than being bridged.

This is a **defect, not a design disagreement**. The code contradicts the PRD.

## Evidence

### 1. The PRD consistently says *width*

[[wildlife-overpass-crossing]] describes the span across the hazard, never along
it:

- Proposed solution: "tiled continuously across the full **width** of the
  dangerous terrain"
- Rule 2: "a three-tile-**wide** river requires three overpass tiles"
- Superseded no-cost note: "a three-tile road **span** costs 15,000"

A three-tile span is a structure roughly three tiles across. Nothing in the PRD
describes paving a corridor end to end.

### 2. The segment data is a corridor, not a cross-section

`game/data/segments.json` → `s7_trans_canada_bow_a`:

- `tiles`: q ∈ {12, 13} × r ∈ {0…9} — **2 wide × 10 long = 20 tiles**
- `surround_tiles`: (11,0), (11,9), (14,0), (14,9) — the flanking patches on
  either side, at q = 11 and q = 14
- `hazard_type`: `road`

The segment describes *the whole stretch of highway that is a candidate
crossing site*. It is not a description of one structure.

### 3. The cost arithmetic is decisive

`infrastructure.json` sets `cost_per_tile: 5000` for `overpass`. Starting budget
is 50,000 ([[game-design-overview]] economy section — spec only; `GameState.budget`
is still `0` until the Phase 3 economy is wired).

| | Tiles covered | Cost | vs. starting budget |
|---|---|---|---|
| Current behaviour | 20 | **100,000** | 200% |
| PRD intent (span the width) | 2 | 10,000 | 20% |

The current implementation makes the **tutorial** crossing cost twice the entire
starting budget. When the Phase 3 economy lands, Phase 1 becomes unplayable.
This is strong corroboration that a span was always meant to be a handful of
tiles.

## Root cause

**The code conflates the segment with the span.** These are different things and
the codebase currently has only one word for both:

| Concept | What it is | Size (Bow Valley) | Unit of |
|---|---|---|---|
| **Segment** | The whole hazardous corridor | 20 tiles | *Selection* — what you pick on the world map |
| **Span** | The structure across the corridor's width at one point | 2 tiles | *Construction* — what you build and pay for |

`InfrastructureManager.try_complete()` requires every tile returned by
`_dangerous_tiles(seg)` to be covered — i.e. the whole segment. It should
instead require an unbroken chain of crossing tiles **across** the corridor,
connecting the patch on one side to the patch on the other.

The ambiguity originates in the wording of PRD rule 2 — "span every cell of
dangerous terrain" — which reads correctly if "dangerous terrain" means *the
width being crossed*, and incorrectly if it means *the segment*. The
implementation took the second reading. [[../../docs/adr/0003-crossing-tile-architecture|ADR 0003]]
repeats the same phrase and so propagated it.

## Decision — player picks the span location

Confirmed by the product owner, 2026-07-19.

The player chooses **where along the corridor** the span goes. Rejected
alternatives:

- *Auto-place at the highest-connectivity point.* Ships fastest and the
  connectivity graph could already score it, but placement stops being a player
  decision — this is the central verb of the game.
- *Author a fixed location per segment in data.* Most ecologically faithful and
  cheapest to build, but 19 segments need hand-authoring and the player has no
  agency.

Player-chosen placement matches the PRD's existing "selects an overpass tile
from the build palette and places it over a dangerous tile" language, and fits
the Cities-Skylines-like feel in the project north star.

## Scope of the fix

Three files. Pathfinding, the connectivity graph, and the data schema are
untouched.

- **`game/scripts/systems/infrastructure_manager.gd`** — the real change.
  `try_complete()` validates a chain across the corridor rather than total
  segment coverage. `place()`, `_chain_connected()`, and
  `_link_bordering_patches()` all survive as-is; `_chain_connected()` is already
  the exact primitive needed.
- **`game/scripts/systems/simulation.gd`** — `build_crossing()` is a one-line
  passthrough; it needs to take a span location.
- **`game/tests/infrastructure_manager_test.gd`** — assertions currently encode
  the whole-segment behaviour and will need rewriting.

`build_full()` should be retained but renamed and re-scoped to "cover this span
and complete it" rather than "cover this whole segment".

## Open questions

1. ~~**How is span width determined?**~~ **Resolved 2026-07-19 →
   [[../../docs/adr/0016-crossing-span-geometry|ADR 0016]].** "Width" was the
   wrong frame — it presumes an axis the diagonal river segments do not have. A
   span is defined topologically instead: a connected, single-type set of hazard
   tiles containing a subset whose *safe ring* falls into two or more components.
   Shape-agnostic. Bow Valley resolves to 2 tiles (10,000), Snake River to 1
   (5,000).
2. ~~**Does `surround_tiles` need extending?**~~ **No** — ADR 0016 derives the
   sides from the candidate's own neighbourhood, so `surround_tiles` is no longer
   load-bearing for validation and stays as authored metadata.
3. **Minimum/maximum span length?** Partly resolved: a span too small to reach
   the far side is rejected by the ADR 0016 predicate, and an over-wide span is
   *valid but priced per tile* rather than refused. What remains is UI — the
   rejection needs a legible message, and running cost should be visible during
   placement so the bill is never a surprise.
4. **UI.** Player-chosen placement needs a build mode with a ghost preview.
   That is Phase 2/3 UI work and is not yet specced.
5. **Will animals actually use the crossing?** New, and larger than the rest —
   17 of 19 corridors do not separate their map, so an animal may walk around
   rather than cross. Tracked at [[detour-cost-question]].

## Related

- [[../../docs/adr/0016-crossing-span-geometry|ADR 0016]] — the span definition
  this memo asked for
- [[detour-cost-question]] — the open follow-on it surfaced
- [[wildlife-overpass-crossing]] — rule 2, amended 2026-07-19
- [[../../docs/adr/0003-crossing-tile-architecture|ADR 0003]] — amended 2026-07-19
- [[crossing-location-selection]] — the segment *selection* flow, unaffected
