---
title: "0003 — Crossing Tile Architecture"
date: 2026-06-17
status: accepted
---

## Context

The overpass is the first of three planned crossing types (overpass, underpass,
corridor). [`wildlife-overpass-crossing`](../../obsidian-vault/prd/wildlife-overpass-crossing.md)
requires that adding future crossing types be possible "by adding new tile type
entries rather than requiring structural changes" (P2 / goal 5, composability).
A crossing must span *every* cell of dangerous terrain to create a route, and
each species has a `preferred_crossing_type` that lowers pathfinding cost for
matching crossings. We must choose how crossings are represented so the data
model is open to new types without rewriting pathfinding or placement code.

Options considered:

1. **Hardcoded per-type scenes/classes** (one `Overpass`, one `Underpass`, …)
   with type-specific pathfinding logic.
2. **Data-driven crossing-type registry**: a single placeable crossing tile
   whose behaviour is parameterised by a `crossing_type` entry loaded from data.

## Decision

Adopt a **data-driven crossing-type registry**. A crossing is a tile carrying a
`crossing_type` string key (`overpass` | `underpass` | `corridor`) that indexes
an entry in `infrastructure.json`. The entry holds cost-per-tile, the set of
terrain flags the type may cover, the species-preference cost modifier, and the
biome sprite-variant set. Pathfinding and placement read the registry; they
contain no per-type branches. Adding a type is a data edit plus art, not a code
change.

Span completeness is a property of the segment, not the individual tile: a
segment's dangerous tiles gain zero-mortality graph edges only when every
`is_hazardous`/`is_impassable` cell in the segment is covered by a connected
chain of crossing tiles of a single type.

## Consequences

### Positive

- New crossing types ship as `infrastructure.json` entries + sprites, satisfying
  the composability goal with no structural rewrite.
- Species preference is a uniform cost modifier keyed by `crossing_type`, so the
  pathfinding cost function is type-agnostic (see
  [`simulation-design`](../simulation-design.md)).
- Cost tuning (`5,000` per overpass tile, etc.) lives in data/constants, not code.

### Negative / Trade-offs

- A type that needs genuinely novel behaviour (e.g. a seasonal corridor only
  usable in autumn) may exceed what pure data parameters express, requiring a
  registry-schema extension. The schema is versioned to absorb this.
- Validation that a span is "complete and single-type" is more involved than a
  per-tile check; it is centralised in `infrastructure_manager.gd`.

### Neutral / Follow-on work

- The data schema for `infrastructure.json` is specified in
  [`data-schemas`](../data-schemas.md); extend its `data_version` when adding
  fields for underpass/corridor.
