---
title: "0016 — Crossing Span Geometry"
date: 2026-07-19
status: accepted
---

## Context

[ADR 0003](0003-crossing-tile-architecture.md) made span completeness a property
of the *segment*: a route opened only when every dangerous cell in the segment
was covered. `infrastructure_manager.gd` implemented that literally, so building
the Bow Valley tutorial crossing paved all 20 tiles of the Trans-Canada corridor
— the highway ceased to exist rather than being bridged, at a cost of 100,000
against a 50,000 starting budget. Found in play testing 2026-07-19; see
[[../../obsidian-vault/design/segment-vs-span-defect|the defect memo]] for the
full evidence.

The fix requires defining what a span *is*. The PRD says "the full **width** of
the dangerous terrain", which is unambiguous only for corridors that have a
width. The authored data does not cooperate:

- `s7_trans_canada_bow_a` — a road, 2 tiles across × 10 along. Rectangular.
- `s1_snake_river_a` — a river, 8 tiles in a diagonal stair:
  (12,7), (13,5), (13,6), (14,3), (14,4), (15,1), (15,2), (16,0). No axis.

Any rule phrased as "take the tiles in a row" works on both by accident of
authoring and breaks on the first corridor that bends, forks, or runs east–west.
A definition is needed that makes no assumption about corridor shape.

Options considered:

1. **Axis-aligned width** — pick the corridor's long axis, span the short one.
   Requires every corridor to have a principal axis; the braided rivers do not.
2. **Author each span location in data** — add a fixed span to every segment
   record. Precise, but removes player agency (rejected in the defect memo) and
   requires hand-authoring 19 segments.
3. **Topological: a span is what connects the two sides.** Derive validity from
   what the structure achieves rather than from its shape.

## Decision

Adopt the **topological definition (option 3)**, evaluated on the candidate's
*local* neighbourhood.

A set `S` of covered tiles is a **valid span** of segment `G` when:

1. `S ⊆ dangerous_tiles(G)` — you may only build on the hazard.
2. All tiles in `S` carry the same `crossing_type` (unchanged from ADR 0003).
3. `S` contains a **two-sided core**: some connected subset `C ⊆ S` for which
   the *safe ring* falls into two or more connected components. The safe ring of
   `C` is every in-world neighbour of `C` that is neither in `C` nor a dangerous
   tile of `G`.

Cost is `|S| × cost_per_tile` — the whole covered set, not just the core.

### Why the ring is computed locally

Asking "which regions does this corridor separate?" globally gives the wrong
answer. Only 2 of the 19 authored segments actually cut their map in two; the
rest stop short of the map edge, so their two sides are technically one region
reachable around the end. Restricting the test to the candidate's own ring
sidesteps this entirely — the corridor tiles flanking `C` pinch its ring into two
arcs, which is exactly the local "there is a side here and a side there" that a
crossing structure addresses.

### Why "contains a two-sided core" rather than "is two-sided"

Testing `S` itself is not monotone: as `S` grows its ring grows too, and
eventually wraps around the corridor's ends and reconnects. Covering the entire
Snake River tests as *one*-sided and would be rejected, while covering the entire
Bow Valley road tests as two-sided and would be accepted — the same player action
judged oppositely on two segments. Requiring only that a valid core exist
*somewhere inside* `S` restores monotonicity: adding tiles never invalidates a
span.

### Over-wide spans are priced, not policed

A player who covers more than the minimum builds a valid crossing and pays for
every tile. Rejecting over-wide spans would mean an error message for a
harmless act, which cuts against the "cozy, not stressful" north star. The bill
teaches the economy; the validator only enforces that the thing actually crosses.

*(This rule was the builder's recommendation, adopted by the product owner
2026-07-19. It is the one part of this ADR that is a preference rather than a
consequence of the geometry.)*

### Verified behaviour

| Segment | Candidate | Result | Cost |
|---|---|---|---|
| Bow Valley | full width at r=5 — {(12,5),(13,5)} | **valid** (core 2) | 10,000 |
| Bow Valley | half width — {(12,5)} | **invalid** | — |
| Bow Valley | 3 tiles *along* the road | **invalid** | — |
| Bow Valley | the whole 20-tile corridor | valid (core 2) | 100,000 |
| Snake River | single tile {(15,1)} | **valid** (core 1) | 5,000 |
| Snake River | single tile at the river tip {(16,0)} | valid (core 1) | 5,000 |
| Snake River | the whole 8-tile river | valid (core 1) | 40,000 |

The two rejections are the ones that matter: a half-width span does not reach
the far side, and tiles laid *along* a corridor never cross it however many you
place. Both fall out of the definition without special-casing.

Minimum spans land at 1–2 tiles (5,000–10,000), consistent with the PRD's worked
example of a three-tile span at 15,000 and affordable against the 50,000
starting budget.

## Consequences

### Positive

- Shape-agnostic. Rectangular roads, diagonal rivers, and any future bent or
  forked corridor are handled by one rule with no per-segment authoring.
- Reuses existing primitives: `_chain_connected()` already tests connectivity and
  `HexGrid.neighbors()` gives the ring. This is one new predicate, not a new
  system.
- `segments.json` needs no schema change. `surround_tiles` stays as authored
  metadata and is no longer load-bearing for validation.
- Player agency in placement is preserved, per the defect memo's decision.

### Negative / Trade-offs

- "Contains a two-sided core" is a subset search rather than a single test. Naive
  enumeration is exponential, so the implementation must bound it — corridors are
  ≤ 20 tiles and real spans are 1–4, so a search capped at small core sizes is
  sufficient. **The cap is an implementation constant and must be documented
  where it is set.**
- The local ring test is a heuristic for "there are two sides here". It is
  correct on all 19 authored segments but is not a proof for arbitrary
  topologies — a corridor that loops back on itself could produce ring components
  that are not meaningfully opposite sides. No such corridor exists today; revisit
  if one is authored.
- A player may build a valid but absurdly expensive span (the whole corridor at
  100,000). This is deliberate — see "priced, not policed" — but it means the UI
  should surface running cost during placement so the bill is never a surprise.

### Neutral / Follow-on work

- `infrastructure_manager.gd`: `try_complete()` adopts this predicate;
  `build_full()` is renamed and re-scoped to cover a span rather than a segment.
- `infrastructure_manager_test.gd`: existing assertions encode whole-segment
  behaviour and need rewriting. Add the seven rows of the table above as cases —
  particularly the two rejections.
- The PRD's rule 2 was reworded 2026-07-19 to distinguish segment from span;
  ADR 0003's span-completeness paragraph carries an amendment pointing here.
- **Unresolved, tracked separately:** whether animals will actually *use* a
  crossing rather than walking around the corridor's end. See
  [[../../obsidian-vault/design/detour-cost-question|the detour-cost question]].
  That question does not affect this definition, but it determines whether a
  correctly-built span changes anything in the simulation.
